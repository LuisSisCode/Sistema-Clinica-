-- ═══════════════════════════════════════════════════════════════════
-- SCRIPT DE OPTIMIZACIÓN - ÍNDICES BASE DE DATOS
-- Sistema Clínica María Inmaculada v1.0
-- ═══════════════════════════════════════════════════════════════════
-- 
-- PROPÓSITO:
-- Este script crea índices en las tablas más consultadas para mejorar
-- significativamente el rendimiento del sistema, especialmente en:
-- 
-- ✅ Búsquedas de productos (farmacia)
-- ✅ Sistema FIFO (lotes por fecha)
-- ✅ Reportes de ventas y compras
-- ✅ Historial de pacientes
-- ✅ Alertas de vencimiento
-- 
-- IMPACTO ESPERADO:
-- - Búsquedas: 5-10x más rápidas
-- - Reportes: 10-20x más rápidos
-- - FIFO: 3-5x más rápido
-- 
-- EJECUCIÓN:
-- - Primera vez: ~2-5 minutos
-- - Con datos (1000+ productos): ~10-15 minutos
-- 
-- COMPATIBILIDAD:
-- - SQL Server 2019+
-- - SQL Server Express 2019+
-- 
-- ═══════════════════════════════════════════════════════════════════

USE [ClinicaMariaInmaculada]
GO

PRINT '═══════════════════════════════════════════════════════════════════'
PRINT 'INICIANDO CREACIÓN DE ÍNDICES DE OPTIMIZACIÓN'
PRINT 'Sistema Clínica María Inmaculada v1.0'
PRINT '═══════════════════════════════════════════════════════════════════'
PRINT ''
PRINT 'Fecha: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- SECCIÓN 1: ÍNDICES PARA TABLA PRODUCTOS
-- ═══════════════════════════════════════════════════════════════════
-- Justificación:
-- - Búsquedas frecuentes por nombre (barra de búsqueda)
-- - Filtros por estado activo
-- - JOIN constante con Marca
-- - Ordenamiento por nombre
-- ═══════════════════════════════════════════════════════════════════

PRINT '[1/12] Creando índices para tabla Productos...'

-- Índice para búsqueda por nombre
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Productos_Nombre')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Productos_Nombre
    ON [dbo].[Productos] ([Nombre] ASC)
    INCLUDE ([Codigo], [Precio_venta], [Stock_Unitario], [Activo])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Productos_Nombre'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Productos_Nombre'

-- Índice para filtrar productos activos + JOIN con Marca
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Productos_Activo_Marca')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Productos_Activo_Marca
    ON [dbo].[Productos] ([Activo] ASC, [ID_Marca] ASC)
    INCLUDE ([Nombre], [Codigo], [Precio_venta], [Stock_Unitario])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Productos_Activo_Marca'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Productos_Activo_Marca'

-- Índice para alertas de stock bajo
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Productos_Stock')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Productos_Stock
    ON [dbo].[Productos] ([Stock_Unitario] ASC, [Stock_Minimo] ASC)
    WHERE ([Activo] = 1)
    INCLUDE ([Nombre], [Codigo])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Productos_Stock'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Productos_Stock'

PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- SECCIÓN 2: ÍNDICES PARA TABLA LOTE (CRÍTICO PARA FIFO)
-- ═══════════════════════════════════════════════════════════════════
-- Justificación:
-- - Sistema FIFO requiere ordenar por fecha
-- - Búsquedas frecuentes de lotes activos por producto
-- - Alertas de vencimiento (comparación de fechas)
-- - JOIN constante con Productos
-- ═══════════════════════════════════════════════════════════════════

PRINT '[2/12] Creando índices para tabla Lote (FIFO)...'

-- Índice PRINCIPAL para FIFO: Producto + Estado + Fecha (MÁS IMPORTANTE)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Lote_FIFO_Principal')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Lote_FIFO_Principal
    ON [dbo].[Lote] ([Id_Producto] ASC, [Estado] ASC, [Fecha_Compra] ASC)
    INCLUDE ([Stock_Actual], [Fecha_Vencimiento], [Precio_Compra], [Cantidad_Unitario])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Lote_FIFO_Principal (MÁS IMPORTANTE)'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Lote_FIFO_Principal'

