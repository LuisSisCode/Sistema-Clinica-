from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from decimal import Decimal

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)

class ProveedorRepository(BaseRepository):
    """Repository especializado para gestión de proveedores"""
    
    def __init__(self):
        super().__init__('Proveedor', 'proveedores')
        print("🏢 ProveedorRepository inicializado")
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene proveedores activos con estadísticas"""
        query = """
        SELECT p.*, 
               COUNT(c.id) as Total_Compras,
               ISNULL(SUM(c.Total), 0) as Monto_Total,
               ISNULL(AVG(c.Total), 0) as Compra_Promedio,
               MAX(c.Fecha) as Ultima_Compra,
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
        return self._execute_query(query)
    
    @ExceptionHandler.handle_exception
    def crear_proveedor(self, nombre: str, direccion: str, telefono: str = "", email: str = "", contacto: str = "") -> int:
        """Crea nuevo proveedor con validaciones completas"""
        validate_required(nombre, "nombre")
        validate_required(direccion, "direccion")
        
        nombre = nombre.strip()
        direccion = direccion.strip()
        
        # Verificar duplicados
        if self.existe_proveedor(nombre):
            raise ValidationError("nombre", nombre, "Ya existe un proveedor con este nombre")
        
        proveedor_data = {
            'Nombre': nombre,
            'Direccion': direccion,
            'Telefono': telefono.strip() if telefono else "",
            'Email': email.strip() if email else "",
            'Contacto': contacto.strip() if contacto else ""
        }
        
        proveedor_id = self.insert(proveedor_data)
        
        if proveedor_id:
            print(f"🏢 Proveedor creado - ID: {proveedor_id}, Nombre: {nombre}")
        
        return proveedor_id
    
    @ExceptionHandler.handle_exception
    def actualizar_proveedor(self, proveedor_id: int, datos: Dict[str, Any]) -> bool:
        """Actualiza proveedor existente"""
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
        
        # Limpiar datos
        datos_limpios = {}
        for campo in ['Nombre', 'Direccion', 'Telefono', 'Email', 'Contacto']:
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
        """Busca proveedores por nombre, dirección o contacto"""
        if not termino or len(termino.strip()) < 2:
            return []
        
        query = """
        SELECT p.*, 
               COUNT(c.id) as Total_Compras,
               ISNULL(SUM(c.Total), 0) as Monto_Total,
               MAX(c.Fecha) as Ultima_Compra
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        WHERE p.Nombre LIKE ? OR p.Direccion LIKE ? OR p.Contacto LIKE ? OR p.Email LIKE ?
        GROUP BY p.id, p.Nombre, p.Direccion, p.Telefono, p.Email, p.Contacto
        ORDER BY p.Nombre
        """
        termino_like = f"%{termino.strip()}%"
        return self._execute_query(query, (termino_like, termino_like, termino_like, termino_like))
    
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
            SUM(dc.Cantidad_Caja + dc.Cantidad_Unitario) as Unidades_Totales
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
            MIN(c.Fecha) as Primera_Compra,
            MAX(c.Fecha) as Ultima_Compra
        FROM Compra c
        WHERE c.Id_Proveedor = ?
        """
        
        stats = self._execute_query(stats_query, (proveedor_id,), fetch_one=True)
        
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
        """Obtiene resumen estadístico de todos los proveedores"""
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
        
        resumen = self._execute_query(query, fetch_one=True)
        
        # Top 5 proveedores por monto
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
        
        top_proveedores = self._execute_query(top_proveedores_query)
        
        return {
            'resumen': resumen or {},
            'top_proveedores': top_proveedores or []
        }
    
    def get_proveedores_paginados(self, pagina: int = 1, por_pagina: int = 10, 
                                 termino_busqueda: str = "") -> Dict[str, Any]:
        """Obtiene proveedores con paginación y búsqueda"""
        offset = (pagina - 1) * por_pagina
        
        # Construir WHERE clause
        where_clause = ""
        params = []
        
        if termino_busqueda and termino_busqueda.strip():
            where_clause = """
            WHERE p.Nombre LIKE ? OR p.Direccion LIKE ? 
               OR p.Contacto LIKE ? OR p.Email LIKE ?
            """
            termino_like = f"%{termino_busqueda.strip()}%"
            params = [termino_like, termino_like, termino_like, termino_like]
        
        # Query para datos
        data_query = f"""
        SELECT p.*, 
               COUNT(c.id) as Total_Compras,
               ISNULL(SUM(c.Total), 0) as Monto_Total,
               ISNULL(AVG(c.Total), 0) as Compra_Promedio,
               MAX(c.Fecha) as Ultima_Compra,
               CASE 
                   WHEN MAX(c.Fecha) >= DATEADD(MONTH, -3, GETDATE()) THEN 'Activo'
                   WHEN MAX(c.Fecha) >= DATEADD(MONTH, -12, GETDATE()) THEN 'Inactivo'
                   WHEN COUNT(c.id) = 0 THEN 'Sin_Compras'
                   ELSE 'Obsoleto'
               END as Estado
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        {where_clause}
        GROUP BY p.id, p.Nombre, p.Direccion, p.Telefono, p.Email, p.Contacto
        ORDER BY p.Nombre
        OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
        """
        
        data_params = params + [offset, por_pagina]
        data = self._execute_query(data_query, tuple(data_params))
        
        # Query para total
        count_query = f"""
        SELECT COUNT(DISTINCT p.id) as total
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        {where_clause}
        """
        
        total_result = self._execute_query(count_query, tuple(params), fetch_one=True)
        total = total_result['total'] if total_result else 0
        
        return {
            'data': data,
            'total': total,
            'pagina': pagina,
            'por_pagina': por_pagina,
            'paginas': (total + por_pagina - 1) // por_pagina
        }