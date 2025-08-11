import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: enfermeriaRoot
    objectName: "enfermeriaRoot"
    
    // Acceso a colores
    readonly property color primaryColor: "#e91e63"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color emergencyColor: "#e67e22"
    
    // Usuario actual del sistema (simulado - en producción vendría del login)
    readonly property string currentUser: "Enfermera Ana María González"
    readonly property string currentUserRole: "Enfermera Jefe"
    
    // Propiedades para los diálogos
    property bool showNewProcedureDialog: false
    property bool showConfigProceduresDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1

    // ✅ PROPIEDADES DE PAGINACIÓN CORREGIDAS
    property int itemsPerPageEnfermeria: 10
    property int currentPageEnfermeria: 0
    property int totalPagesEnfermeria: 0

    // ✅ NUEVA PROPIEDAD PARA DATOS ORIGINALES
    property var procedimientosOriginales: []

    // Lista de trabajadores disponibles
    property var trabajadoresDisponibles: [
        "Dr. Carlos Mendoza",
        "Dra. María Fernández", 
        "Lic. Ana González",
        "Lic. José Pérez",
        "Lic. Miguel Torres",
        "Enf. Elena Vargas",
        "Enf. Roberto Silva"
    ]
    
    // Modelo de tipos de procedimientos de enfermería con precios normal y emergencia
    property var tiposProcedimientos: [
        { 
            nombre: "Curación Simple", 
            descripcion: "Limpieza y vendaje básico", 
            precioNormal: 25.0,
            precioEmergencia: 40.0
        },
        { 
            nombre: "Curación Avanzada", 
            descripcion: "Curación de heridas complejas", 
            precioNormal: 45.0,
            precioEmergencia: 70.0
        },
        { 
            nombre: "Inyección Intramuscular", 
            descripcion: "Administración de medicamento IM", 
            precioNormal: 15.0,
            precioEmergencia: 25.0
        },
        { 
            nombre: "Inyección Intravenosa", 
            descripcion: "Administración de medicamento IV", 
            precioNormal: 20.0,
            precioEmergencia: 35.0
        },
        { 
            nombre: "Control de Signos Vitales", 
            descripcion: "Medición de presión, temperatura, pulso", 
            precioNormal: 10.0,
            precioEmergencia: 18.0
        },
        { 
            nombre: "Colocación de Sonda", 
            descripcion: "Instalación de sonda vesical o nasogástrica", 
            precioNormal: 35.0,
            precioEmergencia: 55.0
        },
        { 
            nombre: "Nebulización", 
            descripcion: "Terapia respiratoria con nebulizador", 
            precioNormal: 18.0,
            precioEmergencia: 30.0
        }
    ]

    // ✅ DATOS AMPLIADOS PARA PROBAR PAGINACIÓN (12 procedimientos)
    property var procedimientosModelData: [
        {
            procedimientoId: "1",
            paciente: "María Elena López",
            tipoProcedimiento: "Curación Simple",
            cantidad: 1,
            tipo: "Normal",
            precioUnitario: "25.00",
            precioTotal: "25.00",
            fecha: "2025-06-15",
            trabajadorRealizador: "Lic. Ana González",
            registradoPor: "Luis López",
            observaciones: "Herida en proceso de cicatrización, evolución favorable"
        },
        {
            procedimientoId: "2",
            paciente: "Carlos Eduardo Martínez",
            tipoProcedimiento: "Inyección Intramuscular",
            cantidad: 3,
            tipo: "Normal",
            precioUnitario: "15.00",
            precioTotal: "45.00",
            fecha: "2025-06-16",
            trabajadorRealizador: "Lic. José Pérez",
            registradoPor: "Luis López",
            observaciones: "3 dosis de diclofenaco 75mg aplicadas durante el día, sin reacciones adversas"
        },
        {
            procedimientoId: "3",
            paciente: "Elena Isabel Vargas",
            tipoProcedimiento: "Control de Signos Vitales",
            cantidad: 2,
            tipo: "Emergencia",
            precioUnitario: "18.00",
            precioTotal: "36.00",
            fecha: "2025-06-17",
            trabajadorRealizador: "Lic. Ana González",
            registradoPor: "Luis López",
            observaciones: "Controles cada 4 horas - PA: 120/80, FC: 72, Temp: 36.5°C - Valores estables"
        },
        {
            procedimientoId: "4",
            paciente: "Roberto Silva",
            tipoProcedimiento: "Nebulización",
            cantidad: 2,
            tipo: "Normal",
            precioUnitario: "18.00",
            precioTotal: "36.00",
            fecha: "2025-06-17",
            trabajadorRealizador: "Lic. Miguel Torres",
            registradoPor: "Luis López",
            observaciones: "2 sesiones de nebulización con salbutamol, mejoría en función respiratoria"
        },
        {
            procedimientoId: "5",
            paciente: "Ana Patricia Morales",
            tipoProcedimiento: "Curación Avanzada",
            cantidad: 1,
            tipo: "Emergencia",
            precioUnitario: "70.00",
            precioTotal: "70.00",
            fecha: "2025-06-18",
            trabajadorRealizador: "Dra. María Fernández",
            registradoPor: "Luis López",
            observaciones: "Curación post-quirúrgica de emergencia, cambio de apósitos estériles"
        },
        {
            procedimientoId: "6",
            paciente: "José Antonio Morales",
            tipoProcedimiento: "Inyección Intravenosa",
            cantidad: 1,
            tipo: "Emergencia",
            precioUnitario: "35.00",
            precioTotal: "35.00",
            fecha: "2025-06-19",
            trabajadorRealizador: "Lic. José Pérez",
            registradoPor: "Luis López",
            observaciones: "Administración de antibiótico IV de urgencia"
        },
        {
            procedimientoId: "7",
            paciente: "Carmen Rosa Delgado",
            tipoProcedimiento: "Colocación de Sonda",
            cantidad: 1,
            tipo: "Normal",
            precioUnitario: "35.00",
            precioTotal: "35.00",
            fecha: "2025-06-20",
            trabajadorRealizador: "Lic. Ana González",
            registradoPor: "Luis López",
            observaciones: "Sonda vesical colocada sin complicaciones"
        },
        {
            procedimientoId: "8",
            paciente: "Ricardo Herrera",
            tipoProcedimiento: "Curación Avanzada",
            cantidad: 1,
            tipo: "Emergencia",
            precioUnitario: "70.00",
            precioTotal: "70.00",
            fecha: "2025-06-21",
            trabajadorRealizador: "Dra. María Fernández",
            registradoPor: "Luis López",
            observaciones: "Curación de quemadura de segundo grado"
        },
        {
            procedimientoId: "9",
            paciente: "Patricia Sánchez",
            tipoProcedimiento: "Control de Signos Vitales",
            cantidad: 4,
            tipo: "Normal",
            precioUnitario: "10.00",
            precioTotal: "40.00",
            fecha: "2025-06-22",
            trabajadorRealizador: "Enf. Elena Vargas",
            registradoPor: "Luis López",
            observaciones: "Monitoreo post-operatorio cada 2 horas"
        },
        {
            procedimientoId: "10",
            paciente: "Fernando Gómez",
            tipoProcedimiento: "Nebulización",
            cantidad: 3,
            tipo: "Normal",
            precioUnitario: "18.00",
            precioTotal: "54.00",
            fecha: "2025-06-23",
            trabajadorRealizador: "Lic. Miguel Torres",
            registradoPor: "Luis López",
            observaciones: "Terapia respiratoria intensiva"
        },
        {
            procedimientoId: "11",
            paciente: "Isabella Ramírez",
            tipoProcedimiento: "Inyección Intramuscular",
            cantidad: 2,
            tipo: "Emergencia",
            precioUnitario: "25.00",
            precioTotal: "50.00",
            fecha: "2025-06-24",
            trabajadorRealizador: "Lic. José Pérez",
            registradoPor: "Luis López",
            observaciones: "Analgésicos de emergencia para dolor severo"
        },
        {
            procedimientoId: "12",
            paciente: "Miguel Ángel Torres",
            tipoProcedimiento: "Curación Simple",
            cantidad: 1,
            tipo: "Normal",
            precioUnitario: "25.00",
            precioTotal: "25.00",
            fecha: "2025-06-25",
            trabajadorRealizador: "Lic. Ana González",
            registradoPor: "Luis López",
            observaciones: "Cambio de vendaje rutinario"
        }
    ]

    // ✅ MODELOS SEPARADOS PARA PAGINACIÓN
    ListModel {
        id: procedimientosListModel // Modelo filtrado (todos los resultados del filtro)
    }
    
    ListModel {
        id: procedimientosPaginadosModel // Modelo para la página actual
    }

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
                
                // Header de Procedimientos - FIJO
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
                                text: "🩹"
                                font.pixelSize: 24
                                color: primaryColor
                            }
                            
                            Label {
                                text: "Registro de Procedimientos de Enfermería"
                                font.pixelSize: 20
                                font.bold: true
                                color: textColor
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            objectName: "newProcedureButton"
                            text: "➕ Nuevo Procedimiento"
                            
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
                                showNewProcedureDialog = true
                            }
                        } 
                        
                        // Botón de configuración (engranaje)
                        Button {
                            id: configButton
                            text: "⚙️"
                            font.pixelSize: 18
                            
                            background: Rectangle {
                                color: "#6c757d"
                                radius: 12
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            onClicked: configMenu.open()
                            
                            Menu {
                                id: configMenu
                                y: parent.height
                                
                                MenuItem {
                                    text: "🩺 Configuración de Procedimientos"
                                    onTriggered: showConfigProceduresDialog = true
                                }
                            }
                        }           
                    }
                }
                
                // ✅ FILTROS CON MÁS ESPACIO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80  // ✅ AUMENTADO de 60 a 80
                    color: "transparent"
                    z: 10
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 32
                        anchors.bottomMargin: 16  // ✅ AGREGAR separación
                        spacing: 16
                        
                        Label {
                            text: "Filtrar por:"
                            font.bold: true
                            color: textColor
                        }
                        
                        ComboBox {
                            id: filtroFecha
                            Layout.preferredWidth: 120
                            model: ["Todas", "Hoy", "Semana", "Mes"]
                            currentIndex: 0
                            onCurrentIndexChanged: aplicarFiltros()
                        }
                        
                        Label {
                            text: "Procedimiento:"
                            font.bold: true
                            color: textColor
                        }
                        
                        ComboBox {
                            id: filtroProcedimiento
                            Layout.preferredWidth: 160
                            model: {
                                var list = ["Todos"]
                                for (var i = 0; i < tiposProcedimientos.length; i++) {
                                    list.push(tiposProcedimientos[i].nombre)
                                }
                                return list
                            }
                            currentIndex: 0
                            onCurrentIndexChanged: aplicarFiltros()
                        }
                        
                        Label {
                            text: "Tipo:"
                            font.bold: true
                            color: textColor
                        }
                        
                        ComboBox {
                            id: filtroTipo
                            Layout.preferredWidth: 100
                            model: ["Todos", "Normal", "Emergencia"]
                            currentIndex: 0
                            onCurrentIndexChanged: aplicarFiltros()
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        TextField {
                            id: campoBusqueda
                            Layout.preferredWidth: 180
                            placeholderText: "Buscar paciente..."
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
               
                // ✅ CONTENEDOR DE TABLA CORREGIDO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 565  // ✅ ALTURA FIJA para que quepan 10 filas + header
                    Layout.fillHeight: false
                    Layout.margins: 32
                    Layout.topMargin: 0
                    color: "#FFFFFF"
                    border.color: "#D5DBDB"
                    border.width: 1
                    radius: 8
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 0
                        
                        // Header de la tabla - FIJO
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45
                            color: "#f5f5f5"
                            border.color: "#d0d0d0"
                            border.width: 1
                            z: 5
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "ID"
                                        font.bold: true
                                        font.pixelSize: 10
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 150
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "PACIENTE"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 140
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "PROCEDIMIENTO"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 60
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "CANT."
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "TIPO"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "PRECIO"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "TOTAL"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 90
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "FECHA"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 130
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "TRABAJADOR"
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
                        
                        // Contenido de la tabla con scroll controlado
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 520  // ✅ ALTURA FIJA (565-45=520)
                            Layout.fillHeight: false
                            clip: true
                            
                            ListView {
                                id: procedimientosListView
                                model: procedimientosPaginadosModel  // ✅ USAR MODELO PAGINADO
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: 50  // ✅ REDUCIDO de 65 a 50
                                    color: {
                                        if (selectedRowIndex === index) return "#fce4ec"
                                        return index % 2 === 0 ? "transparent" : "#fafafa"
                                    }
                                    border.color: selectedRowIndex === index ? primaryColor : "#e8e8e8"
                                    border.width: selectedRowIndex === index ? 2 : 1
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 50
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: model.procedimientoId
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: 11  // ✅ REDUCIDO de 12 a 11
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 150
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: 3  // ✅ REDUCIDO de 4 a 3
                                                text: model.paciente
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: 11  // ✅ REDUCIDO de 12 a 11
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 140
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: 3  // ✅ REDUCIDO de 4 a 3
                                                text: model.tipoProcedimiento
                                                color: primaryColor
                                                font.bold: true
                                                font.pixelSize: 10  // ✅ REDUCIDO de 12 a 10
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 60
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 22  // ✅ REDUCIDO de 25 a 22
                                                height: 18  // ✅ REDUCIDO de 20 a 18
                                                color: model.cantidad > 1 ? warningColor : successColor
                                                radius: 9
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.cantidad
                                                    color: whiteColor
                                                    font.pixelSize: 10  // ✅ REDUCIDO de 12 a 10
                                                    font.bold: true
                                                }
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 45  // ✅ REDUCIDO de 50 a 45
                                                height: 16  // ✅ REDUCIDO de 18 a 16
                                                color: model.tipo === "Emergencia" ? emergencyColor : successColor
                                                radius: 8
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.tipo
                                                    color: whiteColor
                                                    font.pixelSize: 8  // ✅ REDUCIDO de 9 a 8
                                                    font.bold: true
                                                }
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: "Bs " + model.precioUnitario
                                                color: model.tipo === "Emergencia" ? emergencyColor : successColor
                                                font.bold: true
                                                font.pixelSize: 11  // ✅ REDUCIDO de 12 a 11
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: "Bs " + model.precioTotal
                                                color: model.tipo === "Emergencia" ? emergencyColor : successColor
                                                font.bold: true
                                                font.pixelSize: 11  // ✅ REDUCIDO de 12 a 11
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 90
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: model.fecha
                                                color: textColor
                                                font.pixelSize: 10  // ✅ REDUCIDO de 12 a 10
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 130
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: 3  // ✅ REDUCIDO de 4 a 3
                                                text: model.trabajadorRealizador
                                                color: "#34495e"
                                                font.bold: true
                                                font.pixelSize: 10  // ✅ REDUCIDO de 12 a 10
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
                                                anchors.margins: 3  // ✅ REDUCIDO de 4 a 3
                                                text: model.registradoPor || "Luis López"
                                                color: "#7f8c8d"
                                                font.pixelSize: 10  // ✅ REDUCIDO de 12 a 10
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
                                            console.log("Seleccionado procedimiento ID:", model.procedimientoId)
                                        }
                                    }
                                    
                                    // ✅ BOTONES DE ACCIÓN CORREGIDOS
                                    RowLayout {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 5  // ✅ REDUCIDO de 6 a 5
                                        spacing: 3
                                        visible: selectedRowIndex === index
                                        z: 10
                                        
                                        Button {
                                            id: editButton
                                            width: 24  // ✅ REDUCIDO de 28 a 24
                                            height: 24  // ✅ REDUCIDO de 28 a 24
                                            text: "✏️"
                                            
                                            background: Rectangle {
                                                color: warningColor
                                                radius: 5
                                                border.color: "#f1c40f"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: 9  // ✅ REDUCIDO de 10 a 9
                                            }
                                            
                                            onClicked: {
                                                // ✅ BUSCAR EL ÍNDICE REAL EN EL MODELO FILTRADO
                                                var procedimientoId = model.procedimientoId
                                                var realIndex = -1
                                                
                                                for (var i = 0; i < procedimientosListModel.count; i++) {
                                                    if (procedimientosListModel.get(i).procedimientoId === procedimientoId) {
                                                        realIndex = i
                                                        break
                                                    }
                                                }
                                                
                                                isEditMode = true
                                                editingIndex = realIndex
                                                
                                                console.log("Editando procedimiento ID:", procedimientoId, "índice real:", realIndex)
                                                showNewProcedureDialog = true
                                            }
                                        }
                                        
                                        Button {
                                            id: deleteButton
                                            width: 24  // ✅ REDUCIDO de 28 a 24
                                            height: 24  // ✅ REDUCIDO de 28 a 24
                                            text: "🗑️"
                                            
                                            background: Rectangle {
                                                color: dangerColor
                                                radius: 5
                                                border.color: "#c0392b"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: 9  // ✅ REDUCIDO de 10 a 9
                                            }
                                            
                                            onClicked: {
                                                // ✅ ELIMINAR DEL MODELO FILTRADO Y ACTUALIZAR
                                                var procedimientoId = model.procedimientoId
                                                
                                                // Eliminar de procedimientosListModel
                                                for (var i = 0; i < procedimientosListModel.count; i++) {
                                                    if (procedimientosListModel.get(i).procedimientoId === procedimientoId) {
                                                        procedimientosListModel.remove(i)
                                                        break
                                                    }
                                                }
                                                
                                                // Eliminar de procedimientosOriginales
                                                for (var j = 0; j < procedimientosOriginales.length; j++) {
                                                    if (procedimientosOriginales[j].procedimientoId === procedimientoId) {
                                                        procedimientosOriginales.splice(j, 1)
                                                        break
                                                    }
                                                }
                                                
                                                selectedRowIndex = -1
                                                updatePaginatedModel() // ✅ ACTUALIZAR PAGINACIÓN
                                                console.log("Procedimiento eliminado ID:", procedimientoId)
                                            }
                                        }
                                    }
                                    
                                    // Tooltip con observaciones al hacer hover
                                    ToolTip {
                                        id: observacionesTooltip
                                        text: "Observaciones: " + model.observaciones
                                        visible: mouseArea.containsMouse
                                        delay: 1000
                                    }
                                    
                                    MouseArea {
                                        id: mouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            selectedRowIndex = index
                                            console.log("Seleccionado procedimiento ID:", model.procedimientoId)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ✅ CONTROL DE PAGINACIÓN CORREGIDO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    Layout.margins: 32
                    Layout.topMargin: 0
                    color: "#F8F9FA"
                    border.color: "#D5DBDB"
                    border.width: 1
                    radius: 8
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 20
                        
                        // Botón Anterior
                        Button {
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 36
                            text: "← Anterior"
                            enabled: currentPageEnfermeria > 0
                            
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
                                if (currentPageEnfermeria > 0) {
                                    currentPageEnfermeria--
                                    updatePaginatedModel()  // ✅ CAMBIAR A FUNCIÓN CORRECTA
                                }
                            }
                        }
                        
                        // Indicador de página
                        Label {
                            text: "Página " + (currentPageEnfermeria + 1) + " de " + Math.max(1, totalPagesEnfermeria)
                            color: "#374151"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        // Botón Siguiente
                        Button {
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 36
                            text: "Siguiente →"
                            enabled: currentPageEnfermeria < totalPagesEnfermeria - 1  // ✅ CORREGIDO
                            
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
                                if (currentPageEnfermeria < totalPagesEnfermeria - 1) {  // ✅ CORREGIDO
                                    currentPageEnfermeria++
                                    updatePaginatedModel()  // ✅ CAMBIAR A FUNCIÓN CORRECTA
                                }
                            }
                        }
                    }
                }  
            }
        }
    }

    // Diálogo Nuevo Procedimiento / Editar Procedimiento
    Rectangle {
        id: newProcedureDialog
        anchors.fill: parent
        color: "black"
        opacity: showNewProcedureDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showNewProcedureDialog = false
                selectedRowIndex = -1
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    Rectangle {
        id: procedureForm
        anchors.centerIn: parent
        width: 550
        height: 750  // Aumentado para incluir campo trabajador
        color: whiteColor
        radius: 20
        border.color: lightGrayColor
        border.width: 2
        visible: showNewProcedureDialog
        
        property int selectedProcedureIndex: -1
        property string procedureType: "Normal"
        property real calculatedUnitPrice: 0.0
        property real calculatedTotalPrice: 0.0
        
        // Función para cargar datos en modo edición
        function loadEditData() {
            if (isEditMode && editingIndex >= 0) {
                var procedimiento = procedimientosListModel.get(editingIndex)
                
                // Extraer nombres del paciente completo
                var nombreCompleto = procedimiento.paciente.split(" ")
                nombrePaciente.text = nombreCompleto[0] || ""
                apellidoPaterno.text = nombreCompleto[1] || ""
                apellidoMaterno.text = nombreCompleto.slice(2).join(" ") || ""
                
                // Buscar el tipo de procedimiento correspondiente
                for (var i = 0; i < tiposProcedimientos.length; i++) {
                    if (tiposProcedimientos[i].nombre === procedimiento.tipoProcedimiento) {
                        procedimientoCombo.currentIndex = i + 1
                        procedureForm.selectedProcedureIndex = i
                        break
                    }
                }
                
                // Buscar trabajador
                for (var j = 0; j < trabajadoresDisponibles.length; j++) {
                    if (trabajadoresDisponibles[j] === procedimiento.trabajadorRealizador) {
                        trabajadorCombo.currentIndex = j + 1
                        break
                    }
                }
                
                // Configurar tipo de procedimiento
                if (procedimiento.tipo === "Normal") {
                    normalRadio.checked = true
                    procedureForm.procedureType = "Normal"
                } else {
                    emergenciaRadio.checked = true
                    procedureForm.procedureType = "Emergencia"
                }
                
                // Cargar cantidad
                cantidadSpinBox.value = parseInt(procedimiento.cantidad)
                
                // Calcular precios
                if (procedureForm.selectedProcedureIndex >= 0) {
                    var proc = tiposProcedimientos[procedureForm.selectedProcedureIndex]
                    procedureForm.calculatedUnitPrice = procedureForm.procedureType === "Normal" ? 
                                                      proc.precioNormal : proc.precioEmergencia
                    procedureForm.calculatedTotalPrice = procedureForm.calculatedUnitPrice * cantidadSpinBox.value
                }
                
                // Cargar observaciones
                observacionesProcedimiento.text = procedimiento.observaciones
            }
        }
        
        function updatePrices() {
            if (procedureForm.selectedProcedureIndex >= 0) {
                var proc = tiposProcedimientos[procedureForm.selectedProcedureIndex]
                procedureForm.calculatedUnitPrice = procedureForm.procedureType === "Normal" ? 
                                                  proc.precioNormal : proc.precioEmergencia
                procedureForm.calculatedTotalPrice = procedureForm.calculatedUnitPrice * cantidadSpinBox.value
            } else {
                procedureForm.calculatedUnitPrice = 0.0
                procedureForm.calculatedTotalPrice = 0.0
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
                // Limpiar formulario para nuevo procedimiento
                nombrePaciente.text = ""
                apellidoPaterno.text = ""
                apellidoMaterno.text = ""
                edadPaciente.text = ""
                procedimientoCombo.currentIndex = 0
                trabajadorCombo.currentIndex = 0
                normalRadio.checked = true
                cantidadSpinBox.value = 1
                observacionesProcedimiento.text = ""
                procedureForm.selectedProcedureIndex = -1
                procedureForm.calculatedUnitPrice = 0.0
                procedureForm.calculatedTotalPrice = 0.0
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20
            
            // Título
            Label {
                Layout.fillWidth: true
                text: isEditMode ? "Editar Procedimiento" : "Nuevo Procedimiento"
                font.pixelSize: 24
                font.bold: true
                color: textColor
                horizontalAlignment: Text.AlignHCenter
            }
            
            // Datos del Paciente
            GroupBox {
                Layout.fillWidth: true
                title: "Datos del Paciente"
                
                background: Rectangle {
                    color: "#f8f9fa"
                    border.color: lightGrayColor
                    border.width: 1
                    radius: 8
                }
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    
                    // Nombre
                    TextField {
                        id: nombrePaciente
                        Layout.fillWidth: true
                        placeholderText: "Nombre del paciente"
                        background: Rectangle {
                            color: whiteColor
                            border.color: lightGrayColor
                            border.width: 1
                            radius: 6
                        }
                    }
                    
                    // Apellidos
                    RowLayout {
                        Layout.fillWidth: true                       
                        TextField {
                            id: apellidoPaterno
                            Layout.fillWidth: true
                            placeholderText: "Apellido paterno"
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 6
                            }
                        }
                        
                        TextField {
                            id: apellidoMaterno
                            Layout.fillWidth: true
                            placeholderText: "Apellido materno"
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 6
                            }
                        }
                    }
                    
                    // Edad
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.preferredWidth: 120
                            text: "Edad:"
                            font.bold: true
                            color: textColor
                        }
                        TextField {
                            id: edadPaciente
                            Layout.preferredWidth: 100
                            placeholderText: "0"
                            validator: IntValidator { bottom: 0; top: 120 }
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 6
                            }
                        }
                        Label {
                            text: "años"
                            color: textColor
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
            
            // Tipo de Procedimiento
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.preferredWidth: 120
                    text: "Procedimiento:"
                    font.bold: true
                    color: textColor
                }
                ComboBox {
                    id: procedimientoCombo
                    Layout.fillWidth: true
                    model: {
                        var list = ["Seleccionar procedimiento..."]
                        for (var i = 0; i < tiposProcedimientos.length; i++) {
                            list.push(tiposProcedimientos[i].nombre)
                        }
                        return list
                    }
                    onCurrentIndexChanged: {
                        if (currentIndex > 0) {
                            procedureForm.selectedProcedureIndex = currentIndex - 1
                        } else {
                            procedureForm.selectedProcedureIndex = -1
                        }
                        procedureForm.updatePrices()
                    }
                }
            }
            
            // Trabajador que realizará el procedimiento
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.preferredWidth: 120
                    text: "Trabajador:"
                    font.bold: true
                    color: textColor
                }
                ComboBox {
                    id: trabajadorCombo
                    Layout.fillWidth: true
                    model: {
                        var list = ["Seleccionar trabajador..."]
                        for (var i = 0; i < trabajadoresDisponibles.length; i++) {
                            list.push(trabajadoresDisponibles[i])
                        }
                        return list
                    }
                }
            }
            
            // Descripción del procedimiento seleccionado
            RowLayout {
                Layout.fillWidth: true
                visible: procedureForm.selectedProcedureIndex >= 0
                Label {
                    Layout.preferredWidth: 120
                    text: "Descripción:"
                    font.bold: true
                    color: textColor
                }
                Label {
                    Layout.fillWidth: true
                    text: procedureForm.selectedProcedureIndex >= 0 ? 
                          tiposProcedimientos[procedureForm.selectedProcedureIndex].descripcion : ""
                    color: "#7f8c8d"
                    font.italic: true
                    wrapMode: Text.WordWrap
                }
            }
            
            // Tipo de Procedimiento (Normal/Emergencia)
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.preferredWidth: 120
                    text: "Tipo:"
                    font.bold: true
                    color: textColor
                }
                
                RadioButton {
                    id: normalRadio
                    text: "Normal"
                    checked: true
                    onCheckedChanged: {
                        if (checked) {
                            procedureForm.procedureType = "Normal"
                            procedureForm.updatePrices()
                        }
                    }
                }
                
                RadioButton {
                    id: emergenciaRadio
                    text: "Emergencia"
                    onCheckedChanged: {
                        if (checked) {
                            procedureForm.procedureType = "Emergencia"
                            procedureForm.updatePrices()
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }
            
            // Cantidad
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.preferredWidth: 120
                    text: "Cantidad:"
                    font.bold: true
                    color: textColor
                }
                SpinBox {
                    id: cantidadSpinBox
                    Layout.preferredWidth: 120
                    from: 1
                    to: 50
                    value: 1
                    onValueChanged: procedureForm.updatePrices()
                }
                Label {
                    text: "procedimiento(s)"
                    color: textColor
                }
                Item { Layout.fillWidth: true }
            }
            
            // Precios calculados
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                color: "#f8f9fa"
                radius: 8
                border.color: lightGrayColor
                border.width: 1
                
                GridLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 20
                    
                    Label {
                        text: "Precio Unitario:"
                        font.bold: true
                        color: textColor
                    }
                    Label {
                        text: procedureForm.selectedProcedureIndex >= 0 ? 
                              "Bs" + procedureForm.calculatedUnitPrice.toFixed(2) : "Seleccione procedimiento"
                        font.bold: true
                        font.pixelSize: 14
                        color: procedureForm.procedureType === "Emergencia" ? emergencyColor : successColor
                    }
                    
                    Label {
                        text: "Total a Pagar:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: 16
                    }
                    Label {
                        text: procedureForm.selectedProcedureIndex >= 0 ? 
                              "Bs" + procedureForm.calculatedTotalPrice.toFixed(2) : "Bs0.00"
                        font.bold: true
                        font.pixelSize: 18
                        color: procedureForm.procedureType === "Emergencia" ? emergencyColor : successColor
                    }
                }
            }
            
            // Observaciones
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                Label {
                    text: "Observaciones:"
                    font.bold: true
                    color: textColor
                }
                
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 60
                    
                    TextArea {
                        id: observacionesProcedimiento
                        placeholderText: "Observaciones del procedimiento, resultados, reacciones del paciente..."
                        wrapMode: TextArea.Wrap
                        background: Rectangle {
                            color: whiteColor
                            border.color: lightGrayColor
                            border.width: 1
                            radius: 8
                        }
                    }
                }
            }
            
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
                        // Limpiar campos
                        nombrePaciente.text = ""
                        apellidoPaterno.text = ""
                        apellidoMaterno.text = ""
                        edadPaciente.text = ""
                        procedimientoCombo.currentIndex = 0
                        trabajadorCombo.currentIndex = 0
                        normalRadio.checked = true
                        cantidadSpinBox.value = 1
                        observacionesProcedimiento.text = ""
                        showNewProcedureDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                    }
                }
                
                Button {
                    text: isEditMode ? "Actualizar" : "Guardar"
                    enabled: procedureForm.selectedProcedureIndex >= 0 && 
                             nombrePaciente.text.length > 0 &&
                             trabajadorCombo.currentIndex > 0
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
                        // Crear datos de procedimiento
                        var nombreCompleto = nombrePaciente.text + " " + 
                                           apellidoPaterno.text + " " + 
                                           apellidoMaterno.text
                        
                        var tipoProcedimiento = tiposProcedimientos[procedureForm.selectedProcedureIndex].nombre
                        var trabajadorSeleccionado = trabajadoresDisponibles[trabajadorCombo.currentIndex - 1]
                        
                        var procedimientoData = {
                            paciente: nombreCompleto.trim(),
                            tipoProcedimiento: tipoProcedimiento,
                            cantidad: cantidadSpinBox.value,
                            tipo: procedureForm.procedureType,
                            precioUnitario: procedureForm.calculatedUnitPrice.toFixed(2),
                            precioTotal: procedureForm.calculatedTotalPrice.toFixed(2),
                            fecha: new Date().toISOString().split('T')[0],
                            trabajadorRealizador: trabajadorSeleccionado,
                            registradoPor: "Luis López",  // Siempre Luis López
                            observaciones: observacionesProcedimiento.text || "Sin observaciones adicionales"
                        }
                        
                        if (isEditMode && editingIndex >= 0) {
                            // ✅ ACTUALIZAR PROCEDIMIENTO EXISTENTE
                            var procedimientoExistente = procedimientosListModel.get(editingIndex)
                            procedimientoData.procedimientoId = procedimientoExistente.procedimientoId
                            
                            // Actualizar en modelo filtrado
                            procedimientosListModel.set(editingIndex, procedimientoData)
                            
                            // Actualizar en datos originales
                            for (var i = 0; i < procedimientosOriginales.length; i++) {
                                if (procedimientosOriginales[i].procedimientoId === procedimientoData.procedimientoId) {
                                    procedimientosOriginales[i] = procedimientoData
                                    break
                                }
                            }
                            
                            console.log("Procedimiento actualizado:", JSON.stringify(procedimientoData))
                        } else {
                            // ✅ CREAR NUEVO PROCEDIMIENTO
                            procedimientoData.procedimientoId = (getTotalEnfermeriaCount() + 1).toString()
                            
                            // Agregar a modelo filtrado
                            procedimientosListModel.append(procedimientoData)
                            
                            // Agregar a datos originales
                            procedimientosOriginales.push(procedimientoData)
                            
                            console.log("Nuevo procedimiento guardado:", JSON.stringify(procedimientoData))
                        }
                        
                        // ✅ ACTUALIZAR PAGINACIÓN
                        updatePaginatedModel()
                        
                        // Limpiar y cerrar
                        nombrePaciente.text = ""
                        apellidoPaterno.text = ""
                        apellidoMaterno.text = ""
                        edadPaciente.text = ""
                        procedimientoCombo.currentIndex = 0
                        trabajadorCombo.currentIndex = 0
                        normalRadio.checked = true
                        cantidadSpinBox.value = 1
                        observacionesProcedimiento.text = ""
                        showNewProcedureDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                    }
                }
            }
        }
    }

    // ✅ FUNCIÓN PARA APLICAR FILTROS - MEJORADA
    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros en enfermería...")
        
        // Limpiar el modelo filtrado
        procedimientosListModel.clear()
        
        var hoy = new Date()
        var textoBusqueda = campoBusqueda.text.toLowerCase()
        
        for (var i = 0; i < procedimientosOriginales.length; i++) {
            var procedimiento = procedimientosOriginales[i]
            var mostrar = true
            
            // Filtro por fecha
            if (filtroFecha.currentIndex > 0) {
                var fechaProcedimiento = new Date(procedimiento.fecha)
                var diferenciaDias = Math.floor((hoy - fechaProcedimiento) / (1000 * 60 * 60 * 24))
                
                switch(filtroFecha.currentIndex) {
                    case 1: // Hoy
                        if (diferenciaDias !== 0) mostrar = false
                        break
                    case 2: // Esta Semana
                        if (diferenciaDias > 7) mostrar = false
                        break
                    case 3: // Este Mes
                        if (diferenciaDias > 30) mostrar = false
                        break
                }
            }
            
            // Filtro por tipo de procedimiento
            if (filtroProcedimiento.currentIndex > 0 && mostrar) {
                var procedimientoSeleccionado = tiposProcedimientos[filtroProcedimiento.currentIndex - 1].nombre
                if (procedimiento.tipoProcedimiento !== procedimientoSeleccionado) {
                    mostrar = false
                }
            }
            
            // Filtro por tipo (Normal/Emergencia)
            if (filtroTipo.currentIndex > 0 && mostrar) {
                var tipoSeleccionado = filtroTipo.model[filtroTipo.currentIndex]
                if (procedimiento.tipo !== tipoSeleccionado) {
                    mostrar = false
                }
            }
            
            // Búsqueda por texto en paciente
            if (textoBusqueda.length > 0 && mostrar) {
                if (!procedimiento.paciente.toLowerCase().includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                procedimientosListModel.append(procedimiento)
            }
        }
        
        // ✅ RESETEAR A PRIMERA PÁGINA Y ACTUALIZAR PAGINACIÓN
        currentPageEnfermeria = 0
        updatePaginatedModel()
        
        console.log("✅ Filtros aplicados. Procedimientos mostrados:", procedimientosListModel.count)
    }

    // ✅ NUEVA FUNCIÓN PARA ACTUALIZAR PAGINACIÓN
    function updatePaginatedModel() {
        console.log("📄 Enfermería: Actualizando paginación - Página:", currentPageEnfermeria + 1)
        
        // Limpiar modelo paginado
        procedimientosPaginadosModel.clear()
        
        // Calcular total de páginas basado en procedimientos filtrados
        var totalItems = procedimientosListModel.count
        totalPagesEnfermeria = Math.ceil(totalItems / itemsPerPageEnfermeria)
        
        // Asegurar que siempre hay al menos 1 página
        if (totalPagesEnfermeria === 0) {
            totalPagesEnfermeria = 1
        }
        
        // Ajustar página actual si es necesario
        if (currentPageEnfermeria >= totalPagesEnfermeria && totalPagesEnfermeria > 0) {
            currentPageEnfermeria = totalPagesEnfermeria - 1
        }
        if (currentPageEnfermeria < 0) {
            currentPageEnfermeria = 0
        }
        
        // Calcular índices
        var startIndex = currentPageEnfermeria * itemsPerPageEnfermeria
        var endIndex = Math.min(startIndex + itemsPerPageEnfermeria, totalItems)
        
        // Agregar elementos de la página actual
        for (var i = startIndex; i < endIndex; i++) {
            var procedimiento = procedimientosListModel.get(i)
            procedimientosPaginadosModel.append(procedimiento)
        }
        
        console.log("📄 Enfermería: Página", currentPageEnfermeria + 1, "de", totalPagesEnfermeria,
                    "- Mostrando", procedimientosPaginadosModel.count, "de", totalItems)
    }

    // Diálogo Configuración de Tipos de Procedimientos
    Rectangle {
        id: configProceduresBackground
        anchors.fill: parent
        color: "black"
        opacity: showConfigProceduresDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: showConfigProceduresDialog = false
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    Rectangle {
        id: configProceduresDialog
        anchors.centerIn: parent
        width: 750
        height: 650
        color: whiteColor
        radius: 20
        border.color: lightGrayColor
        border.width: 2
        visible: showConfigProceduresDialog
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // Header fijo para título y formulario
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 380
                color: whiteColor
                radius: 20
                z: 10
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 30
                    spacing: 20
                    
                    Label {
                        Layout.fillWidth: true
                        text: "🩺 Configuración de Tipos de Procedimientos"
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    // Formulario para agregar nuevo tipo de procedimiento
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Agregar Nuevo Tipo de Procedimiento"
                        
                        background: Rectangle {
                            color: "#f8f9fa"
                            border.color: lightGrayColor
                            border.width: 1
                            radius: 8
                        }
                        
                        GridLayout {
                            anchors.fill: parent
                            columns: 2
                            rowSpacing: 12
                            columnSpacing: 10
                            
                            Label {
                                text: "Nombre:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevoProcedimientoNombre
                                Layout.fillWidth: true
                                placeholderText: "Ej: Sutura Simple"
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Label {
                                text: "Descripción:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevoProcedimientoDescripcion
                                Layout.fillWidth: true
                                placeholderText: "Ej: Sutura de heridas superficiales"
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Label {
                                text: "Precio Normal:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevoProcedimientoPrecioNormal
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
                            
                            Label {
                                text: "Precio Emergencia:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevoProcedimientoPrecioEmergencia
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
                            
                            Item { }
                            Button {
                                Layout.alignment: Qt.AlignRight
                                text: "➕ Agregar Procedimiento"
                                background: Rectangle {
                                    color: successColor
                                    radius: 8
                                }
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                onClicked: {
                                    if (nuevoProcedimientoNombre.text && nuevoProcedimientoDescripcion.text && 
                                        nuevoProcedimientoPrecioNormal.text && nuevoProcedimientoPrecioEmergencia.text) {
                                        
                                        var nuevoProcedimiento = {
                                            nombre: nuevoProcedimientoNombre.text,
                                            descripcion: nuevoProcedimientoDescripcion.text,
                                            precioNormal: parseFloat(nuevoProcedimientoPrecioNormal.text),
                                            precioEmergencia: parseFloat(nuevoProcedimientoPrecioEmergencia.text)
                                        }
                                        
                                        tiposProcedimientos.push(nuevoProcedimiento)
                                        enfermeriaRoot.tiposProcedimientos = tiposProcedimientos
                                        
                                        // Limpiar campos
                                        nuevoProcedimientoNombre.text = ""
                                        nuevoProcedimientoDescripcion.text = ""
                                        nuevoProcedimientoPrecioNormal.text = ""
                                        nuevoProcedimientoPrecioEmergencia.text = ""
                                        
                                        console.log("Nuevo tipo de procedimiento agregado:", JSON.stringify(nuevoProcedimiento))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Lista de tipos de procedimientos existentes con scroll limitado
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 30
                Layout.topMargin: 0
                color: "transparent"
                
                ScrollView {
                    anchors.fill: parent
                    clip: true
                    
                    ListView {
                        model: tiposProcedimientos
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 90
                            color: index % 2 === 0 ? "transparent" : "#fafafa"
                            border.color: "#e8e8e8"
                            border.width: 1
                            radius: 8
                            
                            GridLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                columns: 4
                                rowSpacing: 6
                                columnSpacing: 12
                                
                                // Nombre y Descripción
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    
                                    Label {
                                        text: modelData.nombre
                                        font.bold: true
                                        color: primaryColor
                                        font.pixelSize: 14
                                    }
                                    Label {
                                        text: modelData.descripcion
                                        color: textColor
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                    }
                                }
                                
                                // Precio Normal
                                ColumnLayout {
                                    Layout.preferredWidth: 100
                                    spacing: 4
                                    
                                    Label {
                                        text: "Normal"
                                        font.bold: true
                                        color: successColor
                                        font.pixelSize: 12
                                    }
                                    Label {
                                        text: "Bs" + modelData.precioNormal.toFixed(2)
                                        color: successColor
                                        font.bold: true
                                        font.pixelSize: 14
                                    }
                                }
                                
                                // Precio Emergencia
                                ColumnLayout {
                                    Layout.preferredWidth: 100
                                    spacing: 4
                                    
                                    Label {
                                        text: "Emergencia"
                                        font.bold: true
                                        color: emergencyColor
                                        font.pixelSize: 12
                                    }
                                    Label {
                                        text: "Bs" + modelData.precioEmergencia.toFixed(2)
                                        color: emergencyColor
                                        font.bold: true
                                        font.pixelSize: 14
                                    }
                                }
                                
                                // Botón eliminar
                                Button {
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    text: "🗑️"
                                    background: Rectangle {
                                        color: dangerColor
                                        radius: 6
                                    }
                                    contentItem: Label {
                                        text: parent.text
                                        color: whiteColor
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: {
                                        tiposProcedimientos.splice(index, 1)
                                        enfermeriaRoot.tiposProcedimientos = tiposProcedimientos
                                        console.log("Tipo de procedimiento eliminado en índice:", index)
                                    }
                                }
                            }
                        }
                    }
                }
            }      
        }
    }
    
    // ✅ FUNCIÓN PARA OBTENER TOTAL DE PROCEDIMIENTOS CORREGIDA
    function getTotalEnfermeriaCount() {
        return procedimientosOriginales.length
    }
    
    // ✅ INICIALIZACIÓN AL CARGAR EL COMPONENTE
    Component.onCompleted: {
        console.log("🩹 Módulo Enfermería iniciado")
        
        // Cargar datos originales
        for (var i = 0; i < procedimientosModelData.length; i++) {
            procedimientosOriginales.push(procedimientosModelData[i])
            procedimientosListModel.append(procedimientosModelData[i])
        }
        
        // Inicializar paginación
        updatePaginatedModel()
        
        console.log("✅ Procedimientos cargados:", procedimientosOriginales.length)
    }
}