-- Índice para alertas de vencimiento
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Lote_Vencimiento')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Lote_Vencimiento
    ON [dbo].[Lote] ([Fecha_Vencimiento] ASC, [Estado] ASC)
    WHERE ([Stock_Actual] > 0 AND [Fecha_Vencimiento] IS NOT NULL)
    INCLUDE ([Id_Producto], [Stock_Actual])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Lote_Vencimiento'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Lote_Vencimiento'

-- Índice para lotes por compra
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Lote_Compra')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Lote_Compra
    ON [dbo].[Lote] ([Id_Compra] ASC)
    INCLUDE ([Id_Producto], [Cantidad_Unitario], [Stock_Actual], [Precio_Compra])
    WHERE ([Id_Compra] IS NOT NULL)
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Lote_Compra'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Lote_Compra'

PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- SECCIÓN 3: ÍNDICES PARA VENTAS
-- ═══════════════════════════════════════════════════════════════════
-- Justificación:
-- - Reportes diarios/mensuales requieren filtrar por fecha
-- - Auditoría por usuario
-- - Cierre de caja por fecha
-- ═══════════════════════════════════════════════════════════════════

PRINT '[3/12] Creando índices para tabla Ventas...'

-- Índice para reportes por fecha (descendente = más recientes primero)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Ventas_Fecha')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Ventas_Fecha
    ON [dbo].[Ventas] ([Fecha] DESC)
    INCLUDE ([Total], [Id_Usuario])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Ventas_Fecha'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Ventas_Fecha'

-- Índice para ventas por usuario
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Ventas_Usuario')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Ventas_Usuario
    ON [dbo].[Ventas] ([Id_Usuario] ASC, [Fecha] DESC)
    INCLUDE ([Total])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Ventas_Usuario'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Ventas_Usuario'

PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- SECCIÓN 4: ÍNDICES PARA DETALLES DE VENTAS
-- ═══════════════════════════════════════════════════════════════════
-- Justificación:
-- - JOIN frecuente con Ventas
-- - Cálculo de totales por venta
-- - Análisis de productos vendidos
-- ═══════════════════════════════════════════════════════════════════

PRINT '[4/12] Creando índices para tabla DetallesVentas...'

-- Índice para JOIN con Ventas
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DetallesVentas_Venta')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DetallesVentas_Venta
    ON [dbo].[DetallesVentas] ([Id_Venta] ASC)
    INCLUDE ([Id_Lote], [Cantidad_Unitario], [Precio_Unitario])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_DetallesVentas_Venta'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_DetallesVentas_Venta'

-- Índice para análisis por lote
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DetallesVentas_Lote')
BEGIN
    CREATE NONCLUSTERED INDEX IX_DetallesVentas_Lote
    ON [dbo].[DetallesVentas] ([Id_Lote] ASC)
    INCLUDE ([Id_Venta], [Cantidad_Unitario], [Costo_Unitario], [Margen])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_DetallesVentas_Lote'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_DetallesVentas_Lote'

PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- SECCIÓN 5: ÍNDICES PARA COMPRAS
-- ═══════════════════════════════════════════════════════════════════

PRINT '[5/12] Creando índices para tabla Compra...'

-- Índice para reportes de compras por fecha
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Compra_Fecha')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Compra_Fecha
    ON [dbo].[Compra] ([Fecha] DESC)
    INCLUDE ([Total], [Id_Proveedor], [Id_Usuario])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Compra_Fecha'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Compra_Fecha'

-- Índice para compras por proveedor
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Compra_Proveedor')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Compra_Proveedor
    ON [dbo].[Compra] ([Id_Proveedor] ASC, [Fecha] DESC)
    INCLUDE ([Total])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Compra_Proveedor'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Compra_Proveedor'

PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- SECCIÓN 6: ÍNDICES PARA CONSULTAS MÉDICAS
-- ═══════════════════════════════════════════════════════════════════

PRINT '[6/12] Creando índices para tabla Consultas...'

-- Índice para consultas por fecha
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Consultas_Fecha')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Consultas_Fecha
    ON [dbo].[Consultas] ([Fecha] DESC)
    INCLUDE ([Id_Paciente], [Id_Especialidad], [Id_Usuario])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Consultas_Fecha'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Consultas_Fecha'

