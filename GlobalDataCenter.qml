pragma Singleton
import QtQuick 2.15

QtObject {
    id: globalDataCenter
    objectName: "globalDataCenter"
    
    // ========== PROPIEDADES DEL USUARIO ACTUAL ==========
    property string usuarioActualId: ""
    property string usuarioActualNombre: ""
    property string usuarioActualRol: ""
    property string usuarioActualCorreo: ""
    property bool usuarioLogueado: false
    property var usuarioPermisos: ({})
    
    // ========== PROPIEDADES DE NOTIFICACIONES ==========
    property int totalNotificaciones: 0
    property var notificacionesActivas: []
    
    // ========== PROPIEDADES DE BÚSQUEDA ==========
    property string ultimaBusqueda: ""
    property var resultadosBusqueda: []
    
    // ========== SEÑALES ==========
    signal usuarioLogueadoCambiado()
    signal notificacionesActualizadas()
    signal busquedaRealizada(string termino, var resultados)
    signal nuevaNotificacion(string tipo, string titulo, string mensaje)
    
    // ========== DATOS DE EJEMPLO ==========
    property var pacientesData: [
        {
            id: 1,
            nombre: "Juan Carlos Pérez",
            documento: "12345678",
            telefono: "78901234",
            tipo: "paciente"
        },
        {
            id: 2,
            nombre: "María Elena Rodríguez",
            documento: "87654321",
            telefono: "76543210",
            tipo: "paciente"
        },
        {
            id: 3,
            nombre: "Roberto García Luna",
            documento: "11223344",
            telefono: "72345678",
            tipo: "paciente"
        }
    ]
    
    property var citasData: [
        {
            id: 1,
            paciente: "Juan Carlos Pérez",
            fecha: "2025-07-09",
            hora: "09:00",
            medico: "Dr. López",
            tipo: "cita"
        },
        {
            id: 2,
            paciente: "María Elena Rodríguez",
            fecha: "2025-07-09",
            hora: "10:30",
            medico: "Dr. Mendoza",
            tipo: "cita"
        }
    ]
    
    property var usuariosData: [
        {
            id: "admin",
            nombreCompleto: "Dr. Admin",
            nombreUsuario: "admin",
            correo: "admin@clinica.com",
            rol: "Administrador",
            contrasena: "admin123",
            permisos: {
                "Vista general": true,
                "Farmacia": true,
                "Consultas": true,
                "Laboratorio": true,
                "Enfermería": true,
                "Servicios Básicos": true,
                "Usuarios": true,
                "Trabajadores": true,
                "Configuración": true
            }
        },
        {
            id: "medico1",
            nombreCompleto: "Dr. Juan Mendoza",
            nombreUsuario: "juan.mendoza",
            correo: "juan.mendoza@clinica.com",
            rol: "Médico",
            contrasena: "medico123",
            permisos: {
                "Vista general": true,
                "Consultas": true,
                "Laboratorio": true,
                "Enfermería": true
            }
        }
    ]
    
    // ========== FUNCIONES DE AUTENTICACIÓN ==========
    function autenticarUsuario(nombreUsuario, contrasena) {
        console.log("🔐 Intentando autenticar:", nombreUsuario)
        
        for (var i = 0; i < usuariosData.length; i++) {
            var usuario = usuariosData[i]
            
            if (usuario.nombreUsuario === nombreUsuario && usuario.contrasena === contrasena) {
                // Login exitoso
                usuarioActualId = usuario.id
                usuarioActualNombre = usuario.nombreCompleto
                usuarioActualRol = usuario.rol
                usuarioActualCorreo = usuario.correo
                usuarioPermisos = usuario.permisos
                usuarioLogueado = true
                
                console.log("✅ Login exitoso para:", usuario.nombreCompleto)
                usuarioLogueadoCambiado()
                
                // Cargar notificaciones iniciales
                cargarNotificacionesIniciales()
                
                return {
                    exito: true,
                    usuario: usuario
                }
            }
        }
        
        console.log("❌ Credenciales incorrectas")
        return {
            exito: false,
            mensaje: "Credenciales incorrectas"
        }
    }
    
    function cerrarSesion() {
        console.log("🚪 Cerrando sesión de:", usuarioActualNombre)
        
        usuarioActualId = ""
        usuarioActualNombre = ""
        usuarioActualRol = ""
        usuarioActualCorreo = ""
        usuarioPermisos = {}
        usuarioLogueado = false
        notificacionesActivas = []
        totalNotificaciones = 0
        
        usuarioLogueadoCambiado()
        notificacionesActualizadas()
    }
    
    // ========== FUNCIONES DE BÚSQUEDA ==========
    function realizarBusquedaGlobal(termino) {
        if (termino.length < 2) {
            resultadosBusqueda = []
            busquedaRealizada(termino, [])
            return
        }
        
        console.log("🔍 Buscando:", termino)
        ultimaBusqueda = termino
        var resultados = []
        var terminoLower = termino.toLowerCase()
        
        // Buscar en pacientes
        for (var i = 0; i < pacientesData.length; i++) {
            var paciente = pacientesData[i]
            if (paciente.nombre.toLowerCase().includes(terminoLower) ||
                paciente.documento.includes(termino) ||
                paciente.telefono.includes(termino)) {
                
                resultados.push({
                    tipo: "Paciente",
                    titulo: paciente.nombre,
                    subtitulo: "Doc: " + paciente.documento + " | Tel: " + paciente.telefono,
                    icono: "👤",
                    accion: "verPaciente",
                    id: paciente.id
                })
            }
        }
        
        // Buscar en citas
        for (var j = 0; j < citasData.length; j++) {
            var cita = citasData[j]
            if (cita.paciente.toLowerCase().includes(terminoLower) ||
                cita.medico.toLowerCase().includes(terminoLower)) {
                
                resultados.push({
                    tipo: "Cita",
                    titulo: cita.paciente,
                    subtitulo: cita.fecha + " " + cita.hora + " - " + cita.medico,
                    icono: "📅",
                    accion: "verCita",
                    id: cita.id
                })
            }
        }
        
        // Buscar productos (esto se conectará con FarmaciaData)
        if (typeof farmaciaData !== 'undefined' && farmaciaData) {
            var productos = farmaciaData.obtenerProductosParaInventario()
            for (var k = 0; k < productos.length; k++) {
                var producto = productos[k]
                if (producto.nombre.toLowerCase().includes(terminoLower) ||
                    producto.codigo.toLowerCase().includes(terminoLower)) {
                    
                    resultados.push({
                        tipo: "Producto",
                        titulo: producto.nombre,
                        subtitulo: "Código: " + producto.codigo + " | Stock: " + producto.stockUnitario,
                        icono: "💊",
                        accion: "verProducto",
                        id: producto.id
                    })
                }
            }
        }
        
        resultadosBusqueda = resultados
        console.log("✅ Búsqueda completada:", resultados.length, "resultados")
        busquedaRealizada(termino, resultados)
    }
    
    // ========== FUNCIONES DE NOTIFICACIONES ==========
    function cargarNotificacionesIniciales() {
        console.log("🔔 Cargando notificaciones iniciales...")
        
        var notificaciones = []
        
        // Verificar productos próximos a vencer (esto se conectará con FarmaciaData)
        if (typeof farmaciaData !== 'undefined' && farmaciaData) {
            var productos = farmaciaData.obtenerProductosParaInventario()
            var hoy = new Date()
            
            for (var i = 0; i < productos.length; i++) {
                var producto = productos[i]
                
                // Simular verificación de vencimiento (en implementación real, consultarías lotes)
                var diasVencimiento = Math.floor(Math.random() * 60) // Simulación
                
                if (diasVencimiento <= 0 && producto.stockUnitario > 0) {
                    notificaciones.push({
                        id: "vencido_" + producto.id,
                        tipo: "vencido",
                        titulo: "Producto Vencido",
                        mensaje: producto.nombre + " ha vencido",
                        fecha: new Date(),
                        prioridad: "alta",
                        icono: "🚨",
                        modulo: "Farmacia"
                    })
                } else if (diasVencimiento > 0 && diasVencimiento <= 30 && producto.stockUnitario > 0) {
                    notificaciones.push({
                        id: "proximo_vencer_" + producto.id,
                        tipo: "proximo_vencer",
                        titulo: "Próximo a Vencer",
                        mensaje: producto.nombre + " vence en " + diasVencimiento + " días",
                        fecha: new Date(),
                        prioridad: "media",
                        icono: "⚠️",
                        modulo: "Farmacia"
                    })
                }
                
                if (producto.stockUnitario <= 10 && producto.stockUnitario > 0) {
                    notificaciones.push({
                        id: "bajo_stock_" + producto.id,
                        tipo: "bajo_stock",
                        titulo: "Stock Bajo",
                        mensaje: producto.nombre + " tiene solo " + producto.stockUnitario + " unidades",
                        fecha: new Date(),
                        prioridad: "media",
                        icono: "📦",
                        modulo: "Farmacia"
                    })
                }
            }
        }
        
        // Notificaciones de citas del día
        var hoyStr = Qt.formatDate(new Date(), "yyyy-MM-dd")
        for (var j = 0; j < citasData.length; j++) {
            var cita = citasData[j]
            if (cita.fecha === hoyStr) {
                notificaciones.push({
                    id: "cita_hoy_" + cita.id,
                    tipo: "cita_hoy",
                    titulo: "Cita de Hoy",
                    mensaje: cita.paciente + " a las " + cita.hora,
                    fecha: new Date(),
                    prioridad: "baja",
                    icono: "📅",
                    modulo: "Consultas"
                })
            }
        }
        
        // Notificación de bienvenida
        notificaciones.push({
            id: "bienvenida",
            tipo: "bienvenida",
            titulo: "Bienvenido",
            mensaje: "Bienvenido al sistema, " + usuarioActualNombre,
            fecha: new Date(),
            prioridad: "baja",
            icono: "👋",
            modulo: "Sistema"
        })
        
        notificacionesActivas = notificaciones
        totalNotificaciones = notificaciones.length
        
        console.log("✅ Notificaciones cargadas:", totalNotificaciones)
        notificacionesActualizadas()
    }
    
    function agregarNotificacion(tipo, titulo, mensaje, prioridad, modulo) {
        var nuevaNotificacion = {
            id: tipo + "_" + Date.now(),
            tipo: tipo,
            titulo: titulo,
            mensaje: mensaje,
            fecha: new Date(),
            prioridad: prioridad || "baja",
            icono: obtenerIconoNotificacion(tipo),
            modulo: modulo || "Sistema"
        }
        
        notificacionesActivas.push(nuevaNotificacion)
        totalNotificaciones = notificacionesActivas.length
        
        console.log("🔔 Nueva notificación:", titulo)
        notificacionesActualizadas()
        nuevaNotificacion(tipo, titulo, mensaje)
    }
    
    function marcarNotificacionComoLeida(notificacionId) {
        for (var i = 0; i < notificacionesActivas.length; i++) {
            if (notificacionesActivas[i].id === notificacionId) {
                notificacionesActivas[i].leida = true
                break
            }
        }
        notificacionesActualizadas()
    }
    
    function eliminarNotificacion(notificacionId) {
        var nuevasNotificaciones = []
        for (var i = 0; i < notificacionesActivas.length; i++) {
            if (notificacionesActivas[i].id !== notificacionId) {
                nuevasNotificaciones.push(notificacionesActivas[i])
            }
        }
        
        notificacionesActivas = nuevasNotificaciones
        totalNotificaciones = notificacionesActivas.length
        notificacionesActualizadas()
    }
    
    function obtenerIconoNotificacion(tipo) {
        switch(tipo) {
            case "vencido": return "🚨"
            case "proximo_vencer": return "⚠️"
            case "bajo_stock": return "📦"
            case "cita_hoy": return "📅"
            case "bienvenida": return "👋"
            case "error": return "❌"
            case "exito": return "✅"
            case "info": return "ℹ️"
            default: return "🔔"
        }
    }
    
    // ========== FUNCIONES DE UTILIDAD ==========
    function tienePermiso(modulo) {
        if (!usuarioLogueado) return false
        return usuarioPermisos[modulo] === true
    }
    
    function formatearFecha(fecha) {
        return Qt.formatDate(fecha, "dd/MM/yyyy hh:mm")
    }
    
    // ========== INICIALIZACIÓN ==========
    Component.onCompleted: {
        console.log("🏗️ GlobalDataCenter inicializado")
    }
}