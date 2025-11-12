import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

/**
 * COMPONENTE: Sección de Especialidades Médicas
 * 
 * Este componente se muestra solo cuando el tipo de trabajador seleccionado
 * tiene area_funcional='MEDICO' y permite:
 * - Seleccionar especialidades de la tabla Especialidad
 * - Marcar una como principal
 * - Ver lista de especialidades asignadas
 * - Quitar especialidades
 * 
 * PROPS REQUERIDAS:
 * - trabajadorModel: Instancia del TrabajadorModel
 * - trabajadorId: ID del trabajador médico (si está en modo edición)
 * - isEditMode: Boolean que indica si está en modo edición
 * - baseUnit: Unidad base para tamaños
 * - fontBaseSize: Tamaño base de fuente
 */
GroupBox {
    id: especialidadesSection
    Layout.fillWidth: true
    title: "⚕️ ESPECIALIDADES MÉDICAS"
    font.bold: true
    font.pixelSize: fontBaseSize
    font.family: "Segoe UI, Arial, sans-serif"
    padding: baseUnit * 1.5
    visible: false  // Se mostrará dinámicamente cuando sea médico
    
    // Props requeridas
    property var trabajadorModel: null
    property int trabajadorId: -1
    property bool isEditMode: false
    
    // Props de estilo (deben venir del padre)
    property real baseUnit: 8
    property real fontBaseSize: 12
    property string primaryColor: "#3498DB"
    property string successColor: "#10B981"
    property string dangerColor: "#E74C3C"
    property string whiteColor: "#FFFFFF"
    property string textColor: "#2c3e50"
    property string textColorLight: "#6B7280"
    
    // Datos internos
    property var especialidadesDisponibles: []
    property var especialidadesAsignadas: []
    property var especialidadesPendientes: []  // Para modo creación
    
    background: Rectangle {
        color: "#E8F5E9"  // Verde claro para diferenciar sección médica
        border.color: successColor
        border.width: 2
        radius: baseUnit * 0.8
    }
    
    // Cargar datos cuando se hace visible
    onVisibleChanged: {
        if (visible) {
            cargarEspecialidadesDisponibles()
            
            // Si está en modo edición, cargar especialidades asignadas
            if (isEditMode && trabajadorId > 0) {
                console.log("🔄 Cargando especialidades del médico existente ID:", trabajadorId)
                cargarEspecialidadesAsignadas()
            } else {
                // En modo creación, limpiar lista
                console.log("🆕 Modo creación - limpiando especialidades")
                especialidadesAsignadas = []
                especialidadesPendientes = []
                especialidadesListView.model = []
            }
        }
    }
    
    // Función para cargar especialidades disponibles
    function cargarEspecialidadesDisponibles() {
        if (!trabajadorModel) {
            console.log("⚠️ TrabajadorModel no disponible")
            return
        }
        
        console.log("🔍 Cargando especialidades disponibles...")
        especialidadesDisponibles = trabajadorModel.obtenerEspecialidadesDisponibles()
        especialidadesCombo.actualizarModelo()
    }
    
    // Función para cargar especialidades asignadas (modo edición)
    function cargarEspecialidadesAsignadas() {
        if (!trabajadorModel || trabajadorId <= 0) {
            console.log("⚠️ No se puede cargar especialidades: médico no válido")
            return
        }
        
        console.log("🔍 Cargando especialidades asignadas al médico", trabajadorId)
        especialidadesAsignadas = trabajadorModel.obtenerEspecialidadesDeMedico(trabajadorId)
        especialidadesListView.model = especialidadesAsignadas
    }
    
    // Función para agregar especialidad (modo edición)
    function agregarEspecialidadDirecta() {
        if (especialidadesCombo.currentIndex <= 0) {
            console.log("⚠️ No se seleccionó especialidad")
            return
        }
        
        var especialidadSeleccionada = especialidadesDisponibles[especialidadesCombo.currentIndex - 1]
        var esPrincipal = checkboxPrincipal.checked
        
        console.log("➕ Agregando especialidad:", especialidadSeleccionada.nombre, "Principal:", esPrincipal)
        
        // En modo edición: asignar directamente
        if (isEditMode && trabajadorId > 0) {
            var success = trabajadorModel.asignarEspecialidadAMedico(
                trabajadorId,
                especialidadSeleccionada.id,
                esPrincipal
            )
            
            if (success) {
                // Recargar lista
                cargarEspecialidadesAsignadas()
                especialidadesCombo.currentIndex = 0
                checkboxPrincipal.checked = false
            }
        } else {
            // En modo creación: agregar a lista pendiente
            agregarEspecialidadPendiente(especialidadSeleccionada, esPrincipal)
        }
    }
    
    // Función para agregar a lista pendiente (modo creación)
    function agregarEspecialidadPendiente(especialidad, esPrincipal) {
        // Verificar si ya está en la lista
        for (var i = 0; i < especialidadesPendientes.length; i++) {
            if (especialidadesPendientes[i].id === especialidad.id) {
                console.log("⚠️ Especialidad ya agregada")
                return
            }
        }
        
        // Si se marca como principal, quitar marca de otras
        if (esPrincipal) {
            for (var j = 0; j < especialidadesPendientes.length; j++) {
                especialidadesPendientes[j].es_principal = false
            }
        }
        
        // Agregar a lista
        var nuevaEspecialidad = {
            id: especialidad.id,
            nombre: especialidad.nombre,
            es_principal: esPrincipal,
            detalles: especialidad.detalles
        }
        
        especialidadesPendientes.push(nuevaEspecialidad)
        especialidadesListView.model = especialidadesPendientes
        
        especialidadesCombo.currentIndex = 0
        checkboxPrincipal.checked = false
        
        console.log("✅ Especialidad agregada a lista pendiente:", especialidad.nombre)
    }
    
    // Función para quitar especialidad
    function quitarEspecialidad(especialidadId, index) {
        console.log("➖ Quitando especialidad ID:", especialidadId)
        
        if (isEditMode && trabajadorId > 0) {
            // En modo edición: desasignar directamente
            var success = trabajadorModel.desasignarEspecialidadDeMedico(
                trabajadorId,
                especialidadId
            )
            
            if (success) {
                cargarEspecialidadesAsignadas()
            }
        } else {
            // En modo creación: quitar de lista pendiente
            especialidadesPendientes.splice(index, 1)
            especialidadesListView.model = especialidadesPendientes
        }
    }
    
    // Función pública para obtener especialidades pendientes
    function obtenerEspecialidadesPendientes() {
        return especialidadesPendientes
    }
    
    ColumnLayout {
        width: parent.width
        spacing: baseUnit * 2
        
        // INFO: Explicación
        Label {
            Layout.fillWidth: true
            text: isEditMode ? 
                  "Las especialidades se asignan y guardan inmediatamente. Seleccione especialidades de la lista y márquelas como principal si corresponde." :
                  "Agregue las especialidades que el médico puede ofrecer. Al guardar el trabajador, se crearán las asignaciones."
            color: textColorLight
            font.pixelSize: fontBaseSize * 0.9
            font.family: "Segoe UI, Arial, sans-serif"
            wrapMode: Text.WordWrap
            font.italic: true
        }
        
        // SELECTOR DE ESPECIALIDAD
        RowLayout {
            Layout.fillWidth: true
            spacing: baseUnit * 1.5
            
            Label {
                text: "Especialidad:"
                font.bold: true
                color: textColor
                font.family: "Segoe UI, Arial, sans-serif"
                Layout.preferredWidth: baseUnit * 12
            }
            
            ComboBox {
                id: especialidadesCombo
                Layout.fillWidth: true
                font.pixelSize: fontBaseSize
                font.family: "Segoe UI, Arial, sans-serif"
                
                // Modelo dinámico
                model: ["Seleccionar especialidad..."]
                
                function actualizarModelo() {
                    var items = ["Seleccionar especialidad..."]
                    for (var i = 0; i < especialidadesDisponibles.length; i++) {
                        items.push(especialidadesDisponibles[i].nombre)
                    }
                    model = items
                    console.log("📋 ComboBox actualizado con", items.length - 1, "especialidades")
                }
            }
            
            CheckBox {
                id: checkboxPrincipal
                text: "Es principal"
                font.pixelSize: fontBaseSize * 0.9
                font.family: "Segoe UI, Arial, sans-serif"
            }
            
            Button {
                text: "➕ Agregar"
                enabled: especialidadesCombo.currentIndex > 0
                Layout.preferredHeight: baseUnit * 4
                
                background: Rectangle {
                    color: parent.enabled ? 
                           (parent.pressed ? Qt.darker(successColor, 1.2) : 
                           (parent.hovered ? Qt.lighter(successColor, 1.1) : successColor)) :
                           "#bdc3c7"
                    radius: baseUnit * 0.5
                }
                
                contentItem: Label {
                    text: parent.text
                    font.pixelSize: fontBaseSize * 0.9
                    font.bold: true
                    font.family: "Segoe UI, Arial, sans-serif"
                    color: whiteColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: agregarEspecialidadDirecta()
            }
        }
        
        // LISTA DE ESPECIALIDADES ASIGNADAS/PENDIENTES
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 20
            color: whiteColor
            border.color: "#e0e0e0"
            border.width: 1
            radius: baseUnit * 0.5
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: baseUnit
                spacing: baseUnit * 0.5
                
                Label {
                    text: isEditMode ? "Especialidades asignadas:" : "Especialidades pendientes de asignar:"
                    font.bold: true
                    color: textColor
                    font.pixelSize: fontBaseSize * 0.95
                    font.family: "Segoe UI, Arial, sans-serif"
                }
                
                ListView {
                    id: especialidadesListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: baseUnit * 0.5
                    
                    model: isEditMode ? especialidadesAsignadas : especialidadesPendientes
                    
                    delegate: Rectangle {
                        width: especialidadesListView.width
                        height: baseUnit * 5
                        color: modelData.es_principal ? "#E8F5E9" : whiteColor
                        border.color: modelData.es_principal ? successColor : "#e0e0e0"
                        border.width: modelData.es_principal ? 2 : 1
                        radius: baseUnit * 0.5
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: baseUnit
                            spacing: baseUnit
                            
                            Label {
                                text: modelData.es_principal ? "⭐" : "•"
                                font.pixelSize: fontBaseSize * 1.2
                                Layout.preferredWidth: baseUnit * 2
                            }
                            
                            Label {
                                text: modelData.nombre
                                font.pixelSize: fontBaseSize * 0.95
                                font.family: "Segoe UI, Arial, sans-serif"
                                font.bold: modelData.es_principal
                                color: textColor
                                Layout.fillWidth: true
                            }
                            
                            Label {
                                text: modelData.es_principal ? "(Principal)" : ""
                                font.pixelSize: fontBaseSize * 0.85
                                font.family: "Segoe UI, Arial, sans-serif"
                                font.italic: true
                                color: successColor
                                visible: modelData.es_principal
                            }
                            
                            Button {
                                text: "✕"
                                Layout.preferredWidth: baseUnit * 3
                                Layout.preferredHeight: baseUnit * 3
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(dangerColor, 1.2) :
                                           (parent.hovered ? dangerColor : "transparent")
                                    radius: baseUnit * 0.3
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    font.pixelSize: fontBaseSize
                                    font.bold: true
                                    color: parent.hovered ? whiteColor : dangerColor
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: quitarEspecialidad(modelData.id, index)
                            }
                        }
                    }
                    
                    // Mensaje cuando está vacía
                    Label {
                        anchors.centerIn: parent
                        visible: especialidadesListView.count === 0
                        text: "No hay especialidades asignadas"
                        color: textColorLight
                        font.pixelSize: fontBaseSize * 0.9
                        font.italic: true
                    }
                }
            }
        }
        
        // NOTA IMPORTANTE
        Label {
            Layout.fillWidth: true
            text: isEditMode ? 
                  "✓ Los cambios se guardan inmediatamente" :
                  "ℹ Las especialidades se asignarán al guardar el trabajador"
            color: textColorLight
            font.pixelSize: fontBaseSize * 0.85
            font.family: "Segoe UI, Arial, sans-serif"
            font.italic: true
        }
    }
}
