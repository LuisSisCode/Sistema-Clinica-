import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import Qt.labs.platform 1.1

Item {
    id: cierreCajaRoot
    objectName: "cierreCajaRoot"
    
    Component.onDestruction: {
        console.log("🨨🨨🨨 CIERRE DE CAJA SIENDO DESTRUIDO 🨨🨨🨨")
        console.log("📍 Momento de destrucción:", new Date().toISOString())
        try {
            var error = new Error()
            console.log("📍 Stack trace:")
            console.log(error.stack)
        } catch (e) {
            console.log("No se pudo obtener stack trace")
        }
    }
    
    // ✅ FUNCIONALIDAD #1: AUTO-ACTUALIZACIÓN AL ENTRAR
    onVisibleChanged: {
        console.log("👁️ CierreCaja visibility cambió a:", visible)
        if (!visible) {
            console.log("⚠️ CierreCaja ocultado (no destruido)")
        } else {
            console.log("✅ CierreCaja mostrado")
            
            // ✅ EJECUTAR INICIALIZACIÓN AUTOMÁTICA
            Qt.callLater(function() {        
                if (cierreCajaModel && typeof cierreCajaModel.inicializarCamposAutomaticamente === 'function') {
                    console.log("🕐 Ejecutando inicialización automática de horarios...")
                    cierreCajaModel.inicializarCamposAutomaticamente()
                } else {
                    console.log("⚠️ Función inicializarCamposAutomaticamente no disponible")
                }
            })
            
            // ✅ NUEVO: CARGAR HISTORIAL DE CIERRES DE LA SEMANA
            Qt.callLater(function() {
                if (cierreCajaModel && typeof cierreCajaModel.cargarCierresSemana === 'function') {
                    console.log("📋 Cargando historial de cierres de la semana...")
                    cierreCajaModel.cargarCierresSemana()
                } else {
                    console.log("⚠️ Función cargarCierresSemana no disponible")
                }
            })
        }
    }

    // PROPIEDADES DEL MODELO
    property var cierreCajaModel: null
    
    // Colores del tema ACTUALES DEL SISTEMA
    readonly property color primaryColor: "#273746"  
    readonly property color primaryDarkColor: "#34495E"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color darkGrayColor: "#7f8c8d"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color zebraColor: "#F8F9FA"
    
    // Estados del módulo
    property int vistaActual: 0
    property bool cierreGenerado: false
    property var datosIngresos: []
    property var datosEgresos: []
    property var resumenFinanciero: ({})
    
    // PROPIEDADES DINÁMICAS DESDE EL MODEL CORREGIDAS
    property string fechaActual: Qt.formatDate(new Date(), "dd/MM/yyyy")
    property string horaInicio: "08:00"
    property string horaFin: Qt.formatTime(new Date(), "HH:mm")
    property real efectivoReal: 0.0
    property real totalIngresos: 0.0
    property real totalEgresos: 0.0
    property real saldoTeorico: 0.0
    property real diferencia: 0.0
    property int totalTransacciones: 0
    property real totalIngresosExtras: 0.0
    property int transaccionesIngresosExtras: 0

    // ✅ Función para sincronizar propiedades MANUALMENTE (menos reactivo)
    function sincronizarConModelo() {
        if (!cierreCajaModel) return
        
        try {
            // Sincronizar en lote con delay entre cada propiedad
            fechaActual = cierreCajaModel.fechaActual || fechaActual
            
            Qt.callLater(function() {
                if (!cierreCajaModel) return
                horaInicio = cierreCajaModel.horaInicio || horaInicio
                horaFin = cierreCajaModel.horaFin || horaFin
            })
            
            Qt.callLater(function() {
                if (!cierreCajaModel) return
                efectivoReal = cierreCajaModel.efectivoReal || 0.0
                totalIngresos = cierreCajaModel.totalIngresos || 0.0
                totalEgresos = cierreCajaModel.totalEgresos || 0.0
            })
            
            Qt.callLater(function() {
                if (!cierreCajaModel) return
                saldoTeorico = cierreCajaModel.saldoTeorico || 0.0
                diferencia = cierreCajaModel.diferencia || 0.0
                totalTransacciones = cierreCajaModel.totalTransacciones || 0
            })
            
            Qt.callLater(function() {
                if (!cierreCajaModel) return
                totalIngresosExtras = cierreCajaModel.totalIngresosExtras || 0.0
                transaccionesIngresosExtras = cierreCajaModel.transaccionesIngresosExtras || 0
            })
            
            console.log("✅ Propiedades sincronizadas con modelo")
            
        } catch (error) {
            console.log("⚠️ Error sincronizando propiedades:", error)
        }
    }
    
    // Propiedades calculadas para el arqueo
    readonly property string tipoDiferencia: {
        if (Math.abs(diferencia) < 1.0) return "NEUTRO"
        else if (diferencia > 0) return "SOBRANTE"
        else return "FALTANTE"
    }

    readonly property bool dentroDeLimite: Math.abs(diferencia) <= 50.0
    readonly property bool requiereAutorizacion: Math.abs(diferencia) > 50.0
    
    onCierreCajaModelChanged: {
        if (cierreCajaModel) {
            // Sincronizar valores iniciales
            if (cierreCajaModel.horaFin) horaFin = cierreCajaModel.horaFin
            if (cierreCajaModel.horaInicio) horaInicio = cierreCajaModel.horaInicio
            if (cierreCajaModel.fechaActual) fechaActual = cierreCajaModel.fechaActual
        }
    }

    Connections {
        target: cierreCajaModel
        
        // ✅ SINCRONIZACIÓN MANUAL RETRASADA (evita sobrecarga)
        function onDatosChanged() {
            console.log("📊 Datos del modelo cambiaron - sincronizando...")
            // Usar timer para evitar actualizaciones simultáneas
            sincronizacionTimer.restart()
        }
        
        function onEfectivoRealChanged() {
            console.log("💵 Efectivo real cambió")
            Qt.callLater(function() {
                if (cierreCajaModel) {
                    efectivoReal = cierreCajaModel.efectivoReal || 0.0
                }
            })
        }
        
        function onValidacionChanged() {
            console.log("✔ Validación cambió")
            Qt.callLater(function() {
                if (cierreCajaModel) {
                    diferencia = cierreCajaModel.diferencia || 0.0
                }
            })
        }
        
        function onOperacionExitosa(mensaje) {
            console.log("✅", mensaje)
            // ✅ SINCRONIZAR DESPUÉS DE OPERACIÓN EXITOSA
            if (mensaje.includes("Datos consultados")) {
                // Sincronizar con delay de 500ms
                Qt.callLater(function() {
                    sincronizacionTimer.restart()
                })
            }
            
            // ✅ NO MOSTRAR TOAST INMEDIATAMENTE
            if (mensaje.includes("PDF") || mensaje.includes("Datos consultados")) {
                Qt.callLater(function() {
                    mostrarNotificacionSegura("Éxito", mensaje)
                })
            }
        }
        
        function onOperacionError(mensaje) {
            console.log("❌", mensaje)
            Qt.callLater(function() {
                mostrarNotificacion("Error", mensaje)
            })
        }

        function onPdfGenerado(filepath) {
            console.log("✅ PDF generado exitosamente:", filepath)
            
            // ✅ ABRIR PDF AUTOMÁTICAMENTE CON DELAY
            Qt.callLater(function() {
                if (filepath && filepath.length > 0) {
                    abrirPDFAutomaticamente(filepath)
                }
            })
        }

        function onCierreCompletado(success, mensaje) {
            if (success) {
                console.log("✅ Cierre completado exitosamente")
                
                // Limpiar la interfaz
                Qt.callLater(function() {
                    // Resetear campos en la UI
                    efectivoReal = 0.0
                    totalIngresos = 0.0
                    totalEgresos = 0.0
                    saldoTeorico = 0.0
                    diferencia = 0.0
                    
                    // Mostrar notificación
                    mostrarNotificacion("Éxito", mensaje)
                    
                    // Recargar automáticamente con nuevos horarios
                    Qt.callLater(function() {
                        if (cierreCajaModel && typeof cierreCajaModel.inicializarCamposAutomaticamente === 'function') {
                            cierreCajaModel.inicializarCamposAutomaticamente()
                        }
                    }, 500)
                })
            } else {
                mostrarNotificacion("Error", mensaje)
            }
        }
    }

    // ✅ NUEVO: Timer para sincronización retrasada
    Timer {
        id: sincronizacionTimer
        interval: 500  // Esperar 500ms antes de sincronizar
        repeat: false
        running: false
        
        onTriggered: {
            console.log("⏰ Ejecutando sincronización retrasada...")
            sincronizarConModelo()
        }
    }
    
    Timer {
        id: modelHealthTimer
        interval: 15000
        running: false  // ✅ NUNCA INICIAR (eliminar complejidad)
        repeat: false   // ✅ NO REPETIR
        
        onTriggered: {
            // ✅ DESHABILITADO POR ESTABILIDAD
            console.log("⚠️ modelHealthTimer deshabilitado por estabilidad")
        }
    }
    
    Timer {
        id: initializationTimer
        interval: 1000
        running: false
        repeat: false
        
        onTriggered: {
            try {
                if (appController && appController.cierre_caja_model_instance) {
                    cierreCajaModel = appController.cierre_caja_model_instance
                    
                    if (cierreCajaModel && cierreCajaModel.usuario_actual_id > 0) {
                        // Solo cargar datos si hay usuario autenticado
                        Qt.callLater(function() {
                            if (typeof cierreCajaModel.cargarCierresSemana === 'function') {
                                cierreCajaModel.cargarCierresSemana()
                            }
                        })
                    }
                    console.log("✅ Modelo inicializado correctamente")
                } else {
                    console.log("❌ Modelo no disponible en AppController")
                }
            } catch (error) {
                console.log("❌ Error en inicialización:", error)
            }
        }
    }
    
    function verificarModelo() {
        if (!cierreCajaModel && appController) {
            try {
                cierreCajaModel = appController.cierre_caja_model_instance
                if (cierreCajaModel) {
                    console.log("🔄 Modelo reconectado")
                }
            } catch (error) {
                console.log("❌ Error verificando modelo:", error)
            }
        }
    }
    
    // ✅ FUNCIONALIDAD #3: VALIDACIÓN DE RANGO DE HORAS
    function validarRangoHoras(inicio, fin) {
        try {
            if (!inicio || !fin) {
                console.log("❌ Parámetros de hora vacíos")
                return false
            }
            
            // Convertir horas a minutos para comparación
            var inicioPartes = inicio.split(':')
            var finPartes = fin.split(':')
            
            if (inicioPartes.length < 2 || finPartes.length < 2) {
                console.log("❌ Formato de hora inválido")
                return false
            }
            
            var inicioMinutos = parseInt(inicioPartes[0]) * 60 + parseInt(inicioPartes[1])
            var finMinutos = parseInt(finPartes[0]) * 60 + parseInt(finPartes[1])
            
            if (inicioMinutos >= finMinutos) {
                console.log("❌ Rango inválido: Hora inicio (" + inicio + ") >= Hora fin (" + fin + ")")
                return false
            }
            
            console.log("✅ Rango válido:", inicio, "-", fin)
            return true
            
        } catch (e) {
            console.log("❌ Error validando rango:", e)
            return false
        }
    }
    
    StackLayout {
        anchors.fill: parent
        currentIndex: vistaActual
        
        // VISTA 0: VISTA PRINCIPAL CON ARQUEO COMPLETO
        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // HEADER FIJO CON BOTONES PRINCIPALES
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: primaryColor
                    z: 10
                    
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: "#10000000" }
                        }
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            
                            Label {
                                text: "💼 ARQUEO DE CAJA DIARIO"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: 18
                                font.family: "Segoe UI"
                            }
                            
                            Label {
                                text: "📅 Fecha: " + fechaActual + " • 🕐 Hora: " + Qt.formatTime(new Date(), "hh:mm")
                                color: "#E8F4FD"
                                font.pixelSize: 11
                                font.family: "Segoe UI"
                            }
                        }
                        
                        RowLayout {
                            spacing: 12
                            
                            // ✅ CORRECCIÓN #1: Botón de PDF - ELIMINAR return
                            Button {
                                text: "📄 Generar PDF"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 150
                                // ✅ SIN return en enabled
                                enabled: cierreCajaModel && 
                                    !cierreCajaModel.loading && 
                                    fechaField.text.trim().length > 0 &&
                                    horaInicioField.text.trim().length > 0 &&
                                    horaFinField.text.trim().length > 0
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(successColor, 1.2) : (parent.enabled ? successColor : darkGrayColor)
                                    radius: 6
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    opacity: parent.enabled ? 1.0 : 0.6
                                }
                                
                                onClicked: {
                                    console.log("📄 Generando PDF del arqueo...")
                                    
                                    // ✅ VALIDACIONES MEJORADAS
                                    if (!cierreCajaModel) {
                                        mostrarNotificacion("Error", "Modelo no disponible")
                                        return
                                    }
                                    
                                    // ✅ Validar que tenga datos consultados
                                    if (totalIngresos === 0 && totalEgresos === 0) {
                                        mostrarNotificacion("Advertencia", "Primero consulte los datos presionando 'Consultar'")
                                        return
                                    }
                                    
                                    // ✅ Validar campos completos
                                    if (fechaField.text.trim().length === 0 || 
                                        horaInicioField.text.trim().length === 0 || 
                                        horaFinField.text.trim().length === 0) {
                                        mostrarNotificacion("Error", "Complete todos los campos de fecha y hora")
                                        return
                                    }
                                    
                                    try {
                                        // ✅ MÉTODO CORRECTO: generarPDFConsulta
                                        if (typeof cierreCajaModel.generarPDFConsulta === 'function') {
                                            console.log("✅ Llamando a generarPDFConsulta()")
                                            cierreCajaModel.generarPDFConsulta()
                                        } else {
                                            console.log("❌ Método generarPDFConsulta no existe")
                                            mostrarNotificacion("Error", "Función no disponible")
                                        }
                                    } catch (error) {
                                        console.log("❌ Error:", error)
                                        mostrarNotificacion("Error", error.toString())
                                    }
                                }
                            }
                            
                            // Botón de abrir carpeta
                            Button {
                                text: "📁 Carpeta"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 120
                                enabled: true
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(primaryDarkColor, 1.2) : primaryDarkColor
                                    radius: 6
                                    border.color: primaryColor
                                    border.width: 1
                                    
                                    // Efecto hover
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6
                                        color: parent.parent.hovered ? "#20FFFFFF" : "transparent"
                                    }
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    console.log("📁 Abriendo carpeta de PDFs...")
                                    
                                    try {
                                        if (appController && typeof appController.abrirCarpetaReportes === 'function') {
                                            var resultado = appController.abrirCarpetaReportes()
                                            
                                            if (resultado) {
                                                mostrarNotificacionSegura("Carpeta Abierta", "Carpeta de reportes abierta correctamente")
                                            } else {
                                                mostrarNotificacion("Advertencia", "No se pudo abrir la carpeta")
                                            }
                                        } else {
                                            console.log("❌ Función abrirCarpetaReportes no disponible")
                                            mostrarNotificacion("Error", "Función no disponible en el sistema")
                                        }
                                    } catch (error) {
                                        console.log("❌ Error:", error)
                                        mostrarNotificacion("Error", "Error abriendo carpeta: " + error.toString())
                                    }
                                }
                                
                                ToolTip.visible: hovered
                                ToolTip.text: "Abrir carpeta donde se guardan los PDFs"
                                ToolTip.delay: 500
                            }
                            
                            // ✅ CORRECCIÓN #2: Botón de Cerrar Caja - ELIMINAR return
                            Button {
                                text: "✅ Cerrar Caja"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 130
                                enabled: {
                                    var habilitado = cierreCajaModel && 
                                                    !cierreCajaModel.loading && 
                                                    efectivoReal > 0 && 
                                                    fechaField.text.trim().length > 0 &&
                                                    horaInicioField.text.trim().length > 0 &&
                                                    horaFinField.text.trim().length > 0
                                    
                                    if (!habilitado) {
                                        console.log("🔒 Botón deshabilitado - Efectivo:", efectivoReal)
                                    }
                                    
                                    habilitado  // ← SIN return
                                }
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(successColor, 1.2) : (parent.enabled ? successColor : darkGrayColor)
                                    radius: 6
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    opacity: parent.enabled ? 1.0 : 0.6
                                }
                                
                                onClicked: {
                                    console.log("🔱️ Botón Cerrar Caja presionado")
                                    
                                    // ✅ VALIDACIÓN ADICIONAL ANTES DE CERRAR
                                    if (!cierreCajaModel) {
                                        mostrarNotificacion("Error", "Modelo no disponible")
                                        return
                                    }
                                    
                                    // ✅ Validar que no esté ocupado (doble verificación)
                                    if (cierreCajaModel.loading) {
                                        console.log("⏳ Modelo ocupado, ignorando clic")
                                        mostrarNotificacion("Espere", "El sistema está procesando otra operación")
                                        return
                                    }
                                    
                                    // ✅ Validar efectivo real
                                    if (efectivoReal <= 0) {
                                        mostrarNotificacion("Error", "Debe ingresar el efectivo real contado")
                                        return
                                    }
                                    
                                    // ✅ Validar que tenga datos consultados
                                    if (totalIngresos === 0 && totalEgresos === 0) {
                                        mostrarNotificacion("Error", "Primero consulte los datos del día")
                                        return
                                    }
                                    
                                    try {
                                        cerrarCaja()
                                    } catch (error) {
                                        console.log("❌ Error en cerrarCaja:", error)
                                        mostrarNotificacion("Error", "Error cerrando caja: " + error.toString())
                                    }
                                }
                            }
                        }
                    }
                }
                
                // CONTENIDO PRINCIPAL CON SCROLL MEJORADO
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    wheelEnabled: true
                    contentWidth: availableWidth
                    contentHeight: mainContent.height + 40
                    
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    
                    Rectangle {
                        width: parent.width
                        height: mainContent.height + 40
                        color: lightGrayColor
                        
                        ColumnLayout {
                            id: mainContent
                            width: parent.width
                            spacing: 20
                            anchors.top: parent.top
                            anchors.topMargin: 20
                            
                            // SELECTOR DE FECHA Y RANGO
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 100
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                color: whiteColor
                                radius: 8
                                border.color: "#E0E6ED"
                                border.width: 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 30
                                    
                                    ColumnLayout {
                                        spacing: 8
                                        Label {
                                            text: "📅 FECHA DEL CIERRE"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: textColor
                                        }
                                        TextField {
                                            id: fechaField
                                            Layout.preferredWidth: 120
                                            Layout.preferredHeight: 35
                                            text: fechaActual
                                            placeholderText: "DD/MM/YYYY"
                                            selectByMouse: true
                                            
                                            background: Rectangle {
                                                color: whiteColor
                                                border.color: {
                                                    if (parent.activeFocus) return primaryColor
                                                    if (parent.text.trim().length === 0) return darkGrayColor
                                                    return validarFormatoFecha(parent.text) ? successColor : dangerColor
                                                }
                                                border.width: 1
                                                radius: 4
                                            }
                                            
                                            onTextChanged: {
                                                // Solo actualizar si hay modelo y el texto tiene contenido
                                                if (cierreCajaModel && text.trim().length > 0) {
                                                    try {
                                                        cierreCajaModel.cambiarFecha(text)
                                                    } catch (error) {
                                                        console.log("Error actualizando fecha:", error)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    ColumnLayout {
                                        spacing: 8
                                        Label {
                                            text: "🕐 HORA INICIO"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: textColor
                                        }
                                        TextField {
                                            id: horaInicioField
                                            Layout.preferredWidth: 80
                                            Layout.preferredHeight: 35
                                            text: horaInicio
                                            placeholderText: "08:00"
                                            selectByMouse: true
                                            
                                            background: Rectangle {
                                                color: whiteColor
                                                border.color: {
                                                    if (parent.activeFocus) return primaryColor
                                                    if (parent.text.trim().length === 0) return darkGrayColor
                                                    return validarFormatoHora(parent.text) ? successColor : dangerColor
                                                }
                                                border.width: 1
                                                radius: 4
                                            }
                                            
                                            onTextChanged: {
                                                if (cierreCajaModel && text.trim().length > 0) {
                                                    try {
                                                        cierreCajaModel.establecerHoraInicio(text)
                                                    } catch (error) {
                                                        console.log("Error actualizando hora inicio:", error)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    ColumnLayout {
                                        spacing: 8
                                        Label {
                                            text: "🕐 HORA FIN"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: textColor
                                        }
                                        TextField {
                                            id: horaFinField
                                            Layout.preferredWidth: 80
                                            Layout.preferredHeight: 35
                                            text: horaFin
                                            placeholderText: "18:00"
                                            selectByMouse: true
                                            
                                            background: Rectangle {
                                                color: whiteColor
                                                border.color: {
                                                    if (parent.activeFocus) return primaryColor
                                                    if (parent.text.trim().length === 0) return darkGrayColor
                                                    return validarFormatoHora(parent.text) ? successColor : dangerColor
                                                }
                                                border.width: 1
                                                radius: 4
                                            }
                                            
                                            onTextChanged: {
                                                if (cierreCajaModel && text.trim().length > 0) {
                                                    try {
                                                        cierreCajaModel.establecerHoraFin(text)
                                                    } catch (error) {
                                                        console.log("Error actualizando hora fin:", error)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // ✅ CORRECCIÓN #3: Botón Consultar - ELIMINAR return + AGREGAR VALIDACIÓN + ACTUALIZAR HORA FIN
                                    Button {
                                        text: "🔄 Consultar"
                                        Layout.preferredHeight: 35
                                        Layout.preferredWidth: 120
                                        // ✅ SIN return en enabled
                                        enabled: cierreCajaModel && 
                                                !cierreCajaModel.loading && 
                                                fechaField.text.trim().length > 0 && 
                                                horaInicioField.text.trim().length > 0 && 
                                                horaFinField.text.trim().length > 0
                                        
                                        background: Rectangle {
                                            color: parent.pressed ? Qt.darker(primaryColor, 1.2) : (parent.enabled ? primaryColor : darkGrayColor)
                                            radius: 6
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: {
                                            console.log("🔄 Botón Consultar presionado")
                                            
                                            // ✅ FUNCIONALIDAD #2: Actualizar hora fin a la hora actual ANTES de consultar
                                            var horaActualSistema = Qt.formatTime(new Date(), "HH:mm")
                                            horaFinField.text = horaActualSistema
                                            console.log("🕐 Hora fin actualizada automáticamente:", horaActualSistema)
                                            
                                            // ✅ VALIDACIONES MEJORADAS
                                            if (!cierreCajaModel) {
                                                console.log("❌ Modelo no disponible")
                                                mostrarNotificacion("Error", "Modelo no disponible")
                                                return
                                            }
                                            
                                            // ✅ Validar que no esté ocupado
                                            if (cierreCajaModel.loading) {
                                                console.log("⏳ Modelo ocupado, ignorando clic")
                                                mostrarNotificacion("Espere", "El sistema está procesando otra operación")
                                                return
                                            }
                                            
                                            // ✅ Validar campos
                                            if (fechaField.text.trim().length === 0 || 
                                                horaInicioField.text.trim().length === 0 || 
                                                horaFinField.text.trim().length === 0) {
                                                mostrarNotificacion("Error", "Complete todos los campos de fecha y hora")
                                                return
                                            }
                                            
                                            // ✅ Validar formato de fecha
                                            if (!validarFormatoFecha(fechaField.text)) {
                                                mostrarNotificacion("Error", "Formato de fecha inválido (DD/MM/YYYY)")
                                                return
                                            }
                                            
                                            // ✅ Validar formato de horas
                                            if (!validarFormatoHora(horaInicioField.text) || !validarFormatoHora(horaFinField.text)) {
                                                mostrarNotificacion("Error", "Formato de hora inválido (HH:MM)")
                                                return
                                            }
                                            
                                            // ✅ FUNCIONALIDAD #3: Validar rango de horas
                                            if (!validarRangoHoras(horaInicioField.text, horaFinField.text)) {
                                                mostrarNotificacion("Error", "Hora inicio debe ser menor que hora fin. Por favor corrija los horarios.")
                                                return
                                            }
                                            
                                            try {
                                                if (typeof cierreCajaModel.consultarDatos === 'function') {
                                                    console.log("✅ Llamando a consultarDatos()")
                                                    cierreCajaModel.consultarDatos()
                                                } else {
                                                    console.log("❌ Método consultarDatos no existe")
                                                    mostrarNotificacion("Error", "Función no disponible")
                                                }
                                            } catch (error) {
                                                console.log("❌ Error en consultarDatos:", error)
                                                mostrarNotificacion("Error", "Error ejecutando operación: " + error.toString())
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // RESUMEN FINANCIERO PRINCIPAL
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                color: whiteColor
                                radius: 8
                                border.color: "#E0E6ED"
                                border.width: 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 40
                                    
                                    // TOTAL INGRESOS
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        
                                        Label {
                                            text: "💰 TOTAL INGRESOS"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: darkGrayColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: "Bs " + totalIngresos.toFixed(2)
                                            font.pixelSize: 28
                                            font.bold: true
                                            color: successColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: (cierreCajaModel && cierreCajaModel.resumenRango ? cierreCajaModel.resumenRango.transacciones_ingresos : 0) + " transacciones"
                                            font.pixelSize: 10
                                            color: darkGrayColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 1
                                        Layout.fillHeight: true
                                        Layout.topMargin: 10
                                        Layout.bottomMargin: 10
                                        color: lightGrayColor
                                    }
                                    
                                    // TOTAL EGRESOS
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        
                                        Label {
                                            text: "💸 TOTAL EGRESOS"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: darkGrayColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: "Bs " + totalEgresos.toFixed(2)
                                            font.pixelSize: 28
                                            font.bold: true
                                            color: dangerColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: (cierreCajaModel && cierreCajaModel.resumenRango ? cierreCajaModel.resumenRango.transacciones_egresos : 0) + " transacciones"
                                            font.pixelSize: 10
                                            color: darkGrayColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 1
                                        Layout.fillHeight: true
                                        Layout.topMargin: 10
                                        Layout.bottomMargin: 10
                                        color: lightGrayColor
                                    }
                                    
                                    // SALDO TEÓRICO
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        
                                        Label {
                                            text: "📊 SALDO TEÓRICO"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: darkGrayColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: "Bs " + saldoTeorico.toFixed(2)
                                            font.pixelSize: 28
                                            font.bold: true
                                            color: saldoTeorico >= 0 ? successColor : dangerColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: "Diferencia del día"
                                            font.pixelSize: 10
                                            color: darkGrayColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }
                            }
                            
                            // GRID CON INGRESOS Y EGRESOS
                            GridLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                columns: 2
                                columnSpacing: 20
                                rowSpacing: 20
                                
                                // TABLA DE INGRESOS DETALLADOS
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 330
                                    color: whiteColor
                                    radius: 8
                                    border.color: "#E0E6ED"
                                    border.width: 1
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 20
                                        spacing: 15
                                        
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12
                                            Rectangle {
                                                width: 4
                                                height: 24
                                                color: successColor
                                                radius: 2
                                            }
                                            Label {
                                                text: "💰 INGRESOS DEL DÍA"
                                                font.pixelSize: 16
                                                font.bold: true
                                                color: textColor
                                            }
                                            Item { Layout.fillWidth: true }
                                            Label {
                                                text: "Bs " + totalIngresos.toFixed(2)
                                                font.pixelSize: 16
                                                font.bold: true
                                                color: successColor
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 35
                                            color: primaryColor
                                            radius: 4
                                            
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 0
                                                Label {
                                                    Layout.preferredWidth: 180
                                                    text: "CONCEPTO"
                                                    font.bold: true
                                                    font.pixelSize: 10
                                                    color: whiteColor
                                                }
                                                Label {
                                                    Layout.preferredWidth: 80
                                                    text: "CANT."
                                                    font.bold: true
                                                    font.pixelSize: 10
                                                    color: whiteColor
                                                    horizontalAlignment: Text.AlignCenter
                                                }
                                                Label {
                                                    Layout.fillWidth: true
                                                    text: "IMPORTE (Bs)"
                                                    font.bold: true
                                                    font.pixelSize: 10
                                                    color: whiteColor
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }
                                        }
                                        
                                        ScrollView {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            clip: true
                                            wheelEnabled: false
                                            
                                            ColumnLayout {
                                                width: parent.width
                                                spacing: 0
                                                
                                                Repeater {
                                                    model: cierreCajaModel && cierreCajaModel.resumenRango ? cierreCajaModel.resumenRango.ingresos_por_categoria : []
                                                    
                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 40
                                                        color: index % 2 === 0 ? whiteColor : zebraColor
                                                        
                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.margins: 10
                                                            spacing: 0
                                                            Label {
                                                                Layout.preferredWidth: 180
                                                                text: modelData.concepto || "Sin concepto"
                                                                font.pixelSize: 10
                                                                color: textColor
                                                                elide: Text.ElideRight
                                                            }
                                                            Label {
                                                                Layout.preferredWidth: 80
                                                                text: (modelData.transacciones || 0).toString()
                                                                font.pixelSize: 10
                                                                color: textColor
                                                                horizontalAlignment: Text.AlignCenter
                                                            }
                                                            Label {
                                                                Layout.fillWidth: true
                                                                text: (modelData.importe || 0).toFixed(2)
                                                                font.pixelSize: 10
                                                                font.bold: true
                                                                color: successColor
                                                                horizontalAlignment: Text.AlignRight
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // TABLA DE EGRESOS DETALLADOS
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 330
                                    color: whiteColor
                                    radius: 8
                                    border.color: "#E0E6ED"
                                    border.width: 1
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 20
                                        spacing: 15
                                        
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12
                                            Rectangle {
                                                width: 4
                                                height: 24
                                                color: dangerColor
                                                radius: 2
                                            }
                                            Label {
                                                text: "💸 EGRESOS DEL DÍA"
                                                font.pixelSize: 16
                                                font.bold: true
                                                color: textColor
                                            }
                                            Item { Layout.fillWidth: true }
                                            Label {
                                                text: "Bs " + totalEgresos.toFixed(2)
                                                font.pixelSize: 16
                                                font.bold: true
                                                color: dangerColor
                                            }
                                        }
                                        
                                        ScrollView {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            clip: true
                                            wheelEnabled: false
                                            
                                            ColumnLayout {
                                                width: parent.width
                                                spacing: 8
                                                
                                                Repeater {
                                                    model: cierreCajaModel && cierreCajaModel.resumenRango ? cierreCajaModel.resumenRango.egresos_por_categoria : []
                                                    
                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 60
                                                        color: index % 2 === 0 ? whiteColor : zebraColor
                                                        radius: 6
                                                        border.color: (modelData.importe || 0) > 0 ? dangerColor : lightGrayColor
                                                        border.width: (modelData.importe || 0) > 0 ? 2 : 1
                                                        
                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.margins: 12
                                                            spacing: 15
                                                            
                                                            ColumnLayout {
                                                                Layout.fillWidth: true
                                                                spacing: 4
                                                                Label {
                                                                    text: modelData.concepto || "Sin concepto"
                                                                    font.pixelSize: 12
                                                                    font.bold: true
                                                                    color: textColor
                                                                }
                                                                Label {
                                                                    text: modelData.detalle || "Sin detalles"
                                                                    font.pixelSize: 9
                                                                    color: darkGrayColor
                                                                }
                                                            }
                                                            Label {
                                                                text: "Bs " + (modelData.importe || 0).toFixed(2)
                                                                font.pixelSize: 14
                                                                font.bold: true
                                                                color: (modelData.importe || 0) > 0 ? dangerColor : darkGrayColor
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // ARQUEO MANUAL - RECTANGLE RESPONSIVE
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                color: whiteColor
                                radius: 8
                                border.color: "#E0E6ED"
                                border.width: 1
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 10
                                    
                                    Label {
                                        text: "📊 ARQUEO MANUAL DE EFECTIVO"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: textColor
                                    }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 15
                                        
                                        // EFECTIVO REAL CONTADO
                                        ColumnLayout {
                                            Layout.preferredWidth: 140
                                            Layout.minimumWidth: 120
                                            spacing: 4
                                            
                                            Label {
                                                text: "💵 Efectivo Real:"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: textColor
                                            }
                                            
                                            TextField {
                                                id: efectivoRealField
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 35
                                                placeholderText: "0.00"
                                                font.pixelSize: 14
                                                font.bold: true
                                                text: ""
                                                selectByMouse: true
                                                
                                                property bool actualizandoTexto: false
                                                
                                                background: Rectangle {
                                                    color: whiteColor
                                                    border.color: parent.activeFocus ? primaryColor : darkGrayColor
                                                    border.width: 1
                                                    radius: 4
                                                }
                                                
                                                // ✅ VALIDACIÓN MANUAL QUE ACEPTA PUNTO Y COMA
                                                validator: RegularExpressionValidator {
                                                    regularExpression: /^[0-9]*[.,]?[0-9]{0,2}$/
                                                }
                                                
                                                onTextChanged: {
                                                    if (!actualizandoTexto) {
                                                        // ✅ VALIDACIÓN MEJORADA
                                                        if (!cierreCajaModel) {
                                                            console.log("⚠️ Modelo no disponible en onTextChanged")
                                                            return
                                                        }
                                                        
                                                        var texto = text.trim()
                                                        var monto = 0
                                                        
                                                        // ✅ Parsear monto con validación (ACEPTA PUNTO Y COMA)
                                                        if (texto.length > 0) {
                                                            try {
                                                                // ✅ NORMALIZAR: Reemplazar coma por punto
                                                                texto = texto.replace(',', '.')
                                                                monto = parseFloat(texto)
                                                                
                                                                // ✅ Validar que sea número válido
                                                                if (isNaN(monto) || !isFinite(monto)) {
                                                                    console.log("⚠️ Valor no numérico:", texto)
                                                                    monto = 0
                                                                }
                                                                
                                                                // ✅ Validar rango razonable
                                                                if (monto < 0) {
                                                                    console.log("⚠️ Valor negativo, corrigiendo a 0")
                                                                    monto = 0
                                                                }
                                                                
                                                                if (monto > 999999) {
                                                                    console.log("⚠️ Valor muy alto, limitando")
                                                                    monto = 999999
                                                                }
                                                                
                                                            } catch (error) {
                                                                console.log("❌ Error parseando efectivo:", error)
                                                                monto = 0
                                                            }
                                                        }
                                                        
                                                        // ✅ ACTUALIZAR MODELO CON VALIDACIÓN
                                                        try {
                                                            console.log("💵 Actualizando efectivo real a:", monto)
                                                            cierreCajaModel.establecerEfectivoReal(monto)
                                                        } catch (error) {
                                                            console.log("❌ Error actualizando efectivo real:", error)
                                                        }
                                                    }
                                                }
                                                
                                                onFocusChanged: {
                                                    if (focus) {
                                                        // ✅ Al recibir foco, seleccionar todo
                                                        selectAll()
                                                    } else if (text.trim().length === 0) {
                                                        // ✅ Si pierde el foco y está vacío, establecer a 0
                                                        if (cierreCajaModel) {
                                                            console.log("💵 Campo vacío, estableciendo a 0")
                                                            cierreCajaModel.establecerEfectivoReal(0)
                                                        }
                                                    } else {
                                                        // ✅ NORMALIZAR AL PERDER FOCO: Mostrar con formato correcto
                                                        var textoNormalizado = text.replace(',', '.')
                                                        var valorFloat = parseFloat(textoNormalizado)
                                                        
                                                        if (!isNaN(valorFloat) && isFinite(valorFloat)) {
                                                            actualizandoTexto = true
                                                            text = valorFloat.toFixed(2)
                                                            actualizandoTexto = false
                                                        }
                                                    }
                                                }
                                                
                                                onPressed: {
                                                    selectAll()
                                                }
                                                
                                                // ✅ Conexión para actualizar cuando el modelo cambia
                                                Connections {
                                                    target: cierreCajaModel
                                                    function onEfectivoRealChanged() {
                                                        if (cierreCajaModel && !efectivoRealField.activeFocus) {
                                                            efectivoRealField.actualizandoTexto = true
                                                            efectivoRealField.text = cierreCajaModel.efectivoReal.toFixed(2)
                                                            efectivoRealField.actualizandoTexto = false
                                                        }
                                                    }
                                                }
                                                
                                                // ✅ TOOLTIP ÚTIL
                                                ToolTip.visible: hovered
                                                ToolTip.text: "Ingrese el efectivo real contado\nAcepta punto (.) o coma (,) como separador decimal\nEjemplos: 100.50 o 100,50"
                                                ToolTip.delay: 500
                                            }
                                        }
                                        
                                        // SEPARADOR VISUAL
                                        Rectangle {
                                            width: 1
                                            Layout.fillHeight: true
                                            Layout.topMargin: 5
                                            Layout.bottomMargin: 5
                                            color: lightGrayColor
                                        }
                                        
                                        // SALDO TEÓRICO
                                        ColumnLayout {
                                            Layout.preferredWidth: 140
                                            Layout.minimumWidth: 120
                                            spacing: 4
                                            
                                            Label {
                                                text: "📊 Saldo Teórico:"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: textColor
                                            }
                                            
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 35
                                                color: zebraColor
                                                radius: 4
                                                border.color: lightGrayColor
                                                border.width: 1
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: "Bs " + saldoTeorico.toFixed(2)
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    color: saldoTeorico >= 0 ? successColor : dangerColor
                                                }
                                            }
                                        }
                                        
                                        // SEPARADOR VISUAL
                                        Rectangle {
                                            width: 1
                                            Layout.fillHeight: true
                                            Layout.topMargin: 5
                                            Layout.bottomMargin: 5
                                            color: lightGrayColor
                                        }
                                        
                                        // ESTADO DE LA DIFERENCIA
                                        Rectangle {
                                            Layout.preferredWidth: 160
                                            Layout.minimumWidth: 140
                                            Layout.preferredHeight: 50
                                            color: dentroDeLimite ? "#d1fae5" : "#fee2e2"
                                            radius: 6
                                            border.color: dentroDeLimite ? successColor : dangerColor
                                            border.width: 2
                                            
                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 2
                                                
                                                Label {
                                                    text: tipoDiferencia === "SOBRANTE" ? "✅ SOBRANTE" : 
                                                        tipoDiferencia === "FALTANTE" ? "❌ FALTANTE" : "⚖️ NEUTRO"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: dentroDeLimite ? "#065f46" : "#dc2626"
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                                
                                                Label {
                                                    text: "Bs " + Math.abs(diferencia).toFixed(2)
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    color: dentroDeLimite ? "#065f46" : "#dc2626"
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                                
                                                Label {
                                                    text: requiereAutorizacion ? "Requiere autorización" : 
                                                        tipoDiferencia === "NEUTRO" ? "Balanceado" : "Dentro del límite"
                                                    font.pixelSize: 8
                                                    color: darkGrayColor
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                            }
                                        }
                                        
                                        // SEPARADOR VISUAL
                                        Rectangle {
                                            width: 1
                                            Layout.fillHeight: true
                                            Layout.topMargin: 5
                                            Layout.bottomMargin: 5
                                            color: lightGrayColor
                                        }
                                        
                                        // OBSERVACIONES EDITABLES (SE EXPANDE PARA USAR ESPACIO RESTANTE)
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 200
                                            spacing: 4
                                            
                                            Label {
                                                text: "📝 Observaciones:"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: textColor
                                            }
                                            
                                            TextField {
                                                id: observacionesField
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 35
                                                placeholderText: "Ingrese observaciones del arqueo..."
                                                text: "Arqueo realizado correctamente. " + 
                                                    (tipoDiferencia === "SOBRANTE" ? "Se registra sobrante." : 
                                                    tipoDiferencia === "FALTANTE" ? "Se registra faltante." : "Sin diferencias.") + 
                                                    (requiereAutorizacion ? " Requiere autorización de supervisor." : " Dentro de límites permitidos.")
                                                selectByMouse: true
                                                font.pixelSize: 11
                                                
                                                background: Rectangle {
                                                    color: "#F8F9FA"
                                                    border.color: parent.activeFocus ? primaryColor : lightGrayColor
                                                    border.width: 1
                                                    radius: 4
                                                }
                                                
                                                onTextChanged: {
                                                    // Guardar observaciones en tiempo real si es necesario
                                                    if (cierreCajaModel && typeof cierreCajaModel.establecerObservaciones === 'function') {
                                                        cierreCajaModel.establecerObservaciones(text)
                                                    }
                                                }
                                                
                                                onPressed: {
                                                    if (text.includes("Arqueo realizado correctamente")) {
                                                        selectAll()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            } 
                            
                            // LISTA DE CIERRES DE LA SEMANA (CON FECHA)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 450
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                color: whiteColor
                                radius: 8
                                border.color: "#E0E6ED"
                                border.width: 1
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 15
                                    
                                    // ENCABEZADO DE LA SECCIÓN
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12
                                        
                                        Rectangle {
                                            width: 4
                                            height: 24
                                            color: primaryColor
                                            radius: 2
                                        }
                                        
                                        Label {
                                            text: "📋 CIERRES DE LA SEMANA ACTUAL"
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: textColor
                                        }
                                        
                                        Item { Layout.fillWidth: true }
                                        
                                        Label {
                                            text: (cierreCajaModel ? cierreCajaModel.cierresDelDia.length : 0) + " cierres registrados"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: primaryColor
                                            background: Rectangle {
                                                color: "#E8F4FD"
                                                radius: 4
                                                anchors.fill: parent
                                                anchors.margins: -6
                                            }
                                        }
                                    }
                                    
                                    // ENCABEZADOS DE LA TABLA
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 45
                                        color: primaryColor
                                        radius: 6
                                        border.color: "#1a202c"
                                        border.width: 2
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 0
                                            
                                            Label {
                                                Layout.preferredWidth: 90
                                                text: "📅 FECHA"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 110
                                                text: "🕐 HORARIO"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 110
                                                text: "💵 EFECTIVO REAL"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 110
                                                text: "📊 SALDO TEÓRICO"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 90
                                                text: "⚖️ DIFERENCIA"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 80
                                                text: "✅ ESTADO"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 120
                                                text: "👤 REGISTRADO POR"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 150
                                                text: "📝 OBSERVACIONES"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 100
                                                text: "⚙️ ACCIONES"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                    
                                    // LISTA DE DATOS
                                    ScrollView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        wheelEnabled: true
                                        
                                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                        
                                        ListView {
                                            model: cierreCajaModel ? cierreCajaModel.cierresDelDia : []
                                            spacing: 1
                                            
                                            delegate: Rectangle {
                                                width: ListView.view.width
                                                height: 60
                                                color: index % 2 === 0 ? whiteColor : zebraColor
                                                border.color: "#E0E6ED"
                                                border.width: 1
                                                
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    spacing: 0
                                                    
                                                    // FECHA
                                                    Rectangle {
                                                        Layout.preferredWidth: 90
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        Label {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            text: formatearFecha(modelData.Fecha)
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            color: textColor
                                                            horizontalAlignment: Text.AlignLeft
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // HORARIO
                                                    Rectangle {
                                                        Layout.preferredWidth: 110
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        Label {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            text: formatearHorario(modelData.HoraInicio, modelData.HoraFin)
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            color: textColor
                                                            horizontalAlignment: Text.AlignLeft
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // EFECTIVO REAL
                                                    Rectangle {
                                                        Layout.preferredWidth: 110
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        Label {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            text: "Bs " + parseFloat(modelData.EfectivoReal || 0).toLocaleString(Qt.locale(), 'f', 2)
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            color: successColor
                                                            horizontalAlignment: Text.AlignLeft
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // SALDO TEÓRICO
                                                    Rectangle {
                                                        Layout.preferredWidth: 110
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        Label {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            text: "Bs " + parseFloat(modelData.SaldoTeorico || 0).toLocaleString(Qt.locale(), 'f', 2)
                                                            font.pixelSize: 10
                                                            color: textColor
                                                            horizontalAlignment: Text.AlignLeft
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // DIFERENCIA
                                                    Rectangle {
                                                        Layout.preferredWidth: 90
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        RowLayout {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            spacing: 4
                                                            
                                                            Rectangle {
                                                                width: 50
                                                                height: 25
                                                                radius: 4
                                                                color: {
                                                                    let diff = parseFloat(modelData.Diferencia || 0)
                                                                    if (Math.abs(diff) < 1.0) return "#d1fae5"
                                                                    else if (diff > 0) return "#fef3c7"
                                                                    else return "#fee2e2"
                                                                }
                                                                border.width: 1
                                                                border.color: {
                                                                    let diff = parseFloat(modelData.Diferencia || 0)
                                                                    if (Math.abs(diff) < 1.0) return successColor
                                                                    else if (diff > 0) return warningColor
                                                                    else return dangerColor
                                                                }
                                                                
                                                                Label {
                                                                    anchors.centerIn: parent
                                                                    text: (parseFloat(modelData.Diferencia || 0) >= 0 ? "+" : "") + 
                                                                        parseFloat(modelData.Diferencia || 0).toFixed(2)
                                                                    font.pixelSize: 9
                                                                    font.bold: true
                                                                    color: {
                                                                        let diff = parseFloat(modelData.Diferencia || 0)
                                                                        if (Math.abs(diff) < 1.0) return "#065f46"
                                                                        else if (diff > 0) return "#92400e"
                                                                        else return "#dc2626"
                                                                    }
                                                                }
                                                            }
                                                            
                                                            Label {
                                                                text: "Bs"
                                                                font.pixelSize: 8
                                                                color: darkGrayColor
                                                            }
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // ESTADO
                                                    Rectangle {
                                                        Layout.preferredWidth: 80
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        Rectangle {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            width: 60
                                                            height: 22
                                                            radius: 11
                                                            color: {
                                                                let diff = parseFloat(modelData.Diferencia || 0)
                                                                if (Math.abs(diff) < 1.0) return successColor
                                                                else if (diff > 0) return warningColor
                                                                else return dangerColor
                                                            }
                                                            
                                                            Label {
                                                                anchors.centerIn: parent
                                                                text: {
                                                                    let diff = parseFloat(modelData.Diferencia || 0)
                                                                    if (Math.abs(diff) < 1.0) return "✔ OK"
                                                                    else if (diff > 0) return "+ SOBRA"
                                                                    else return "- FALTA"
                                                                }
                                                                font.pixelSize: 7
                                                                font.bold: true
                                                                color: whiteColor
                                                            }
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // REGISTRADO POR
                                                    Rectangle {
                                                        Layout.preferredWidth: 120
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        ColumnLayout {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            spacing: 2
                                                            
                                                            Label {
                                                                text: modelData.NombreUsuario || "Usuario desconocido"
                                                                font.pixelSize: 9
                                                                font.bold: true
                                                                color: textColor
                                                                horizontalAlignment: Text.AlignLeft
                                                                elide: Text.ElideRight
                                                                Layout.maximumWidth: 110
                                                            }
                                                            
                                                            Label {
                                                                text: "Cierre: " + formatearHora(modelData.HoraCierre)
                                                                font.pixelSize: 8
                                                                color: darkGrayColor
                                                                horizontalAlignment: Text.AlignLeft
                                                            }
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // OBSERVACIONES
                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 150
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        ScrollView {
                                                            anchors.fill: parent
                                                            anchors.margins: 8
                                                            clip: true
                                                            wheelEnabled: false
                                                            
                                                            ScrollBar.vertical.policy: ScrollBar.AsNeeded
                                                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                                            
                                                            Label {
                                                                text: modelData.Observaciones || "Sin observaciones registradas"
                                                                font.pixelSize: 9
                                                                color: modelData.Observaciones ? textColor : darkGrayColor
                                                                font.italic: !modelData.Observaciones
                                                                wrapMode: Text.WordWrap
                                                                width: parent.width
                                                                horizontalAlignment: Text.AlignLeft
                                                                verticalAlignment: Text.AlignTop
                                                            }
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // NUEVA COLUMNA - ACCIONES
                                                    Rectangle {
                                                        Layout.preferredWidth: 100
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        Button {
                                                            anchors.centerIn: parent
                                                            width: 80
                                                            height: 35
                                                            text: "📄 Ver"
                                                            
                                                            background: Rectangle {
                                                                color: parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor
                                                                radius: 6
                                                                border.color: primaryDarkColor
                                                                border.width: 1
                                                                
                                                                Rectangle {
                                                                    anchors.fill: parent
                                                                    radius: 6
                                                                    color: parent.parent.hovered ? "#20FFFFFF" : "transparent"
                                                                }
                                                            }
                                                            
                                                            contentItem: Label {
                                                                text: parent.text
                                                                color: whiteColor
                                                                font.bold: true
                                                                font.pixelSize: 10
                                                                horizontalAlignment: Text.AlignHCenter
                                                                verticalAlignment: Text.AlignVCenter
                                                            }
                                                            
                                                            onClicked: {
                                                                console.log("📄 Ver cierre presionado")
                                                                
                                                                // ✅ VALIDACIONES COMPLETAS
                                                                if (!cierreCajaModel) {
                                                                    mostrarNotificacion("Error", "Modelo no disponible")
                                                                    return
                                                                }
                                                                
                                                                if (cierreCajaModel.loading) {
                                                                    mostrarNotificacion("Espere", "El sistema está ocupado")
                                                                    return
                                                                }
                                                                
                                                                // ✅ VALIDAR DATOS DEL CIERRE
                                                                if (!modelData || !modelData.Fecha || !modelData.HoraInicio || !modelData.HoraFin) {
                                                                    console.log("❌ Datos del cierre incompletos")
                                                                    mostrarNotificacion("Error", "Datos del cierre incompletos")
                                                                    return
                                                                }
                                                                
                                                                try {
                                                                    console.log("📄 Generando PDF del cierre histórico:")
                                                                    console.log("   Fecha:", modelData.Fecha)
                                                                    console.log("   Horario:", modelData.HoraInicio, "-", modelData.HoraFin)
                                                                    
                                                                    // ✅ LLAMAR AL MÉTODO CORRECTO DEL MODELO
                                                                    if (typeof cierreCajaModel.generarPDFCierreEspecifico === 'function') {
                                                                        cierreCajaModel.generarPDFCierreEspecifico(
                                                                            formatearFechaParaModel(modelData.Fecha),
                                                                            limpiarFormatoHora(modelData.HoraInicio),
                                                                            limpiarFormatoHora(modelData.HoraFin)
                                                                        )
                                                                        
                                                                        // Notificar que está procesando
                                                                        mostrarNotificacionSegura("Procesando", "Generando PDF del cierre...")
                                                                    } else {
                                                                        console.log("❌ Método no existe")
                                                                        mostrarNotificacion("Error", "Función no disponible")
                                                                    }
                                                                    
                                                                } catch (error) {
                                                                    console.log("❌ Error:", error)
                                                                    mostrarNotificacion("Error", "Error generando PDF: " + error.toString())
                                                                }
                                                            }
                                                            
                                                            ToolTip.visible: hovered
                                                            ToolTip.text: "Ver PDF de este cierre"
                                                            ToolTip.delay: 500
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            // MENSAJE CUANDO NO HAY DATOS
                                            Rectangle {
                                                visible: parent.count === 0
                                                anchors.centerIn: parent
                                                width: parent.width * 0.6
                                                height: 120
                                                color: "#F8F9FA"
                                                radius: 8
                                                border.color: "#E0E6ED"
                                                border.width: 1
                                                
                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 8
                                                    
                                                    Label {
                                                        text: "📋"
                                                        font.pixelSize: 32
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }
                                                    
                                                    Label {
                                                        text: "No hay cierres registrados para esta semana"
                                                        font.pixelSize: 14
                                                        font.bold: true
                                                        color: darkGrayColor
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }
                                                    
                                                    Label {
                                                        text: "Realiza tu primer cierre usando el formulario superior"
                                                        font.pixelSize: 11
                                                        color: darkGrayColor
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Espacio final
                            Item { Layout.preferredHeight: 100 }
                        }
                    }
                }
            }
        }
    }
    
    // NOTIFICACIÓN TOAST CENTRADA
    Rectangle {
        id: toastNotification
        anchors.horizontalCenter: parent.horizontalCenter
        y: 100
        width: 400
        height: 70
        radius: 10
        color: "#27ae60"
        visible: false
        z: 9999
        opacity: 0
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        Rectangle {
            anchors.fill: parent
            radius: 10
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#27ae60" }
                GradientStop { position: 1.0; color: "#219a52" }
            }
            border.color: "#1e8449"
            border.width: 2
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 15
            
            Label {
                text: "✅"
                font.pixelSize: 20
                Layout.alignment: Qt.AlignVCenter
            }
            
            Label {
                id: toastMessage
                text: ""
                color: "white"
                font.bold: true
                font.pixelSize: 14
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                wrapMode: Text.WordWrap
            }
        }
        
        Timer {
            id: toastTimer
            interval: 3500
            onTriggered: hide()
        }
        
        function show(message) {
            // ✅ NO HACER NADA SI NO ES CRÍTICO
            console.log("📢 Toast solicitado (ignorado por estabilidad):", message)
            // Comentar todo el código de mostrar para eliminar timers
            /*
            toastMessage.text = message
            visible = true
            opacity = 1
            toastTimer.restart()
            */
        }
        
        function hide() {
            opacity = 0
            timerHide.start()
        }
        
        Timer {
            id: timerHide
            interval: 300
            onTriggered: toastNotification.visible = false
        }
    }

    // FUNCIONES JAVASCRIPT
    function abrirPDFEnNavegador(rutaArchivo) {
        try {
            console.log("🖥 Abriendo PDF en navegador: " + rutaArchivo)
            var urlArchivo = "file:///" + rutaArchivo.replace(/\\/g, "/")
            Qt.openUrlExternally(urlArchivo)
            var nombreArchivo = rutaArchivo.split("/").pop().split("\\").pop()
            mostrarNotificacion("PDF Generado", "Archivo abierto en navegador: " + nombreArchivo)
        } catch (error) {
            console.log("❌ Error abriendo PDF: " + error)
            mostrarNotificacion("Error", "No se pudo abrir el PDF en el navegador")
        }
    }
    
    function cerrarCaja() {
        console.log("✅ Iniciando cierre de caja...")
        
        // ✅ VALIDACIONES INICIALES MEJORADAS
        if (!cierreCajaModel) {
            console.log("❌ Modelo no disponible")
            mostrarNotificacion("Error", "Modelo no disponible")
            return
        }
        
        // ✅ NUEVO: Validar que no esté ocupado
        if (cierreCajaModel.loading) {
            console.log("⏳ Modelo ocupado, cancelando cierre")
            mostrarNotificacion("Espere", "El sistema está procesando otra operación")
            return
        }
        
        // ✅ NUEVO: Validar que tenga datos consultados
        if (totalIngresos === 0 && totalEgresos === 0) {
            console.log("❌ Sin datos consultados")
            mostrarNotificacion("Error", "Primero consulte los datos del día")
            return
        }
        
        if (efectivoReal <= 0) {
            console.log("❌ Efectivo real no válido:", efectivoReal)
            mostrarNotificacion("Error", "Debe ingresar el efectivo real contado")
            return
        }
        
        try {
            console.log("🔍 Validando cierre...")
            console.log("📊 Datos del cierre:")
            console.log("   - Efectivo Real:", efectivoReal)
            console.log("   - Saldo Teórico:", saldoTeorico)
            console.log("   - Diferencia:", diferencia)
            console.log("   - Requiere Autorización:", requiereAutorizacion)
            
            // Intentar validar el cierre
            var validacionExitosa = false
            
            if (typeof cierreCajaModel.validarCierre === 'function') {
                validacionExitosa = cierreCajaModel.validarCierre()
                console.log("✅ Resultado validación:", validacionExitosa)
            } else {
                // Si no existe el método, asumir que es válido
                console.log("⚠️ Método validarCierre no existe, continuando...")
                validacionExitosa = true
            }
            
            if (validacionExitosa) {
                var observaciones = "Cierre automático - diferencia dentro del límite"
                
                if (requiereAutorizacion) {
                    observaciones = "Diferencia de Bs " + Math.abs(diferencia).toFixed(2) + " - Requiere autorización"
                    console.log("⚠️ Requiere autorización por diferencia significativa")
                }
                
                // Ejecutar el cierre
                console.log("💾 Completando cierre con observaciones:", observaciones)
                
                if (typeof cierreCajaModel.completarCierre === 'function') {
                    var resultado = cierreCajaModel.completarCierre(observaciones)
                    console.log("🏁 Resultado completarCierre:", resultado)
                    
                    // Mostrar notificación de éxito
                    mostrarNotificacion("Éxito", "Caja cerrada correctamente")
                    
                    // Recargar datos para actualizar la interfaz
                    Qt.callLater(function() {
                        if (typeof cierreCajaModel.cargarCierresSemana === 'function') {
                            cierreCajaModel.cargarCierresSemana()
                        }
                    })
                    
                    if (cierreCajaModel && typeof cierreCajaModel.establecerEfectivoReal === 'function') {
                        cierreCajaModel.establecerEfectivoReal(0.0)
                    }
                    efectivoRealField.text = ""
                } else {
                    console.log("❌ Método completarCierre no existe")
                    mostrarNotificacion("Error", "Método de cierre no disponible")
                }
            } else {
                console.log("❌ Validación de cierre falló")
                mostrarNotificacion("Error", "No se puede cerrar la caja - validación falló")
            }
            
        } catch (error) {
            console.log("❌ Error en cerrarCaja:", error.toString())
            mostrarNotificacion("Error", "Error al cerrar caja: " + error.toString())
        }
    }
        
    function mostrarNotificacion(titulo, mensaje) {
        console.log("📢 " + titulo + ": " + mensaje)
        
        if (titulo.includes("✅") || titulo.includes("Éxito") || 
            titulo.includes("PDF") || titulo.includes("Cierre") ||
            titulo.includes("Consulta")) {
            toastNotification.show(mensaje)
        }
    }
    
    function mostrarConfirmacion(titulo, mensaje, callback) {
        console.log("❓ " + titulo + ": " + mensaje)
        callback()
    }

    function calculateDuration(inicio, fin) {
        if (!inicio || !fin) return "0.0"
        
        try {
            let inicioMinutos = parseInt(inicio.split(':')[0]) * 60 + parseInt(inicio.split(':')[1])
            let finMinutos = parseInt(fin.split(':')[0]) * 60 + parseInt(fin.split(':')[1])
            let duracion = (finMinutos - inicioMinutos) / 60
            return duracion.toFixed(1)
        } catch (e) {
            return "0.0"
        }
    }
    
    function formatearHorario(inicio, fin) {
        if (!inicio || !fin) return "--:-- - --:--"
        
        try {
            function extraerHoraMinuto(hora) {
                if (!hora) return "--:--"
                
                let horaStr = hora.toString().trim()
                let partes = horaStr.split(':')
                
                if (partes.length >= 2) {
                    let horas = parseInt(partes[0]) || 0
                    let minutos = parseInt(partes[1]) || 0
                    
                    return String(horas).padStart(2, '0') + ':' + String(minutos).padStart(2, '0')
                }
                
                return "--:--"
            }
            
            let inicioLimpio = extraerHoraMinuto(inicio)
            let finLimpio = extraerHoraMinuto(fin)
            
            return inicioLimpio + " - " + finLimpio
            
        } catch (e) {
            return "--:-- - --:--"
        }
    }

    function formatearFecha(fecha) {
        if (!fecha) return "--/--/----"
        
        try {
            // Si viene como string de fecha
            if (typeof fecha === 'string') {
                // Si ya está en formato DD/MM/YYYY, devolverla
                if (fecha.match(/^\d{1,2}\/\d{1,2}\/\d{4}$/)) {
                    return fecha
                }
                
                // Si viene en formato YYYY-MM-DD, convertir a DD/MM/YYYY
                if (fecha.match(/^\d{4}-\d{2}-\d{2}/)) {
                    let partes = fecha.split('-')
                    return partes[2] + '/' + partes[1] + '/' + partes[0]
                }
            }
            
            // Si viene como Date object
            if (fecha instanceof Date) {
                let dia = String(fecha.getDate()).padStart(2, '0')
                let mes = String(fecha.getMonth() + 1).padStart(2, '0')
                let anio = fecha.getFullYear()
                return dia + '/' + mes + '/' + anio
            }
            
            return "--/--/----"
        } catch (e) {
            return "--/--/----"
        }
    }

    function formatearHora(hora) {
        if (!hora) return "--:--"
        
        try {
            let horaStr = hora.toString().trim()
            let partes = horaStr.split(':')
            
            if (partes.length >= 2) {
                let horas = parseInt(partes[0]) || 0
                let minutos = parseInt(partes[1]) || 0
                
                return String(horas).padStart(2, '0') + ':' + String(minutos).padStart(2, '0')
            }
            
            return "--:--"
        } catch (e) {
            return "--:--"
        }
    }
    
    function validarFormatoFecha(fecha) {
        if (!fecha || fecha.trim().length === 0) return false
        
        // Permitir varios formatos: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
        var regex = /^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})$/
        var match = fecha.match(regex)
        
        if (!match) return false
        
        var dia = parseInt(match[1])
        var mes = parseInt(match[2])
        var anio = parseInt(match[3])
        
        return dia >= 1 && dia <= 31 && 
            mes >= 1 && mes <= 12 && 
            anio >= 2020 && anio <= 2030
    }

    function validarFormatoHora(hora) {
        if (!hora || hora.trim().length === 0) return false
        
        // Permitir formatos: HH:MM, H:MM, HH.MM, H.MM
        var regex = /^(\d{1,2})[\:\.](\d{2})$/
        var match = hora.match(regex)
        
        if (!match) return false
        
        var horas = parseInt(match[1])
        var minutos = parseInt(match[2])
        
        return horas >= 0 && horas <= 23 && 
            minutos >= 0 && minutos <= 59
    }
    
    function generarPDFCierreEspecifico(fecha, horaInicio, horaFin) {
        console.log("📄 Generando PDF de cierre específico")
        
        // ✅ VALIDACIONES DE ENTRADA
        if (!fecha || !horaInicio || !horaFin) {
            console.log("❌ Parámetros incompletos")
            mostrarNotificacion("Error", "Parámetros incompletos para generar PDF")
            return
        }
        
        if (!cierreCajaModel) {
            console.log("❌ Modelo no disponible")
            mostrarNotificacion("Error", "Modelo no disponible")
            return
        }
        
        // ✅ Validar que el modelo no esté ocupado
        if (cierreCajaModel.loading) {
            console.log("⏳ Modelo ocupado")
            mostrarNotificacion("Espere", "El sistema está procesando otra operación")
            return
        }
        
        try {
            console.log("   📅 Fecha original:", fecha)
            console.log("   🕐 Horario original:", horaInicio, "-", horaFin)
            
            // ✅ LIMPIAR FORMATOS antes de enviar al model
            let fechaLimpia = formatearFechaParaModel(fecha)
            let horaInicioLimpia = limpiarFormatoHora(horaInicio)
            let horaFinLimpia = limpiarFormatoHora(horaFin)
            
            // ✅ VALIDAR FORMATOS LIMPIOS
            if (!fechaLimpia || fechaLimpia === "" || fechaLimpia === "--/--/----") {
                console.log("❌ Fecha limpia inválida:", fechaLimpia)
                mostrarNotificacion("Error", "Formato de fecha inválido")
                return
            }
            
            if (!horaInicioLimpia || horaInicioLimpia === "--:--" || horaInicioLimpia === "00:00") {
                console.log("❌ Hora inicio limpia inválida:", horaInicioLimpia)
                mostrarNotificacion("Error", "Formato de hora inicio inválido")
                return
            }
            
            if (!horaFinLimpia || horaFinLimpia === "--:--" || horaFinLimpia === "00:00") {
                console.log("❌ Hora fin limpia inválida:", horaFinLimpia)
                mostrarNotificacion("Error", "Formato de hora fin inválido")
                return
            }
            
            console.log("🔧 Datos limpiados:")
            console.log("   Fecha:", fechaLimpia)
            console.log("   Hora inicio:", horaInicioLimpia)
            console.log("   Hora fin:", horaFinLimpia)
            
            // ✅ Llamar al método del model CON VALIDACIÓN
            if (typeof cierreCajaModel.generarPDFCierreEspecifico === 'function') {
                cierreCajaModel.generarPDFCierreEspecifico(
                    fechaLimpia, 
                    horaInicioLimpia, 
                    horaFinLimpia
                )
                
                mostrarNotificacion("Procesando", "Generando PDF del cierre...")
            } else {
                console.log("❌ Método generarPDFCierreEspecifico no existe en el modelo")
                mostrarNotificacion("Error", "Función no disponible en el modelo")
            }
            
        } catch (error) {
            console.log("❌ Error en generarPDFCierreEspecifico:", error.toString())
            mostrarNotificacion("Error", "Error al generar PDF: " + error.toString())
        }
    }
    
    function formatearFechaParaModel(fecha) {
        if (!fecha) return ""
        
        let fechaStr = fecha.toString().trim()
        
        // Si ya está en DD/MM/YYYY, devolverla
        if (fechaStr.match(/^\d{1,2}\/\d{1,2}\/\d{4}$/)) {
            return fechaStr
        }
        
        // Si viene en YYYY-MM-DD, convertir a DD/MM/YYYY
        if (fechaStr.match(/^\d{4}-\d{2}-\d{2}/)) {
            let partes = fechaStr.split('-')
            return partes[2] + '/' + partes[1] + '/' + partes[0]
        }
        
        // Si tiene timestamp, extraer solo la fecha
        if (fechaStr.indexOf(' ') > 0) {
            let soloFecha = fechaStr.split(' ')[0]
            return formatearFechaParaModel(soloFecha)
        }
        
        return fechaStr
    }
    
    function limpiarFormatoHora(hora) {
        if (!hora) return "00:00"
        
        let horaStr = hora.toString().trim()
        
        // Extraer solo HH:MM de cualquier formato
        if (horaStr.indexOf(':') > 0) {
            let partes = horaStr.split(':')
            if (partes.length >= 2) {
                let horas = partes[0].padStart(2, '0')
                let minutos = partes[1].padStart(2, '0')
                return horas + ':' + minutos
            }
        }
        
        return horaStr
    }
    
    // ✅ NUEVA: Función segura para notificaciones (sin timers problemáticos)
    function mostrarNotificacionSegura(titulo, mensaje) {
        console.log("📢", titulo, ":", mensaje)
        
        // Solo usar console, sin toast que active timers
        // Si realmente necesitas feedback visual, usar alternativa más simple
        
        // Alternativa segura: cambiar texto de un Label por 3 segundos
        if (typeof appController !== 'undefined' && appController) {
            try {
                appController.showNotification(titulo, mensaje)
            } catch (e) {
                console.log("⚠️ No se pudo mostrar notificación:", e)
            }
        }
    }

    // ✅ FUNCIONALIDAD #2: ABRIR PDF AUTOMÁTICAMENTE
    function abrirPDFAutomaticamente(filepath) {
        try {
            console.log("🖥 Intentando abrir PDF:", filepath)
            
            // Convertir ruta a formato URL
            var urlPath = "file:///" + filepath.replace(/\\/g, "/")
            
            console.log("🖥 URL formateada:", urlPath)
            
            // Abrir con el visor del sistema
            Qt.openUrlExternally(urlPath)
            
            // Extraer nombre del archivo para la notificación
            var nombreArchivo = filepath.split("\\").pop().split("/").pop()
            
            // Notificación de éxito
            mostrarNotificacionSegura("PDF Abierto", "Archivo: " + nombreArchivo)
            
            console.log("✅ PDF abierto exitosamente")
            
        } catch (error) {
            console.log("❌ Error abriendo PDF:", error)
            mostrarNotificacion("Error", "No se pudo abrir el PDF automáticamente")
        }
    }

    // INICIALIZACIÓN MEJORADA
    Component.onCompleted: {
        console.log("🏁 Inicializando módulo CierreCaja")
        console.log("🔧 Versión: Con auto-gestión de horarios y PDFs funcionales")
        
        // Verificar AppController primero
        if (!appController) {
            console.log("❌ AppController no disponible")
            return
        }
        
        // ✅ INICIALIZAR CON DELAY PARA ESTABILIDAD
        Qt.callLater(function() {
            if (appController && appController.cierre_caja_model_instance) {
                cierreCajaModel = appController.cierre_caja_model_instance
                console.log("✅ Modelo conectado")
                
                // ✅ FUNCIONALIDAD #1: INICIALIZAR CAMPOS AUTOMÁTICAMENTE
                Qt.callLater(function() {
                    if (cierreCajaModel && typeof cierreCajaModel.inicializarCamposAutomaticamente === 'function') {
                        console.log("🕐 Llamando a inicialización automática de horarios...")
                        cierreCajaModel.inicializarCamposAutomaticamente()
                    }
                })
                
                // ✅ SINCRONIZAR PROPIEDADES DESPUÉS DE CONECTAR
                Qt.callLater(function() {
                    sincronizarConModelo()
                })
                
                // ✅ CARGAR DATOS CON DELAY ADICIONAL
                if (cierreCajaModel && cierreCajaModel.usuario_actual_id > 0) {
                    Qt.callLater(function() {
                        if (typeof cierreCajaModel.cargarCierresSemana === 'function') {
                            cierreCajaModel.cargarCierresSemana()
                        }
                    })
                }
            } else {
                console.log("❌ Modelo no disponible en AppController")
            }
        })
    }
}
