from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from decimal import Decimal

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    CompraError, ProductoNotFoundError, ValidationError,
    ExceptionHandler, validate_required, validate_positive_number
)
from .producto_repository import ProductoRepository

class CompraRepository(BaseRepository):
    """Repository para compras con creación automática de lotes"""
    
    def __init__(self):
        super().__init__('Compra', 'compras')
        self.producto_repo = ProductoRepository()
        print("🛒 CompraRepository inicializado con auto-lotes")
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene compras del mes actual"""
        query = """
        SELECT c.*, p.Nombre as Proveedor_Nombre, u.Nombre + ' ' + u.Apellido_Paterno as Usuario
        FROM Compra c
        INNER JOIN Proveedor p ON c.Id_Proveedor = p.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE MONTH(c.Fecha) = MONTH(GETDATE()) AND YEAR(c.Fecha) = YEAR(GETDATE())
        ORDER BY c.Fecha DESC
        """
        return self._execute_query(query)
    
    def get_compras_con_detalles(self, fecha_desde: str = None, fecha_hasta: str = None) -> List[Dict[str, Any]]:
        """Obtiene compras con sus detalles en período específico"""
        where_clause = ""
        params = []
        
        if fecha_desde and fecha_hasta:
            where_clause = "WHERE c.Fecha BETWEEN ? AND ?"
            params = [fecha_desde, fecha_hasta]
        elif fecha_desde:
            where_clause = "WHERE c.Fecha >= ?"
            params = [fecha_desde]
        elif fecha_hasta:
            where_clause = "WHERE c.Fecha <= ?"
            params = [fecha_hasta]
        
        query = f"""
        SELECT 
            c.id as Compra_ID,
            c.Fecha,
            c.Total as Compra_Total,
            p.Nombre as Proveedor,
            p.Direccion as Proveedor_Direccion,
            u.Nombre + ' ' + u.Apellido_Paterno as Usuario,
            COUNT(dc.id) as Items_Comprados,
            SUM(dc.Cantidad_Caja + dc.Cantidad_Unitario) as Unidades_Totales
        FROM Compra c
        INNER JOIN Proveedor p ON c.Id_Proveedor = p.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        LEFT JOIN DetalleCompra dc ON c.id = dc.Id_Compra
        {where_clause}
        GROUP BY c.id, c.Fecha, c.Total, p.Nombre, p.Direccion, u.Nombre, u.Apellido_Paterno
        ORDER BY c.Fecha DESC
        """
        return self._execute_query(query, tuple(params))
    
    def get_compra_completa(self, compra_id: int) -> Dict[str, Any]:
        """Obtiene compra con todos sus detalles"""
        validate_required(compra_id, "compra_id")
        
        # Datos principales de la compra
        compra_query = """
        SELECT c.*, p.Nombre as Proveedor_Nombre, p.Direccion as Proveedor_Direccion,
            u.Nombre + ' ' + u.Apellido_Paterno as Usuario
        FROM Compra c
        INNER JOIN Proveedor p ON c.Id_Proveedor = p.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE c.id = ?
        """
        compra = self._execute_query(compra_query, (compra_id,), fetch_one=True)
        
        if not compra:
            raise CompraError(f"Compra no encontrada: {compra_id}", compra_id=compra_id)
        
        # Detalles de la compra - CORRECCIÓN APLICADA
        detalles_query = """
        SELECT 
            dc.*,
            l.Fecha_Vencimiento,
            p.Codigo as Producto_Codigo,
            p.Nombre as Producto_Nombre,
            m.Nombre as Marca_Nombre,
            (dc.Cantidad_Caja + dc.Cantidad_Unitario) as Cantidad_Total,
            (dc.Cantidad_Caja + dc.Cantidad_Unitario) * dc.Precio_Unitario as Subtotal
        FROM DetalleCompra dc
        INNER JOIN Lote l ON dc.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        LEFT JOIN Marca m ON p.ID_Marca = m.id
        WHERE dc.Id_Compra = ?
        ORDER BY dc.id
        """
        detalles = self._execute_query(detalles_query, (compra_id,))
        
        compra['detalles'] = detalles
        compra['total_items'] = len(detalles)
        compra['total_unidades'] = sum(detalle['Cantidad_Total'] for detalle in detalles)
        
        return compra
    
    def get_compras_por_proveedor(self, proveedor_id: int = None) -> List[Dict[str, Any]]:
        """Obtiene compras por proveedor"""
        if proveedor_id:
            where_clause = "WHERE c.Id_Proveedor = ?"
            params = (proveedor_id,)
        else:
            where_clause = ""
            params = ()
        
        query = f"""
        SELECT 
            p.Nombre as Proveedor,
            COUNT(c.id) as Total_Compras,
            SUM(c.Total) as Monto_Total,
            AVG(c.Total) as Compra_Promedio,
            MAX(c.Fecha) as Ultima_Compra
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        {where_clause}
        GROUP BY p.id, p.Nombre
        HAVING COUNT(c.id) > 0
        ORDER BY Monto_Total DESC
        """
        return self._execute_query(query, params)
    
    # ===============================
    # CREACIÓN DE COMPRAS CON LOTES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_compra(self, proveedor_id: int, usuario_id: int, items_compra: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Crea nueva compra con generación automática de lotes
        
        Args:
            proveedor_id: ID del proveedor
            usuario_id: ID del usuario comprador
            items_compra: Lista de items [{'codigo': str, 'cantidad_caja': int, 'cantidad_unitario': int, 
                                          'precio_unitario': float, 'fecha_vencimiento': str}]
        
        Returns:
            Información completa de la compra creada
        """
        validate_required(proveedor_id, "proveedor_id")
        validate_required(usuario_id, "usuario_id")
        validate_required(items_compra, "items_compra")
        
        if not items_compra:
            raise CompraError("No se proporcionaron items para la compra")
        
        print(f"📦 Iniciando compra - Proveedor: {proveedor_id}, Items: {len(items_compra)}")
        
        # 1. Validar y preparar items
        items_preparados = []
        total_compra = Decimal('0.00')
        
        for item in items_compra:
            item_preparado = self._validar_y_preparar_item(item)
            items_preparados.append(item_preparado)
            total_compra += item_preparado['subtotal']
        
        # 2. Crear compra principal
        compra_data = {
            'Id_Proveedor': proveedor_id,
            'Id_Usuario': usuario_id,
            'Fecha': datetime.now(),
            'Total': float(total_compra)
        }
        
        print(f"🔍 DEBUG: Datos de compra a insertar: {compra_data}")
        compra_id = self.insert(compra_data)
        print(f"🔍 DEBUG: ID de compra retornado: {compra_id} (tipo: {type(compra_id)})")

        if not compra_id:
            print(f"❌ ERROR: No se pudo crear la compra principal")
            raise CompraError("Error creando compra principal")

        print(f"🛒 Compra creada - ID: {compra_id}, Total: ${total_compra}")
        
        # 3. Procesar items y crear lotes + detalles
        lotes_creados = []
        
        for item in items_preparados:
            lote_info = self._procesar_item_con_lote(compra_id, item)
            lotes_creados.append(lote_info)
        
        # 4. Verificar que se crearon lotes
        if not lotes_creados:
            # Eliminar compra si no se pudieron crear lotes
            self.delete(compra_id)
            raise CompraError("No se pudieron procesar los items de la compra")
        
        # 5. Retornar compra completa
        compra_completa = self.get_compra_completa(compra_id)
        
        print(f"✅ Compra completada - ID: {compra_id}, Lotes: {len(lotes_creados)}")
        
        return compra_completa
    
    def _validar_y_preparar_item(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """Valida y prepara un item para la compra"""
        # Validaciones básicas
        codigo = item.get('codigo', '').strip()
        cantidad_caja = item.get('cantidad_caja', 0)
        cantidad_unitario = item.get('cantidad_unitario', 0)
        precio_unitario = item.get('precio_unitario', 0)
        fecha_vencimiento = item.get('fecha_vencimiento', '')
        
        validate_required(codigo, "codigo")
        validate_required(fecha_vencimiento, "fecha_vencimiento")
        validate_positive_number(precio_unitario, "precio_unitario")
        
        if cantidad_caja <= 0 and cantidad_unitario <= 0:
            raise ValidationError("cantidad", f"{cantidad_caja}/{cantidad_unitario}", 
                                "Debe especificar cantidad de cajas o unitarios")
        
        # Obtener producto
        producto = self.producto_repo.get_by_codigo(codigo)
        if not producto:
            raise ProductoNotFoundError(codigo=codigo)
        
        # Calcular totales
        cantidad_total = cantidad_caja + cantidad_unitario
        subtotal = Decimal(str(cantidad_total)) * Decimal(str(precio_unitario))
        
        return {
            'codigo': codigo,
            'producto_id': producto['id'],
            'producto_nombre': producto['Nombre'],
            'cantidad_caja': cantidad_caja,
            'cantidad_unitario': cantidad_unitario,
            'cantidad_total': cantidad_total,
            'precio_unitario': precio_unitario,
            'fecha_vencimiento': fecha_vencimiento,
            'subtotal': subtotal,
            'producto': producto
        }
    
    def _procesar_item_con_lote(self, compra_id: int, item: Dict[str, Any]) -> Dict[str, Any]:
        """Procesa un item creando lote y detalle de compra"""
        
        # 1. Crear nuevo lote
        lote_id = self.producto_repo.aumentar_stock_compra(
            producto_id=item['producto_id'],
            cantidad_caja=item['cantidad_caja'],
            cantidad_unitario=item['cantidad_unitario'],
            fecha_vencimiento=item['fecha_vencimiento'],
            precio_compra=item['precio_unitario']
        )
        
        if not lote_id:
            raise CompraError(f"Error creando lote para producto {item['codigo']}")
        
        # 2. Crear detalle de compra
        detalle_data = {
            'Id_Compra': compra_id,
            'Id_Lote': lote_id,
            'Cantidad_Caja': item['cantidad_caja'],
            'Cantidad_Unitario': item['cantidad_unitario'],
            'Precio_Unitario': item['precio_unitario']
        }
        
        detalle_query = """
        INSERT INTO DetalleCompra (Id_Compra, Id_Lote, Cantidad_Caja, Cantidad_Unitario, Precio_Unitario)
        OUTPUT INSERTED.id
        VALUES (?, ?, ?, ?, ?)
        """
        
        detalle_result = self._execute_query(
            detalle_query,
            (compra_id, lote_id, item['cantidad_caja'], 
             item['cantidad_unitario'], item['precio_unitario']),
            fetch_one=True
        )
        
        detalle_id = detalle_result['id'] if detalle_result else None
        
        if detalle_id:
            print(f"📝 Detalle creado - ID: {detalle_id}, Lote: {lote_id}, Producto: {item['codigo']}")
        
        return {
            'detalle_id': detalle_id,
            'lote_id': lote_id,
            'producto_codigo': item['codigo'],
            'cantidad_total': item['cantidad_total'],
            'precio_unitario': item['precio_unitario']
        }
    
    # ===============================
    # GESTIÓN DE PROVEEDORES
    # ===============================
    
    def get_proveedores_activos(self) -> List[Dict[str, Any]]:
        """Obtiene proveedores con compras recientes"""
        query = """
        SELECT p.*, 
               COUNT(c.id) as Total_Compras,
               MAX(c.Fecha) as Ultima_Compra,
               SUM(c.Total) as Monto_Total
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        GROUP BY p.id, p.Nombre, p.Direccion
        ORDER BY Ultima_Compra DESC
        """
        return self._execute_query(query)
    
    def crear_proveedor(self, nombre: str, direccion: str) -> int:
        """Crea nuevo proveedor"""
        validate_required(nombre, "nombre")
        validate_required(direccion, "direccion")
        
        # Verificar que no existe
        if self.exists_proveedor(nombre):
            raise ValidationError("nombre", nombre, "Proveedor ya existe")
        
        proveedor_data = {
            'Nombre': nombre.strip(),
            'Direccion': direccion.strip()
        }
        
        proveedor_query = """
        INSERT INTO Proveedor (Nombre, Direccion)
        OUTPUT INSERTED.id
        VALUES (?, ?)
        """
        
        result = self._execute_query(proveedor_query, (nombre.strip(), direccion.strip()), fetch_one=True)
        proveedor_id = result['id'] if result else None
        
        if proveedor_id:
            print(f"🏢 Proveedor creado - ID: {proveedor_id}, Nombre: {nombre}")
        
        return proveedor_id
    
    def exists_proveedor(self, nombre: str) -> bool:
        """Verifica si existe proveedor por nombre"""
        query = "SELECT COUNT(*) as count FROM Proveedor WHERE Nombre = ?"
        result = self._execute_query(query, (nombre.strip(),), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def buscar_proveedores(self, termino: str) -> List[Dict[str, Any]]:
        """Busca proveedores por nombre o dirección"""
        if not termino:
            return []
        
        query = """
        SELECT p.*, 
               COUNT(c.id) as Total_Compras,
               MAX(c.Fecha) as Ultima_Compra
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        WHERE p.Nombre LIKE ? OR p.Direccion LIKE ?
        GROUP BY p.id, p.Nombre, p.Direccion
        ORDER BY p.Nombre
        """
        termino_like = f"%{termino}%"
        return self._execute_query(query, (termino_like, termino_like))
    
    # ===============================
    # REPORTES Y ESTADÍSTICAS
    # ===============================
    
    def get_compras_del_mes(self, año: int = None, mes: int = None) -> Dict[str, Any]:
        """Obtiene resumen de compras del mes"""
        if not año:
            año = datetime.now().year
        if not mes:
            mes = datetime.now().month
        
        query = """
        SELECT 
            COUNT(c.id) as Total_Compras,
            ISNULL(SUM(c.Total), 0) as Gastos_Total,
            ISNULL(AVG(c.Total), 0) as Compra_Promedio,
            COUNT(DISTINCT c.Id_Proveedor) as Proveedores_Utilizados,
            COUNT(DISTINCT p.id) as Productos_Comprados
        FROM Compra c
        LEFT JOIN DetalleCompra dc ON c.id = dc.Id_Compra
        LEFT JOIN Lote l ON dc.Id_Lote = l.id
        LEFT JOIN Productos p ON l.Id_Producto = p.id
        WHERE YEAR(c.Fecha) = ? AND MONTH(c.Fecha) = ?
        """
        
        resumen = self._execute_query(query, (año, mes), fetch_one=True)
        
        # Compras detalladas del mes
        compras_query = """
        SELECT c.*, p.Nombre as Proveedor
        FROM Compra c
        INNER JOIN Proveedor p ON c.Id_Proveedor = p.id
        WHERE YEAR(c.Fecha) = ? AND MONTH(c.Fecha) = ?
        ORDER BY c.Fecha DESC
        """
        
        compras = self._execute_query(compras_query, (año, mes))
        
        return {
            'año': año,
            'mes': mes,
            'resumen': resumen,
            'compras': compras
        }
    
    def get_productos_mas_comprados(self, dias: int = 30, limit: int = 10) -> List[Dict[str, Any]]:
        """Productos más comprados en período"""
        query = f"""
        SELECT TOP {limit}
            p.Codigo,
            p.Nombre as Producto_Nombre,
            m.Nombre as Marca_Nombre,
            SUM(dc.Cantidad_Caja + dc.Cantidad_Unitario) as Cantidad_Comprada,
            COUNT(DISTINCT c.id) as Num_Compras,
            SUM((dc.Cantidad_Caja + dc.Cantidad_Unitario) * dc.Precio_Unitario) as Costo_Total,
            AVG(dc.Precio_Unitario) as Precio_Promedio
        FROM Compra c
        INNER JOIN DetalleCompra dc ON c.id = dc.Id_Compra
        INNER JOIN Lote l ON dc.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        INNER JOIN Marca m ON p.ID_Marca = m.id
        WHERE c.Fecha >= DATEADD(DAY, -?, GETDATE())
        GROUP BY p.id, p.Codigo, p.Nombre, m.Nombre
        ORDER BY Cantidad_Comprada DESC
        """
        return self._execute_query(query, (dias,))
    
    def get_reporte_gastos_compras(self, periodo: int = 30) -> Dict[str, Any]:
        """Reporte de gastos en compras por período"""
        # Gastos totales
        gastos_query = """
        SELECT 
            SUM(Total) as Gastos_Total,
            COUNT(*) as Total_Compras,
            AVG(Total) as Compra_Promedio
        FROM Compra 
        WHERE Fecha >= DATEADD(DAY, -?, GETDATE())
        """
        
        gastos = self._execute_query(gastos_query, (periodo,), fetch_one=True)
        
        # Gastos por proveedor
        por_proveedor_query = """
        SELECT 
            p.Nombre as Proveedor,
            SUM(c.Total) as Gastos_Proveedor,
            COUNT(c.id) as Compras_Realizadas,
            AVG(c.Total) as Compra_Promedio
        FROM Compra c
        INNER JOIN Proveedor p ON c.Id_Proveedor = p.id
        WHERE c.Fecha >= DATEADD(DAY, -?, GETDATE())
        GROUP BY p.id, p.Nombre
        ORDER BY Gastos_Proveedor DESC
        """
        
        por_proveedor = self._execute_query(por_proveedor_query, (periodo,))
        
        # Gastos por día
        gastos_diarios_query = """
        SELECT 
            CAST(Fecha AS DATE) as Fecha,
            SUM(Total) as Gastos_Dia,
            COUNT(*) as Compras_Dia
        FROM Compra 
        WHERE Fecha >= DATEADD(DAY, -?, GETDATE())
        GROUP BY CAST(Fecha AS DATE)
        ORDER BY Fecha DESC
        """
        
        gastos_diarios = self._execute_query(gastos_diarios_query, (periodo,))
        
        return {
            'periodo_dias': periodo,
            'resumen': gastos,
            'por_proveedor': por_proveedor,
            'por_dia': gastos_diarios
        }
    
    def verificar_integridad_compra(self, compra_id: int) -> Dict[str, Any]:
        """Verifica la integridad de una compra"""
        compra = self.get_compra_completa(compra_id)
        
        if not compra:
            return {'valida': False, 'errores': ['Compra no encontrada']}
        
        errores = []
        
        # Verificar que el total coincide
        total_calculado = sum(
            (detalle['Cantidad_Caja'] + detalle['Cantidad_Unitario']) * detalle['Precio_Unitario']
            for detalle in compra['detalles']
        )
        
        if abs(total_calculado - compra['Total']) > 0.01:
            errores.append(f"Total inconsistente: DB={compra['Total']}, Calculado={total_calculado}")
        
        # Verificar que todos los lotes existen y tienen stock
        for detalle in compra['detalles']:
            lote_query = "SELECT * FROM Lote WHERE id = ?"
            lote = self._execute_query(lote_query, (detalle['Id_Lote'],), fetch_one=True)
            if not lote:
                errores.append(f"Lote {detalle['Id_Lote']} no existe")
            elif (lote['Cantidad_Caja'] + lote['Cantidad_Unitario']) <= 0:
                errores.append(f"Lote {detalle['Id_Lote']} sin stock")
        
        return {
            'valida': len(errores) == 0,
            'errores': errores,
            'total_db': compra['Total'],
            'total_calculado': total_calculado
        }
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene compras del mes actual"""
        query = """
        SELECT c.*, p.Nombre as Proveedor_Nombre, u.Nombre + ' ' + u.Apellido_Paterno as Usuario
        FROM Compra c
        INNER JOIN Proveedor p ON c.Id_Proveedor = p.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        WHERE MONTH(c.Fecha) = MONTH(GETDATE()) AND YEAR(c.Fecha) = YEAR(GETDATE())
        ORDER BY c.Fecha DESC
        """
        
        result = self._execute_query(query)
        
        return result