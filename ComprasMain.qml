import QtQuick 2.15
import QtQuick.Controls 2.15

// Contenedor principal que maneja la navegación entre Compras y CrearCompra usando StackView
Item {
    id: comprasMainRoot
    
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
        
        // Componente inicial - Lista de Compras
        initialItem: Component {
            Item {
                // Instancia del componente Compras simplificado
                Loader {
                    id: comprasLoader
                    anchors.fill: parent
                    
                    sourceComponent: Component {
                        Item {
                            id: comprasWrapper
                            
                            // Propiedades para el componente de compras
                            property var inventarioModel: comprasMainRoot.inventarioModel
                            property var ventaModel: comprasMainRoot.ventaModel
                            property var compraModel: comprasMainRoot.compraModel
                            
                            // Vista de compras simplificada
                            Compras {
                                anchors.fill: parent
                                compraModel: comprasWrapper.compraModel
                                
                                // Conexión de señales
                                onNavegarACrearCompra: {
                                    console.log("📱 Señal recibida: Navegar a CrearCompra")
                                    comprasMainRoot.irACrearCompra()
                                }
                            }
                        }
                    }
                    
                    onLoaded: {
                        console.log("✅ Compras.qml cargado correctamente")
                    }
                    
                    onStatusChanged: {
                        if (status === Loader.Error) {
                            console.log("❌ Error al cargar Compras.qml")
                        }
                    }
                }
            }
        }
    }
    
    // FUNCIONES DE NAVEGACIÓN
    
    // Función para navegar a CrearCompra
    function irACrearCompra() {
        console.log("🚀 ComprasMain: Navegando a CrearCompra")
        
        var crearCompraComponent = Qt.createComponent("CrearCompra.qml")
        
        if (crearCompraComponent.status === Component.Ready) {
            var crearCompraItem = crearCompraComponent.createObject(stackView, {
                "inventarioModel": inventarioModel,
                "ventaModel": ventaModel,
                "compraModel": compraModel
            });
            
            if (crearCompraItem) {
                // Conectar señales del componente CrearCompra
                crearCompraItem.compraCompletada.connect(function() {
                    console.log("✅ Compra completada, regresando a lista")
                    regresarACompras()
                })
                
                crearCompraItem.cancelarCompra.connect(function() {
                    console.log("❌ Compra cancelada, regresando a lista")
                    regresarACompras()
                })
                
                stackView.push(crearCompraItem)
                console.log("✅ CrearCompra agregado al stack")
            } else {
                console.log("❌ Error al crear instancia de CrearCompra")
            }
        } else if (crearCompraComponent.status === Component.Error) {
            console.log("❌ Error al cargar CrearCompra.qml:", crearCompraComponent.errorString())
            
            // Fallback: usar componente inline
            var fallbackComponent = Qt.createComponent("CrearCompra.qml");
            if (fallbackComponent.status === Component.Ready) {
                var crearCompraItem = fallbackComponent.createObject(stackView, {
                    "inventarioModel": inventarioModel,
                    "ventaModel": ventaModel,
                    "compraModel": compraModel
                });
                if (crearCompraItem) {
                    crearCompraItem.compraCompletada.connect(function() {
                        console.log("✅ Compra completada (fallback)");
                        comprasMainRoot.regresarACompras();
                    });
                    crearCompraItem.cancelarCompra.connect(function() {
                        console.log("❌ Compra cancelada (fallback)");
                        comprasMainRoot.regresarACompras();
                    });
                    stackView.push(crearCompraItem);
                    console.log("✅ CrearCompra cargado con fallback");
                } else {
                    console.log("❌ Error al crear instancia de fallback CrearCompra");
                }
            } else {
                console.log("❌ Error al cargar fallback CrearCompra.qml:", fallbackComponent.errorString());
            }
        }
    }
    
    // Función para regresar a la lista de compras
    function regresarACompras() {
        console.log("🔙 ComprasMain: Regresando a lista de compras")
        
        if (stackView.depth > 1) {
            stackView.pop()
            console.log("✅ Stack popped, regresado a Compras")
            
            // Actualizar datos en la vista de compras
            Qt.callLater(function() {
                if (compraModel) {
                    console.log("🔄 Actualizando datos de compras...")
                    compraModel.refresh_compras()
                    compraModel.refresh_proveedores()
                }
            })
        }
    }
    
    // MANEJO DE TECLAS PARA NAVEGACIÓN
    focus: true
    Keys.onEscapePressed: {
        if (stackView.depth > 1) {
            console.log("🔙 Escape presionado, regresando")
            regresarACompras()
        }
    }
    
    // CONEXIONES CON DATOS CENTRALES
    Connections {
        target: compraModel
        function onComprasRecientesChanged() {
            console.log("🔄 ComprasMain: Compras actualizadas")
        }
    }
    
    // FUNCIONES DE DEPURACIÓN
    function obtenerEstadoNavegacion() {
        return {
            profundidad: stackView.depth,
            vistaActual: stackView.depth === 1 ? "Compras" : "CrearCompra",
            modelsDisponibles: !!(inventarioModel && ventaModel && compraModel)
        }
    }
    
    function imprimirEstado() {
        var estado = obtenerEstadoNavegacion()
        console.log("📊 Estado de ComprasMain:")
        console.log("   - Profundidad del stack:", estado.profundidad)
        console.log("   - Vista actual:", estado.vistaActual)
        console.log("   - Models disponibles:", estado.modelsDisponibles)
    }
    
    // INICIALIZACIÓN
    Component.onCompleted: {
        console.log("=== COMPRAS MAIN CONTAINER INICIALIZADO ===")
        console.log("🗂️ StackView configurado")
        console.log("📱 Navegación lista")
        
        if (!inventarioModel || !ventaModel || !compraModel) {
            console.log("⚠️ ADVERTENCIA: Models no están disponibles")
        } else {
            console.log("✅ Models conectados correctamente")
            console.log("📊 CompraModel proveedores:", compraModel.total_proveedores)
            console.log("📊 CompraModel compras mes:", compraModel.total_compras_mes)
        }
        
        imprimirEstado()
        console.log("=== CONTAINER LISTO ===")
    }
    
    // LIMPIEZA AL DESTRUIR
    Component.onDestruction: {
        console.log("🧹 ComprasMain: Limpiando recursos...")
    }
}