import QtQuick 2.15
import QtQuick.Controls 2.15

// Contenedor principal que maneja la navegación entre Ventas y CrearVenta usando StackView
Item {
    id: ventasMainRoot
    
    // Propiedades heredadas del componente padre
    property var inventarioModel: parent.inventarioModel
    property var ventaModel: parent.ventaModel
    property var compraModel: parent.compraModel
    
    // SISTEMA DE MÉTRICAS COHERENTE
    readonly property real scaleFactor: Math.min(width / 1400, height / 900)
    readonly property real baseUnit: Math.max(8, height / 100)
    readonly property real fontBaseSize: Math.max(12, height / 70)

    // StackView para manejar la navegación
    StackView {
        id: stackView
        anchors.fill: parent
        
        // Propiedades de animación
        pushEnter: Transition {
            PropertyAnimation {
                property: "x"
                from: stackView.width
                to: 0
                duration: 300
                easing.type: Easing.OutCubic
            }
            PropertyAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 300
            }
        }
        
        pushExit: Transition {
            PropertyAnimation {
                property: "x"
                from: 0
                to: -stackView.width
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        
        popEnter: Transition {
            PropertyAnimation {
                property: "x"
                from: -stackView.width
                to: 0
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        
        popExit: Transition {
            PropertyAnimation {
                property: "x"
                from: 0
                to: stackView.width
                duration: 300
                easing.type: Easing.OutCubic
            }
            PropertyAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 300
            }
        }
        
        // Componente inicial - Lista de Ventas
        initialItem: Component {
            Item {
                id: ventasContainer
                focus: true

                Keys.onEscapePressed: {
                    console.log("Escape en contenedor de Ventas")
                    ventasMainRoot.forceFocus()
                }
                // Instancia del componente Ventas simplificado
                Loader {
                    id: ventasLoader
                    anchors.fill: parent
                    
                    sourceComponent: Component {
                        Item {
                            id: ventasWrapper
                            
                            // Propiedades para el componente de ventas
                            property var inventarioModel: ventasMainRoot.inventarioModel
                            property var ventaModel: ventasMainRoot.ventaModel
                            property var compraModel: ventasMainRoot.compraModel
                            
                            // Vista de ventas simplificada (inline por simplicidad)
                            Ventas {
                                anchors.fill: parent
                                inventarioModel: ventasWrapper.inventarioModel
                                ventaModel: ventasWrapper.ventaModel
                                compraModel: ventasWrapper.compraModel
                                
                                // Conexión de señales
                                onNavegarACrearVenta: {
                                    console.log("📱 Señal recibida: Navegar a CrearVenta")
                                    ventasMainRoot.irACrearVenta()
                                }
                                
                                // ✅ NUEVA CONEXIÓN PARA EDITAR VENTA
                                onNavegarAEditarVenta: function(ventaId) {
                                    console.log("📝 Señal recibida: Navegar a editar venta", ventaId)
                                    ventasMainRoot.irAEditarVenta(ventaId)
                                }
                            }
                        }
                    }
                    
                    onLoaded: {
                        console.log("✅ Ventas.qml cargado correctamente")
                    }
                    
                    onStatusChanged: {
                        if (status === Loader.Error) {
                            console.log("❌ Error al cargar Ventas.qml")
                        }
                    }
                }
            }
        }
    }
    
    // FUNCIONES DE NAVEGACIÓN
    
    // Función para navegar a CrearVenta
    function irACrearVenta() {
        
        var crearVentaComponent = Qt.createComponent("CrearVenta.qml")
        
        if (crearVentaComponent.status === Component.Ready) {
            var crearVentaItem = crearVentaComponent.createObject(stackView, {
               "inventarioModel": inventarioModel,
                "ventaModel": ventaModel,
                "compraModel": compraModel
            })
            
            if (crearVentaItem) {
                // Conectar señales del componente CrearVenta
                crearVentaItem.ventaCompletada.connect(function() {
                    console.log("✅ Venta completada, regresando a lista")
                    regresarAVentas()
                })
                
                crearVentaItem.cancelarVenta.connect(function() {
                    console.log("❌ Venta cancelada, regresando a lista")
                    regresarAVentas()
                })
                
                stackView.push(crearVentaItem)
                console.log("✅ CrearVenta agregado al stack")
            } else {
                console.log("❌ Error al crear instancia de CrearVenta")
            }
        } else if (crearVentaComponent.status === Component.Error) {
            console.log("❌ Error al cargar CrearVenta.qml:", crearVentaComponent.errorString())
            
            // Fallback: usar componente inline
            var fallbackComponent = Qt.createComponent("CrearVenta.qml");
            if (fallbackComponent.status === Component.Ready) {
                var crearVentaItem = fallbackComponent.createObject(stackView, {
                    "inventarioModel": ventasMainRoot.inventarioModel,
                    "ventaModel": ventasMainRoot.ventaModel,
                    "compraModel": ventasMainRoot.compraModel
                });
                if (crearVentaItem) {
                    crearVentaItem.ventaCompletada.connect(function() {
                        console.log("✅ Venta completada (fallback)");
                        ventasMainRoot.regresarAVentas();
                    });
                    crearVentaItem.cancelarVenta.connect(function() {
                        console.log("❌ Venta cancelada (fallback)");
                        ventasMainRoot.regresarAVentas();
                    });
                    stackView.push(crearVentaItem);
                    console.log("✅ CrearVenta cargado con fallback");
                } else {
                    console.log("❌ Error al crear instancia de fallback CrearVenta");
                }
            } else {
                console.log("❌ Error al cargar fallback CrearVenta.qml:", fallbackComponent.errorString());
            }
        }
    }
    
    // ✅ NUEVA FUNCIÓN PARA NAVEGAR A EDITAR VENTA
    function irAEditarVenta(ventaId) {
        
        var crearVentaComponent = Qt.createComponent("CrearVenta.qml")
        
        if (crearVentaComponent.status === Component.Ready) {
            var crearVentaItem = crearVentaComponent.createObject(stackView, {
               "inventarioModel": inventarioModel,
                "ventaModel": ventaModel,
                "compraModel": compraModel,
                "modoEdicion": true,
                "ventaIdAEditar": ventaId
            })
            
            if (crearVentaItem) {
                // Conectar señales del componente CrearVenta
                crearVentaItem.ventaCompletada.connect(function() {
                    console.log("✅ Venta editada, regresando a lista")
                    regresarAVentas()
                })
                
                crearVentaItem.cancelarVenta.connect(function() {
                    console.log("❌ Edición cancelada, regresando a lista")
                    regresarAVentas()
                })
                
                stackView.push(crearVentaItem)
                console.log("✅ CrearVenta (modo edición) agregado al stack")
            } else {
                console.log("❌ Error al crear instancia de CrearVenta para edición")
            }
        } else if (crearVentaComponent.status === Component.Error) {
            console.log("❌ Error al cargar CrearVenta.qml para edición:", crearVentaComponent.errorString())
            
            // Fallback: usar componente inline para edición
            var fallbackComponent = Qt.createComponent("CrearVenta.qml");
            if (fallbackComponent.status === Component.Ready) {
                var crearVentaItem = fallbackComponent.createObject(stackView, {
                    "inventarioModel": ventasMainRoot.inventarioModel,
                    "ventaModel": ventasMainRoot.ventaModel,
                    "compraModel": ventasMainRoot.compraModel,
                    "modoEdicion": true,
                    "ventaIdAEditar": ventaId
                });
                if (crearVentaItem) {
                    crearVentaItem.ventaCompletada.connect(function() {
                        console.log("✅ Venta editada (fallback)");
                        ventasMainRoot.regresarAVentas();
                    });
                    crearVentaItem.cancelarVenta.connect(function() {
                        console.log("❌ Edición cancelada (fallback)");
                        ventasMainRoot.regresarAVentas();
                    });
                    stackView.push(crearVentaItem);
                    console.log("✅ CrearVenta edición cargado con fallback");
                } else {
                    console.log("❌ Error al crear instancia de fallback CrearVenta para edición");
                }
            } else {
                console.log("❌ Error al cargar fallback CrearVenta.qml para edición:", fallbackComponent.errorString());
            }
        }
    }
    
    // Función para regresar a la lista de ventas
    function regresarAVentas() {
        
        if (stackView.depth > 1) {
            stackView.pop()
            console.log("✅ Stack popped, regresado a Ventas")
            
            // Forzar el foco después de regresar
            Qt.callLater(function() {
                forceFocus()
                if (ventaModel) {
                    console.log("🔄 Actualizando datos de ventas...")
                    ventaModel.refresh_ventas_hoy()
                    ventaModel.refresh_estadisticas()
                }
            })
        }
    }
    
    function forceFocus() {
        focus = true
        forceActiveFocus()
        console.log("🔍 Foco forzado en VentasMain")
    }
    
    // MANEJO DE TECLAS PARA NAVEGACIÓN
    focus: true
    Keys.onEscapePressed: {
        if (stackView.depth > 1) {
            console.log("🔙 Escape presionado, regresando")
            regresarAVentas()
        }
    }
    
    
    // FUNCIONES DE DEPURACIÓN
    function obtenerEstadoNavegacion() {
        return {
            profundidad: stackView.depth,
            vistaActual: stackView.depth === 1 ? "Ventas" : "CrearVenta",
            modelsDisponibles: !!(inventarioModel && ventaModel && compraModel)
        }
    }
    
    function imprimirEstado() {
        var estado = obtenerEstadoNavegacion()
        console.log("📊 Estado de VentasMain:")
        console.log("   - Profundidad del stack:", estado.profundidad)
        console.log("   - Vista actual:", estado.vistaActual)
        console.log("   - farmaciaData disponible:", estado.farmaciaDataDisponible)
    }
    
    // INICIALIZACIÓN
    Component.onCompleted: {
        console.log("=== VENTAS MAIN CONTAINER INICIALIZADO ===")
        console.log("🏗️ StackView configurado")
        console.log("📱 Navegación lista")
        
        if (!inventarioModel || !ventaModel || !compraModel) {
            console.log("⚠️ ADVERTENCIA: Models no están disponibles")
        } else {
            console.log("✅ Models conectados correctamente")
        }
        Qt.callLater(function() {
            forceFocus()
        })
        
        imprimirEstado()
        console.log("=== CONTAINER LISTO ===")
    }
}