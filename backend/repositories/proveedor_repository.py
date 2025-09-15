from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from decimal import Decimal

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)

class ProveedorRepository(BaseRepository):
    """Repository especializado para gestión de proveedores - SOLO 3 CAMPOS"""
    
    def __init__(self):
        super().__init__('Proveedor', 'proveedores')
        print("🏢 ProveedorRepository inicializado - SIMPLIFICADO")
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene proveedores activos con estadísticas - CORREGIDO PARA DATOS ACTUALES"""
        query = """
        SELECT p.id, p.Nombre, p.Direccion, 
            COUNT(c.id) as Total_Compras,
            ISNULL(SUM(c.Total), 0) as Monto_Total,
            ISNULL(AVG(c.Total), 0) as Compra_Promedio,
            CASE 
                WHEN MAX(c.Fecha) IS NULL THEN NULL
                ELSE MAX(c.Fecha)
            END as Ultima_Compra,
            CASE 
                WHEN MAX(c.Fecha) >= DATEADD(MONTH, -3, GETDATE()) THEN 'Activo'
                WHEN MAX(c.Fecha) >= DATEADD(MONTH, -12, GETDATE()) THEN 'Inactivo'
                WHEN COUNT(c.id) = 0 THEN 'Sin_Compras'
                ELSE 'Obsoleto'
            END as Estado
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        GROUP BY p.id, p.Nombre, p.Direccion
        ORDER BY p.Nombre ASC
        """
        
        # ✅ FORZAR CONSULTA SIN CACHE PARA DATOS ACTUALES
        resultados = self._execute_query(query, use_cache=False)
        
        # ✅ PROCESAR FECHAS SEGURAMENTE
        for resultado in resultados:
            if resultado.get('Ultima_Compra') is None:
                resultado['Ultima_Compra'] = None
            elif isinstance(resultado.get('Ultima_Compra'), datetime):
                resultado['Ultima_Compra'] = resultado['Ultima_Compra'].strftime('%Y-%m-%d')
        
        # ✅ LOG DETALLADO PARA DEBUG
        print(f"📊 get_active: {len(resultados)} proveedores obtenidos (SIN CACHE)")
        
        # Log de proveedores con compras
        proveedores_con_compras = [r for r in resultados if r.get('Total_Compras', 0) > 0]
        if proveedores_con_compras:
            print("📋 Proveedores con compras encontrados:")
            for prov in proveedores_con_compras:
                nombre = prov.get('Nombre', 'Sin nombre')
                compras = prov.get('Total_Compras', 0)
                monto = prov.get('Monto_Total', 0)
                estado = prov.get('Estado', 'Sin estado')
                print(f"   • {nombre}: {compras} compras, Bs{monto}, Estado: {estado}")
        
        return resultados
    
    @ExceptionHandler.handle_exception
    def crear_proveedor(self, nombre: str, direccion: str) -> int:
        """Crea nuevo proveedor - SOLO 3 CAMPOS"""
        validate_required(nombre, "nombre")
        validate_required(direccion, "direccion")
        
        nombre = nombre.strip()
        direccion = direccion.strip()
        
        # Verificar duplicados
        if self.existe_proveedor(nombre):
            raise ValidationError("nombre", nombre, "Ya existe un proveedor con este nombre")
        
        proveedor_data = {
            'Nombre': nombre,
            'Direccion': direccion
        }
        
        proveedor_id = self.insert(proveedor_data)
        
        if proveedor_id:
            print(f"🏢 Proveedor creado - ID: {proveedor_id}, Nombre: {nombre}")
        
        return proveedor_id
    
    @ExceptionHandler.handle_exception
    def actualizar_proveedor(self, proveedor_id: int, datos: Dict[str, Any]) -> bool:
        """Actualiza proveedor existente - SOLO 3 CAMPOS"""
        validate_required(proveedor_id, "proveedor_id")
        validate_required(datos, "datos")
        
        # Verificar que existe
        proveedor_actual = self.get_by_id(proveedor_id)
        if not proveedor_actual:
            raise ValidationError("proveedor_id", proveedor_id, "Proveedor no encontrado")
        
        # Validar nombre único si se está cambiando
        if 'Nombre' in datos:
            nombre_nuevo = datos['Nombre'].strip()
            if nombre_nuevo != proveedor_actual['Nombre']:
                if self.existe_proveedor(nombre_nuevo):
                    raise ValidationError("Nombre", nombre_nuevo, "Ya existe un proveedor con este nombre")
        
        # Limpiar datos - SOLO CAMPOS VÁLIDOS
        datos_limpios = {}
        for campo in ['Nombre', 'Direccion']:
            if campo in datos:
                datos_limpios[campo] = datos[campo].strip() if datos[campo] else ""
        
        exito = self.update(proveedor_id, datos_limpios)
        
        if exito:
            print(f"✏️ Proveedor actualizado - ID: {proveedor_id}")
        
        return exito
    
    @ExceptionHandler.handle_exception
    def eliminar_proveedor(self, proveedor_id: int) -> bool:
        """Elimina proveedor si no tiene compras asociadas"""
        validate_required(proveedor_id, "proveedor_id")
        
        # Verificar que existe
        proveedor = self.get_by_id(proveedor_id)
        if not proveedor:
            raise ValidationError("proveedor_id", proveedor_id, "Proveedor no encontrado")
        
        # Verificar que no tiene compras
        compras_query = "SELECT COUNT(*) as count FROM Compra WHERE Id_Proveedor = ?"
        resultado = self._execute_query(compras_query, (proveedor_id,), fetch_one=True)
        
        if resultado and resultado['count'] > 0:
            raise ValidationError("proveedor_id", proveedor_id, 
                                f"No se puede eliminar. Tiene {resultado['count']} compras asociadas")
        
        exito = self.delete(proveedor_id)
        
        if exito:
            print(f"🗑️ Proveedor eliminado - ID: {proveedor_id}")
        
        return exito
    
    def existe_proveedor(self, nombre: str) -> bool:
        """Verifica si existe proveedor por nombre"""
        query = "SELECT COUNT(*) as count FROM Proveedor WHERE LOWER(Nombre) = LOWER(?)"
        resultado = self._execute_query(query, (nombre.strip(),), fetch_one=True)
        return resultado['count'] > 0 if resultado else False
    
    def buscar_proveedores(self, termino: str) -> List[Dict[str, Any]]:
        """Busca proveedores por nombre o dirección - CORREGIDO FECHAS"""
        if not termino or len(termino.strip()) < 2:
            return []
        
        query = """
        SELECT p.id, p.Nombre, p.Direccion, 
               COUNT(c.id) as Total_Compras,
               ISNULL(SUM(c.Total), 0) as Monto_Total,
               CASE 
                   WHEN MAX(c.Fecha) IS NULL THEN NULL
                   ELSE MAX(c.Fecha)
               END as Ultima_Compra
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        WHERE p.Nombre LIKE ? OR p.Direccion LIKE ?
        GROUP BY p.id, p.Nombre, p.Direccion
        ORDER BY p.Nombre
        """
        termino_like = f"%{termino.strip()}%"
        resultados = self._execute_query(query, (termino_like, termino_like))
        
        # ✅ FILTRAR VALORES NULL EN FECHAS
        for resultado in resultados:
            if resultado.get('Ultima_Compra') is None:
                resultado['Ultima_Compra'] = None
            elif isinstance(resultado.get('Ultima_Compra'), datetime):
                resultado['Ultima_Compra'] = resultado['Ultima_Compra'].strftime('%Y-%m-%d')
        
        return resultados
    
    def get_historial_compras(self, proveedor_id: int, limite: int = 50) -> List[Dict[str, Any]]:
        """Obtiene historial de compras de un proveedor"""
        validate_required(proveedor_id, "proveedor_id")
        
        query = f"""
        SELECT TOP {limite}
            c.id,
            c.Fecha,
            c.Total,
            u.Nombre + ' ' + u.Apellido_Paterno as Usuario,
            COUNT(dc.id) as Items_Comprados,
            SUM(dc.Cantidad_Caja) as Total_Cajas,
            SUM(dc.Cantidad_Caja * dc.Cantidad_Unitario) as Total_Unidades
        FROM Compra c
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        LEFT JOIN DetalleCompra dc ON c.id = dc.Id_Compra
        WHERE c.Id_Proveedor = ?
        GROUP BY c.id, c.Fecha, c.Total, u.Nombre, u.Apellido_Paterno
        ORDER BY c.Fecha DESC
        """
        return self._execute_query(query, (proveedor_id,))
    
    def get_estadisticas_proveedor(self, proveedor_id: int) -> Dict[str, Any]:
        """Obtiene estadísticas detalladas de un proveedor"""
        validate_required(proveedor_id, "proveedor_id")
        
        # Estadísticas generales
        stats_query = """
        SELECT 
            COUNT(c.id) as Total_Compras,
            ISNULL(SUM(c.Total), 0) as Monto_Total,
            ISNULL(AVG(c.Total), 0) as Compra_Promedio,
            ISNULL(MIN(c.Total), 0) as Compra_Minima,
            ISNULL(MAX(c.Total), 0) as Compra_Maxima,
            CASE 
                WHEN MIN(c.Fecha) IS NULL THEN NULL
                ELSE MIN(c.Fecha)
            END as Primera_Compra,
            CASE 
                WHEN MAX(c.Fecha) IS NULL THEN NULL
                ELSE MAX(c.Fecha)
            END as Ultima_Compra
        FROM Compra c
        WHERE c.Id_Proveedor = ?
        """
        
        stats = self._execute_query(stats_query, (proveedor_id,), fetch_one=True)
        
        # ✅ LIMPIAR FECHAS NULL
        if stats:
            for campo in ['Primera_Compra', 'Ultima_Compra']:
                if stats.get(campo) is None:
                    stats[campo] = None
                elif isinstance(stats.get(campo), datetime):
                    stats[campo] = stats[campo].strftime('%Y-%m-%d')
        
        # Productos más comprados
        productos_query = """
        SELECT TOP 10
            pr.Codigo,
            pr.Nombre as Producto_Nombre,
            m.Nombre as Marca_Nombre,
            SUM(dc.Cantidad_Caja + dc.Cantidad_Unitario) as Cantidad_Total,
            COUNT(c.id) as Num_Compras,
            SUM((dc.Cantidad_Caja + dc.Cantidad_Unitario) * dc.Precio_Unitario) as Monto_Total
        FROM Compra c
        INNER JOIN DetalleCompra dc ON c.id = dc.Id_Compra
        INNER JOIN Lote l ON dc.Id_Lote = l.id
        INNER JOIN Productos pr ON l.Id_Producto = pr.id
        LEFT JOIN Marca m ON pr.ID_Marca = m.id
        WHERE c.Id_Proveedor = ?
        GROUP BY pr.id, pr.Codigo, pr.Nombre, m.Nombre
        ORDER BY Cantidad_Total DESC
        """
        
        productos = self._execute_query(productos_query, (proveedor_id,))
        
        # Compras por mes (últimos 12 meses)
        compras_mes_query = """
        SELECT 
            YEAR(c.Fecha) as Año,
            MONTH(c.Fecha) as Mes,
            COUNT(c.id) as Compras,
            SUM(c.Total) as Monto
        FROM Compra c
        WHERE c.Id_Proveedor = ? AND c.Fecha >= DATEADD(MONTH, -12, GETDATE())
        GROUP BY YEAR(c.Fecha), MONTH(c.Fecha)
        ORDER BY Año DESC, Mes DESC
        """
        
        compras_por_mes = self._execute_query(compras_mes_query, (proveedor_id,))
        
        return {
            'estadisticas_generales': stats or {},
            'productos_mas_comprados': productos or [],
            'compras_por_mes': compras_por_mes or []
        }
    
    def get_resumen_todos_proveedores(self) -> Dict[str, Any]:
        """Obtiene resumen estadístico de todos los proveedores - SIN CACHE"""
        query = """
        SELECT 
            COUNT(DISTINCT p.id) as Total_Proveedores,
            COUNT(DISTINCT CASE WHEN c.id IS NOT NULL THEN p.id END) as Proveedores_Con_Compras,
            COUNT(DISTINCT CASE WHEN c.Fecha >= DATEADD(MONTH, -3, GETDATE()) THEN p.id END) as Proveedores_Activos,
            ISNULL(SUM(c.Total), 0) as Monto_Total_Global,
            ISNULL(AVG(c.Total), 0) as Compra_Promedio_Global
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        """
        
        # ✅ FORZAR SIN CACHE
        resumen = self._execute_query(query, fetch_one=True, use_cache=False)
        
        # Top 5 proveedores por monto - TAMBIÉN SIN CACHE
        top_proveedores_query = """
        SELECT TOP 5
            p.Nombre,
            COUNT(c.id) as Total_Compras,
            SUM(c.Total) as Monto_Total
        FROM Proveedor p
        INNER JOIN Compra c ON p.id = c.Id_Proveedor
        GROUP BY p.id, p.Nombre
        ORDER BY Monto_Total DESC
        """
        
        top_proveedores = self._execute_query(top_proveedores_query, use_cache=False)
        
        result = {
            'resumen': resumen or {},
            'top_proveedores': top_proveedores or []
        }
        
        # ✅ LOG DEL RESUMEN
        if resumen:
            print(f"📊 Resumen proveedores: {resumen.get('Total_Proveedores', 0)} total, {resumen.get('Proveedores_Activos', 0)} activos")
        
        return result
    
    def get_proveedores_paginados(self, pagina: int = 1, por_pagina: int = 10, 
                             termino_busqueda: str = "") -> Dict[str, Any]:
        """Obtiene proveedores con paginación - CORREGIDO PARA DATOS ACTUALES"""
        offset = (pagina - 1) * por_pagina
        
        # Construir WHERE clause
        where_clause = ""
        params = []
        
        if termino_busqueda and termino_busqueda.strip():
            where_clause = "WHERE p.Nombre LIKE ? OR p.Direccion LIKE ?"
            termino_like = f"%{termino_busqueda.strip()}%"
            params = [termino_like, termino_like]
        
        # Query para datos - FORZAR DATOS ACTUALES
        data_query = f"""
        SELECT p.id, p.Nombre, p.Direccion, 
            COUNT(c.id) as Total_Compras,
            ISNULL(SUM(c.Total), 0) as Monto_Total,
            ISNULL(AVG(c.Total), 0) as Compra_Promedio,
            CASE 
                WHEN MAX(c.Fecha) IS NULL THEN NULL
                ELSE MAX(c.Fecha)
            END as Ultima_Compra,
            CASE 
                WHEN MAX(c.Fecha) >= DATEADD(MONTH, -3, GETDATE()) THEN 'Activo'
                WHEN MAX(c.Fecha) >= DATEADD(MONTH, -12, GETDATE()) THEN 'Inactivo'
                WHEN COUNT(c.id) = 0 THEN 'Sin_Compras'
                ELSE 'Obsoleto'
            END as Estado
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        {where_clause}
        GROUP BY p.id, p.Nombre, p.Direccion
        ORDER BY p.Nombre
        OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
        """
        
        data_params = params + [offset, por_pagina]
        
        # ✅ FORZAR CONSULTA SIN CACHE
        data = self._execute_query(data_query, tuple(data_params), use_cache=False)
        
        # ✅ LIMPIAR FECHAS NULL EN RESULTADOS
        for resultado in data:
            if resultado.get('Ultima_Compra') is None:
                resultado['Ultima_Compra'] = None
            elif isinstance(resultado.get('Ultima_Compra'), datetime):
                resultado['Ultima_Compra'] = resultado['Ultima_Compra'].strftime('%Y-%m-%d')
        
        # Query para total - TAMBIÉN SIN CACHE
        count_query = f"""
        SELECT COUNT(DISTINCT p.id) as total
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        {where_clause}
        """
        
        total_result = self._execute_query(count_query, tuple(params), fetch_one=True, use_cache=False)
        total = total_result['total'] if total_result else 0
        
        # ✅ LOG DETALLADO
        print(f"📊 get_proveedores_paginados: Página {pagina}, {len(data)} de {total} (SIN CACHE)")
        
        return {
            'data': data,
            'total': total,
            'pagina': pagina,
            'por_pagina': por_pagina,
            'paginas': (total + por_pagina - 1) // por_pagina
        }
    
    def invalidate_proveedores_cache(self):
        """Invalida específicamente el cache de proveedores"""
        try:
            if hasattr(self, '_cache_manager') and self._cache_manager:
                # Invalidar patrones específicos de proveedores
                patterns_to_invalidate = [
                    'proveedores*',
                    'proveedor_*', 
                    'get_active*',
                    'get_proveedores_paginados*',
                    'get_estadisticas*',
                    'get_resumen*'
                ]
                
                for pattern in patterns_to_invalidate:
                    self._cache_manager.invalidate_pattern(pattern)
                    print(f"🗑️ Pattern invalidado: {pattern}")
                
                print("✅ Cache de proveedores invalidado completamente")
                
        except Exception as e:
            print(f"❌ Error invalidando cache: {str(e)}")

    def _execute_query_force_fresh(self, query: str, params=None, fetch_one=False):
        """Ejecuta query FORZADAMENTE sin cache para datos críticos"""
        # Guardar estado de cache actual
        original_use_cache = getattr(self, '_use_cache_default', True)
        
        try:
            # Desactivar cache temporalmente
            self._use_cache_default = False
            
            # Ejecutar query
            result = self._execute_query(query, params, fetch_one=fetch_one, use_cache=False)
            
            print(f"🔍 Query ejecutada FORZADAMENTE sin cache: {len(str(query)[:50])}...")
            return result
            
        finally:
            # Restaurar estado de cache
            self._use_cache_default = original_use_cache

    # ✅ 6. MÉTODO PARA OBTENER ESTADÍSTICAS ESPECÍFICAS DE PROVEEDOR SIN CACHE
    def get_estadisticas_proveedor_fresh(self, proveedor_id: int) -> Dict[str, Any]:
        """Obtiene estadísticas FRESCAS de un proveedor específico"""
        validate_required(proveedor_id, "proveedor_id")
        
        # Estadísticas generales - SIN CACHE
        stats_query = """
        SELECT 
            COUNT(c.id) as Total_Compras,
            ISNULL(SUM(c.Total), 0) as Monto_Total,
            ISNULL(AVG(c.Total), 0) as Compra_Promedio,
            ISNULL(MIN(c.Total), 0) as Compra_Minima,
            ISNULL(MAX(c.Total), 0) as Compra_Maxima,
            CASE 
                WHEN MIN(c.Fecha) IS NULL THEN NULL
                ELSE MIN(c.Fecha)
            END as Primera_Compra,
            CASE 
                WHEN MAX(c.Fecha) IS NULL THEN NULL
                ELSE MAX(c.Fecha)
            END as Ultima_Compra
        FROM Compra c
        WHERE c.Id_Proveedor = ?
        """
        
        stats = self._execute_query_force_fresh(stats_query, (proveedor_id,), fetch_one=True)
        
        # ✅ LIMPIAR FECHAS NULL
        if stats:
            for campo in ['Primera_Compra', 'Ultima_Compra']:
                if stats.get(campo) is None:
                    stats[campo] = None
                elif isinstance(stats.get(campo), datetime):
                    stats[campo] = stats[campo].strftime('%Y-%m-%d')
        
        print(f"📊 Estadísticas frescas proveedor {proveedor_id}: {stats.get('Total_Compras', 0) if stats else 0} compras")
        
        return {
            'estadisticas_generales': stats or {},
            'productos_mas_comprados': [],  # Simplificado por ahora
            'compras_por_mes': []  # Simplificado por ahora
        }