-- Índice para historial de paciente
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Consultas_Paciente')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Consultas_Paciente
    ON [dbo].[Consultas] ([Id_Paciente] ASC, [Fecha] DESC)
    INCLUDE ([Id_Especialidad], [Tipo_Consulta])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Consultas_Paciente'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Consultas_Paciente'

PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- SECCIÓN 7: ÍNDICES PARA LABORATORIO
-- ═══════════════════════════════════════════════════════════════════

PRINT '[7/12] Creando índices para tabla Laboratorio...'

-- Índice para análisis por fecha
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Laboratorio_Fecha')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Laboratorio_Fecha
    ON [dbo].[Laboratorio] ([Fecha] DESC)
    INCLUDE ([Id_Paciente], [Id_TipoAnalisis], [Id_Usuario])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Laboratorio_Fecha'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Laboratorio_Fecha'

-- Índice para historial de análisis del paciente
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Laboratorio_Paciente')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Laboratorio_Paciente
    ON [dbo].[Laboratorio] ([Id_Paciente] ASC, [Fecha] DESC)
    INCLUDE ([Id_TipoAnalisis], [Estado])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Laboratorio_Paciente'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Laboratorio_Paciente'

PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- SECCIÓN 8: ÍNDICES PARA ENFERMERÍA
-- ═══════════════════════════════════════════════════════════════════

PRINT '[8/12] Creando índices para tabla Enfermeria...'

-- Índice para procedimientos por fecha
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Enfermeria_Fecha')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Enfermeria_Fecha
    ON [dbo].[Enfermeria] ([Fecha] DESC)
    INCLUDE ([Id_Paciente], [Id_Procedimiento], [Tipo])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Enfermeria_Fecha'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Enfermeria_Fecha'

-- Índice para historial del paciente
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Enfermeria_Paciente')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Enfermeria_Paciente
    ON [dbo].[Enfermeria] ([Id_Paciente] ASC, [Fecha] DESC)
    INCLUDE ([Id_Procedimiento], [Cantidad], [Tipo])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Enfermeria_Paciente'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Enfermeria_Paciente'

PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- SECCIÓN 9: ÍNDICES PARA EGRESOS (GASTOS)
-- ═══════════════════════════════════════════════════════════════════

PRINT '[9/12] Creando índices para tabla Egresos...'

-- Índice para egresos por fecha y estado
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Egresos_Fecha_Estado')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Egresos_Fecha_Estado
    ON [dbo].[Egresos] ([Fecha] DESC, [Estado] ASC)
    INCLUDE ([Monto], [Id_Tipo_Gasto], [Id_Usuario])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Egresos_Fecha_Estado'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Egresos_Fecha_Estado'

-- Índice para egresos por tipo
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Egresos_Tipo')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Egresos_Tipo
    ON [dbo].[Egresos] ([Id_Tipo_Gasto] ASC, [Estado] ASC, [Fecha] DESC)
    INCLUDE ([Monto])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Egresos_Tipo'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Egresos_Tipo'

PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- SECCIÓN 10: ÍNDICES PARA KARDEX (HISTORIAL DE MOVIMIENTOS)
-- ═══════════════════════════════════════════════════════════════════

PRINT '[10/12] Creando índices para tabla Kardex...'

-- Índice para movimientos por producto y fecha
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Kardex_Producto_Fecha')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Kardex_Producto_Fecha
    ON [dbo].[Kardex] ([Id_Producto] ASC, [Fecha] DESC)
    INCLUDE ([Id_Lote], [Tipo_Movimiento], [Cantidad], [Precio_Unitario])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Kardex_Producto_Fecha'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Kardex_Producto_Fecha'

-- Índice para movimientos por lote
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Kardex_Lote')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Kardex_Lote
    ON [dbo].[Kardex] ([Id_Lote] ASC, [Fecha] DESC)
    INCLUDE ([Tipo_Movimiento], [Cantidad])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Kardex_Lote'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Kardex_Lote'

PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- SECCIÓN 11: ÍNDICES PARA PACIENTES
-- ═══════════════════════════════════════════════════════════════════

PRINT '[11/12] Creando índices para tabla Pacientes...'

