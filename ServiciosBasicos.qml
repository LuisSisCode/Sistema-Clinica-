import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: serviciosBasicosRoot
    objectName: "serviciosBasicosRoot"
    
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
    // ===== ELIMINADA: property bool showConfigTiposGastosDialog: false =====
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    // Propiedades de paginación para servicios básicos
    property int itemsPerPageServicios: 10
    property int currentPageServicios: 0
    property int totalPagesServicios: 0
    
    // ===== PROPIEDAD PARA EXPONER EL MODELO DE DATOS =====
    property alias tiposGastosModel: tiposGastosModel
    
    // Modelo de tipos de gastos - CAMBIADO A ListModel
    ListModel {
        id: tiposGastosModel
        
        Component.onCompleted: {
            // Cargar datos iniciales
            append({
                nombre: "Servicios Públicos", 
                descripcion: "Gastos de agua, luz, internet, teléfono y otros servicios básicos",
                ejemplos: ["Agua potable", "Energía eléctrica", "Internet", "Teléfono fijo", "Gas natural"],
                color: infoColor
            })
            append({
                nombre: "Personal", 
                descripcion: "Gastos relacionados con salarios, bonos y prestaciones del personal",
                ejemplos: ["Salarios", "Bonos", "Aguinaldos", "Prestaciones sociales", "Capacitación"],
                color: violetColor
            })
            append({
                nombre: "Alimentación", 
                descripcion: "Gastos de comida para personal y refrigerios",
                ejemplos: ["Almuerzo personal", "Refrigerios", "Café", "Agua purificada", "Desayunos"],
                color: successColor
            })
            append({
                nombre: "Mantenimiento", 
                descripcion: "Gastos de limpieza, reparaciones y mantenimiento de equipos",
                ejemplos: ["Limpieza", "Reparación equipos", "Mantenimiento preventivo", "Materiales", "Herramientas"],
                color: warningColor
            })
            append({
                nombre: "Administrativos", 
                descripcion: "Gastos de papelería, licencias, seguros y administración",
                ejemplos: ["Papelería", "Licencias software", "Seguros", "Impuestos", "Trámites legales"],
                color: primaryColor
            })
            append({
                nombre: "Suministros Médicos", 
                descripcion: "Gastos de insumos médicos y materiales de uso clínico",
                ejemplos: ["Gasas", "Jeringas", "Medicamentos básicos", "Alcohol", "Guantes"],
                color: "#e67e22"
            })
        }
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

    // Modelo para gastos existentes
    property var gastosModel: [
        {
            gastoId: "1",
            tipoGasto: "Servicios Públicos",
            descripcion: "Factura de energía eléctrica - Enero 2025",
            monto: "450.00",
            fechaGasto: "2025-01-31",
            proveedorEmpresa: "DELAPAZ S.A.",
            registradoPor: "Luis López"
        },
        {
            gastoId: "2",
            tipoGasto: "Personal",
            descripcion: "Pago quincenal - Personal administrativo",
            monto: "12500.00",
            fechaGasto: "2025-06-15",
            proveedorEmpresa: "Clínica San Rafael",
            registradoPor: "Luis López"
        },
        {
            gastoId: "3",
            tipoGasto: "Alimentación",
            descripcion: "Refrigerios para personal - Semana 25",
            monto: "280.50",
            fechaGasto: "2025-06-20",
            proveedorEmpresa: "Panadería Central",
            registradoPor: "Luis López"
        },
        {
            gastoId: "4",
            tipoGasto: "Mantenimiento",
            descripcion: "Reparación de aire acondicionado - Consulta 2",
            monto: "350.00",
            fechaGasto: "2025-06-18",
            proveedorEmpresa: "Refrigeración López",
            registradoPor: "Luis López"
        },
        {
            gastoId: "5",
            tipoGasto: "Administrativos",
            descripcion: "Renovación licencia software de gestión",
            monto: "890.00",
            fechaGasto: "2025-06-10",
            proveedorEmpresa: "TechSoft Bolivia",
            registradoPor: "Luis López"
        },
        {
            gastoId: "6",
            tipoGasto: "Suministros Médicos",
            descripcion: "Compra de insumos médicos - Mes de junio",
            monto: "650.75",
            fechaGasto: "2025-06-19",
            proveedorEmpresa: "Farmacéutica del Sur",
            registradoPor: "Luis López"
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 32
        
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
                
                // Header de Servicios Básicos - FIJO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: "#f8f9fa"
                    border.color: "#e0e0e0"
                    border.width: 1
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: 20
                        color: parent.color
                        radius: parent.radius
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        
                        RowLayout {
                            spacing: 12
                            
                            Label {
                                text: "💰"
                                font.pixelSize: 24
                                color: primaryColor
                            }
                            
                            Label {
                                text: "Gestión de Servicios Básicos y Gastos Operativos"
                                font.pixelSize: 20
                                font.bold: true
                                color: textColor
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            objectName: "newGastoButton"
                            text: "➕ Nuevo Gasto"
                            
                            background: Rectangle {
                                color: primaryColor
                                radius: 12
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
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
                
                // Filtros y búsqueda - FIJO (SIN FILTRO DE ESTADO)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "transparent"
                    z: 10
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 32
                        spacing: 16
                        
                        Label {
                            text: "Filtrar por:"
                            font.bold: true
                            color: textColor
                        }
                        
                        ComboBox {
                            id: filtroTipoGasto
                            Layout.preferredWidth: 180
                            model: getTiposGastosNombres()
                            currentIndex: 0
                            onCurrentIndexChanged: aplicarFiltros()
                        }
                        
                        Label {
                            text: "Fecha:"
                            font.bold: true
                            color: textColor
                        }
                        
                        ComboBox {
                            id: filtroFecha
                            Layout.preferredWidth: 120
                            model: ["Todas", "Este mes", "Mes anterior", "Últimos 3 meses"]
                            currentIndex: 0
                            onCurrentIndexChanged: aplicarFiltros()
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        TextField {
                            id: campoBusqueda
                            Layout.preferredWidth: 200
                            placeholderText: "Buscar gasto..."
                            onTextChanged: aplicarFiltros()
                            
                            background: Rectangle {
                                color: whiteColor
                                border.color: "#e0e0e0"
                                border.width: 1
                                radius: 8
                            }
                        }
                    }
                }
               
                // Contenedor para tabla con scroll limitado
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 32
                    
                    ScrollView {
                        anchors.fill: parent
                        clip: true
                        
                        ListView {
                            id: gastosListView
                            model: ListModel {
                                id: gastosListModel
                                Component.onCompleted: {
                                    // Cargar datos iniciales
                                    for (var i = 0; i < gastosModel.length; i++) {
                                        append(gastosModel[i])
                                    }
                                }
                            }
                            
                            header: Rectangle {
                                width: parent.width
                                height: 40
                                color: "#f5f5f5"
                                border.color: "#d0d0d0"
                                border.width: 1
                                z: 5
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(50, parent.width * 0.06)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "ID"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(140, parent.width * 0.18)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "TIPO DE GASTO"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(180, parent.width * 0.25)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "DESCRIPCIÓN"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(90, parent.width * 0.12)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "MONTO"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(100, parent.width * 0.14)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "FECHA GASTO"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(130, parent.width * 0.17)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "PROVEEDOR"
                                            font.bold: true
                                            font.pixelSize: 12
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
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                }
                            }
                            
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 80
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
                                        Layout.preferredWidth: Math.max(50, parent.width * 0.06)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: model.gastoId
                                            color: textColor
                                            font.bold: true
                                            font.pixelSize: 12
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(140, parent.width * 0.18)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: Math.min(130, parent.width - 8)
                                            height: 20
                                            color: {
                                                switch(model.tipoGasto) {
                                                    case "Servicios Públicos": return infoColor
                                                    case "Personal": return violetColor
                                                    case "Alimentación": return successColor
                                                    case "Mantenimiento": return warningColor
                                                    case "Administrativos": return primaryColor
                                                    case "Suministros Médicos": return "#e67e22"
                                                    default: return "#95a5a6"
                                                }
                                            }
                                            radius: 12
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.tipoGasto
                                                color: whiteColor
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(180, parent.width * 0.25)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            text: model.descripcion
                                            color: textColor
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 3
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(90, parent.width * 0.12)
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
                                            font.pixelSize: 12
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(100, parent.width * 0.14)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: model.fechaGasto
                                            color: textColor
                                            font.pixelSize: 11
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(130, parent.width * 0.17)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            text: model.proveedorEmpresa
                                            color: "#7f8c8d"
                                            font.pixelSize: 11
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
                                            anchors.margins: 4
                                            text: model.registradoPor || "Luis López"
                                            color: "#7f8c8d"
                                            font.pixelSize: 12
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
                                
                                // Botones de acción que aparecen cuando se selecciona la fila
                                RowLayout {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    spacing: 4
                                    visible: selectedRowIndex === index
                                    z: 10
                                    
                                    Button {
                                        id: editButton
                                        width: 32
                                        height: 32
                                        text: "✏️"
                                        
                                        background: Rectangle {
                                            color: warningColor
                                            radius: 6
                                            border.color: "#f1c40f"
                                            border.width: 1
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: whiteColor
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 12
                                        }
                                        
                                        onClicked: {
                                            isEditMode = true
                                            editingIndex = index
                                            var gasto = gastosListModel.get(index)
                                            console.log("Editando gasto:", JSON.stringify(gasto))
                                            showNewGastoDialog = true
                                        }
                                    }
                                    
                                    Button {
                                        id: deleteButton
                                        width: 32
                                        height: 32
                                        text: "🗑️"
                                        
                                        background: Rectangle {
                                            color: dangerColor
                                            radius: 6
                                            border.color: "#c0392b"
                                            border.width: 1
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: whiteColor
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 12
                                        }
                                        
                                        onClicked: {
                                            gastosListModel.remove(index)
                                            selectedRowIndex = -1
                                            console.log("Gasto eliminado en índice:", index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // Control de Paginación - Centrado con indicador
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#F8F9FA"
                    border.color: "#D5DBDB"
                    border.width: 1
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 20
                        
                        // Botón Anterior con flecha
                        Button {
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 36
                            text: "← Anterior"
                            enabled: currentPageServicios > 0
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? "#E5E7EB" : "#F3F4F6") : 
                                    "#E5E7EB"
                                radius: 18
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
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPageServicios > 0) {
                                    currentPageServicios--
                                    aplicarFiltros()
                                }
                            }
                        }
                        
                        // Indicador de página
                        Label {
                            text: "Página " + (currentPageServicios + 1) + " de " + Math.max(1, totalPagesServicios)
                            color: "#374151"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        // Botón Siguiente con flecha
                        Button {
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 36
                            text: "Siguiente →"
                            enabled: (currentPageServicios + 1) < totalPagesServicios
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") : 
                                    "#E5E7EB"
                                radius: 18
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if ((currentPageServicios + 1) < totalPagesServicios) {
                                    currentPageServicios++
                                    aplicarFiltros()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Diálogo Nuevo Gasto / Editar Gasto (SIN OPCIONES DE ESTADO)
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
        width: 600
        height: 550  // Reducido porque ya no hay opciones de estado
        color: whiteColor
        radius: 20
        border.color: lightGrayColor
        border.width: 2
        visible: showNewGastoDialog
        
        property int selectedTipoGastoIndex: -1
        
        // Función para cargar datos en modo edición
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
                
                // Cargar monto
                montoField.text = gasto.monto
                
                // Cargar fecha
                fechaGastoField.text = gasto.fechaGasto
                
                // Cargar proveedor
                proveedorField.text = gasto.proveedorEmpresa
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
                // Limpiar formulario para nuevo gasto
                tipoGastoCombo.currentIndex = 0
                tipoGastoCombo.model = getTiposGastosParaCombo() // Actualizar modelo
                descripcionField.text = ""
                montoField.text = ""
                fechaGastoField.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
                proveedorField.text = ""
                gastoForm.selectedTipoGastoIndex = -1
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20
            
            // Título
            Label {
                Layout.fillWidth: true
                text: isEditMode ? "Editar Gasto" : "Nuevo Gasto"
                font.pixelSize: 24
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
                    radius: 8
                }
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    
                    // Tipo de Gasto
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.preferredWidth: 120
                            text: "Tipo de Gasto:"
                            font.bold: true
                            color: textColor
                        }
                        ComboBox {
                            id: tipoGastoCombo
                            Layout.fillWidth: true
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
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.preferredWidth: 120
                            text: "Descripción:"
                            font.bold: true
                            color: textColor
                        }
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            
                            TextArea {
                                id: descripcionField
                                placeholderText: "Descripción detallada del gasto..."
                                wrapMode: TextArea.Wrap
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                        }
                    }
                    
                    // Monto y Fecha
                    RowLayout {
                        Layout.fillWidth: true
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "Monto (Bs):"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: montoField
                                Layout.fillWidth: true
                                placeholderText: "0.00"
                                validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "Fecha del Gasto:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: fechaGastoField
                                Layout.fillWidth: true
                                placeholderText: "YYYY-MM-DD"
                                text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                        }
                    }
                    
                    // Proveedor/Empresa
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.preferredWidth: 120
                            text: "Proveedor/Empresa:"
                            font.bold: true
                            color: textColor
                        }
                        TextField {
                            id: proveedorField
                            Layout.fillWidth: true
                            placeholderText: "Nombre del proveedor o empresa"
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 6
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
                    background: Rectangle {
                        color: lightGrayColor
                        radius: 8
                    }
                    contentItem: Label {
                        text: parent.text
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
                    enabled: gastoForm.selectedTipoGastoIndex >= 0 && 
                             descripcionField.text.length > 0 &&
                             montoField.text.length > 0 &&
                             proveedorField.text.length > 0
                    background: Rectangle {
                        color: parent.enabled ? primaryColor : "#bdc3c7"
                        radius: 8
                    }
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    onClicked: {
                        // Crear datos de gasto
                        var tipoGasto = tiposGastosModel.get(gastoForm.selectedTipoGastoIndex)
                        
                        var gastoData = {
                            tipoGasto: tipoGasto.nombre,
                            descripcion: descripcionField.text,
                            monto: parseFloat(montoField.text).toFixed(2),
                            fechaGasto: fechaGastoField.text,
                            proveedorEmpresa: proveedorField.text,
                            registradoPor: "Luis López"
                        }
                        
                        if (isEditMode && editingIndex >= 0) {
                            // Actualizar gasto existente - mantener el ID original
                            var gastoExistente = gastosListModel.get(editingIndex)
                            gastoData.gastoId = gastoExistente.gastoId
                            
                            gastosListModel.set(editingIndex, gastoData)
                            console.log("Gasto actualizado:", JSON.stringify(gastoData))
                        } else {
                            // Crear nuevo gasto con nuevo ID
                            gastoData.gastoId = (gastosListModel.count + 1).toString()
                            gastosListModel.append(gastoData)
                            console.log("Nuevo gasto guardado:", JSON.stringify(gastoData))
                        }
                        
                        // Actualizar filtros después de agregar/editar
                        filtroTipoGasto.model = getTiposGastosNombres()
                        
                        // Limpiar y cerrar
                        showNewGastoDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                    }
                }
            }
        }
    }
    
    // ===== ELIMINADOS: configTiposGastosBackground y configTiposGastosDialog =====
    
    // Función para aplicar filtros (SIN FILTRO DE ESTADO)
    function aplicarFiltros() {
        var hoy = new Date()
        var textoBusqueda = campoBusqueda.text.toLowerCase()
        var filteredGastos = []
        
        // Primero: Filtrar todos los elementos que cumplan los criterios
        for (var i = 0; i < gastosModel.length; i++) {
            var gasto = gastosModel[i]
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
            
            // Búsqueda por texto en descripción o proveedor
            if (textoBusqueda.length > 0 && mostrar) {
                if (!gasto.descripcion.toLowerCase().includes(textoBusqueda) && 
                    !gasto.proveedorEmpresa.toLowerCase().includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                filteredGastos.push(gasto)
            }
        }
        
        // Calcular total de páginas
        totalPagesServicios = Math.ceil(filteredGastos.length / itemsPerPageServicios)
        
        // Asegurar que la página actual esté dentro del rango
        currentPageServicios = Math.min(currentPageServicios, totalPagesServicios - 1)
        
        // Calcular índices de paginación
        var startIndex = currentPageServicios * itemsPerPageServicios
        var endIndex = Math.min(startIndex + itemsPerPageServicios, filteredGastos.length)
        
        // Limpiar modelo actual
        gastosListModel.clear()
        
        // Agregar solo los elementos de la página actual
        for (var j = startIndex; j < endIndex; j++) {
            gastosListModel.append(filteredGastos[j])
        }
    }
}