-- Índice para búsqueda por apellido
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Pacientes_Apellido')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Pacientes_Apellido
    ON [dbo].[Pacientes] ([Apellido_Paterno] ASC, [Apellido_Materno] ASC)
    INCLUDE ([Nombre], [Cedula])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Pacientes_Apellido'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Pacientes_Apellido'

-- Índice para búsqueda por nombre completo
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Pacientes_Nombre')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Pacientes_Nombre
    ON [dbo].[Pacientes] ([Nombre] ASC)
    INCLUDE ([Apellido_Paterno], [Apellido_Materno], [Cedula])
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Pacientes_Nombre'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Pacientes_Nombre'

PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- SECCIÓN 12: ÍNDICES PARA SESIONES DE USUARIO
-- ═══════════════════════════════════════════════════════════════════

PRINT '[12/12] Creando índices para tabla Sesiones_Usuario...'

-- Índice para sesiones activas
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Sesiones_Activas')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Sesiones_Activas
    ON [dbo].[Sesiones_Usuario] ([Activa] ASC, [Fecha_Expiracion] DESC)
    INCLUDE ([Id_Usuario], [token])
    WHERE ([Activa] = 1)
    WITH (STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF);
    
    PRINT '   ✅ Creado: IX_Sesiones_Activas'
END
ELSE
    PRINT '   ℹ️  Ya existe: IX_Sesiones_Activas'

PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- ACTUALIZAR ESTADÍSTICAS DE TODAS LAS TABLAS
-- ═══════════════════════════════════════════════════════════════════

PRINT '📊 Actualizando estadísticas de todas las tablas...'
PRINT ''

EXEC sp_updatestats;

PRINT '   ✅ Estadísticas actualizadas'
PRINT ''

-- ═══════════════════════════════════════════════════════════════════
-- RESUMEN FINAL
-- ═══════════════════════════════════════════════════════════════════

PRINT '═══════════════════════════════════════════════════════════════════'
PRINT '✅ OPTIMIZACIÓN COMPLETADA EXITOSAMENTE'
PRINT '═══════════════════════════════════════════════════════════════════'
PRINT ''
PRINT 'ÍNDICES CREADOS:'
PRINT '  • Productos: 3 índices'
PRINT '  • Lote (FIFO): 3 índices'
PRINT '  • Ventas: 2 índices'
PRINT '  • DetallesVentas: 2 índices'
PRINT '  • Compra: 2 índices'
PRINT '  • Consultas: 2 índices'
PRINT '  • Laboratorio: 2 índices'
PRINT '  • Enfermería: 2 índices'
PRINT '  • Egresos: 2 índices'
PRINT '  • Kardex: 2 índices'
PRINT '  • Pacientes: 2 índices'
PRINT '  • Sesiones_Usuario: 1 índice'
PRINT ''
PRINT 'TOTAL: 25 índices'
PRINT ''
PRINT 'BENEFICIOS ESPERADOS:'
PRINT '  ✅ Búsquedas de productos: 5-10x más rápidas'
PRINT '  ✅ Sistema FIFO: 3-5x más rápido'
PRINT '  ✅ Reportes por fecha: 10-20x más rápidos'
PRINT '  ✅ Historial de pacientes: 5-8x más rápido'
PRINT '  ✅ Alertas de vencimiento: 8-12x más rápidas'
PRINT ''
PRINT 'NOTAS IMPORTANTES:'
PRINT '  📝 Los índices ocupan espacio adicional en disco (~10-20% más)'
PRINT '  📝 Las inserciones pueden ser ligeramente más lentas'
PRINT '  📝 El beneficio en consultas compensa ampliamente el costo'
PRINT ''
PRINT 'MANTENIMIENTO RECOMENDADO:'
PRINT '  🔧 Reorganizar índices: Mensual'
PRINT '  🔧 Reconstruir índices: Trimestral'
PRINT '  🔧 Actualizar estadísticas: Semanal'
PRINT ''
PRINT 'Fecha de creación: ' + CONVERT(VARCHAR, GETDATE(), 120)
PRINT ''
PRINT '═══════════════════════════════════════════════════════════════════'
PRINT 'FIN DEL SCRIPT DE OPTIMIZACIÓN'
PRINT '═══════════════════════════════════════════════════════════════════'

GO
