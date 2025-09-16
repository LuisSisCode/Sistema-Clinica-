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
            SUM(dc.Cantidad_Caja) as Total_Cajas,
            SUM(dc.Cantidad_Caja * dc.Cantidad_Unitario) as Unidades_Totales
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
        """Obtiene compra con todos sus detalles - CORREGIDO"""
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
        
        # Detalles de la compra - CORREGIDO: Sin multiplicación por cantidad
        detalles_query = """
        SELECT 
            dc.*,
            l.Fecha_Vencimiento,
            p.Codigo as Producto_Codigo,
            p.Nombre as Producto_Nombre,
            m.Nombre as Marca_Nombre,
            (dc.Cantidad_Caja * dc.Cantidad_Unitario) as Cantidad_Total,
            dc.Precio_Unitario as Subtotal,
            dc.Precio_Unitario as Costo_Total
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
        Crea nueva compra con generación automática de lotes - CORREGIDO
        
        Args:
            proveedor_id: ID del proveedor
            usuario_id: ID del usuario comprador
            items_compra: Lista de items [{'codigo': str, 'cantidad_caja': int, 'cantidad_unitario': int, 
                                        'precio_unitario': float, 'fecha_vencimiento': str}]
                          IMPORTANTE: precio_unitario es el COSTO TOTAL del producto, no por unidad
        
        Returns:
            Información completa de la compra creada
        """
        validate_required(proveedor_id, "proveedor_id")
        validate_required(usuario_id, "usuario_id")
        validate_required(items_compra, "items_compra")
        
        if not items_compra:
            raise CompraError("No se proporcionaron items para la compra")
        
        print(f"🛒 INICIANDO COMPRA - Proveedor: {proveedor_id}, Items: {len(items_compra)}")
        
        compra_id = None
        lotes_creados = []
        
        try:
            # ===== FASE 1: VALIDAR Y PREPARAR ITEMS =====
            items_preparados = []
            total_compra = Decimal('0.00')
            
            print(f"📋 Validando {len(items_compra)} items...")
            for i, item in enumerate(items_compra):
                try:
                    item_preparado = self._validar_y_preparar_item(item)
                    items_preparados.append(item_preparado)
                    # CORREGIDO: No multiplicar, precio_unitario YA es el costo total
                    total_compra += Decimal(str(item_preparado['precio_unitario']))
                    print(f"  ✅ Item {i+1}: {item_preparado['codigo']} - ${item_preparado['precio_unitario']}")
                except Exception as e:
                    raise CompraError(f"Error en item {i+1} ({item.get('codigo', 'sin código')}): {str(e)}")
            
            print(f"💰 Total calculado: ${total_compra}")
            
            # ===== FASE 2: CREAR COMPRA PRINCIPAL =====
            compra_data = {
                'Id_Proveedor': proveedor_id,
                'Id_Usuario': usuario_id,
                'Fecha': datetime.now(),
                'Total': float(total_compra)
            }
            
            print(f"📝 Creando compra principal...")
            compra_id = self.insert(compra_data)
            
            if not compra_id or compra_id <= 0:
                raise CompraError("❌ FALLO CRÍTICO: No se pudo crear la compra principal")
            
            print(f"✅ Compra principal creada - ID: {compra_id}")
            
            # ===== FASE 3: PROCESAR ITEMS CON ROLLBACK AUTOMÁTICO =====
            print(f"🔄 Procesando {len(items_preparados)} items...")
            
            for i, item in enumerate(items_preparados):
                try:
                    print(f"  📦 Procesando item {i+1}/{len(items_preparados)}: {item['codigo']}")
                    lote_info = self._procesar_item_con_lote(compra_id, item)
                    lotes_creados.append(lote_info)
                    print(f"  ✅ Item {i+1} procesado - Lote: {lote_info['lote_id']}")
                    
                except Exception as item_error:
                    print(f"  ❌ ERROR en item {i+1} ({item['codigo']}): {str(item_error)}")
                    # ROLLBACK AUTOMÁTICO si falla cualquier item
                    self._rollback_compra_completa(compra_id, lotes_creados)
                    raise CompraError(f"Error procesando item {item['codigo']}: {str(item_error)}")
            
            # ===== FASE 4: VERIFICAR INTEGRIDAD FINAL =====
            if len(lotes_creados) != len(items_preparados):
                print(f"❌ ERROR DE INTEGRIDAD: Items esperados: {len(items_preparados)}, Lotes creados: {len(lotes_creados)}")
                self._rollback_compra_completa(compra_id, lotes_creados)
                raise CompraError("Error de integridad: No todos los items se procesaron correctamente")
            
            # ===== FASE 5: OBTENER RESULTADO FINAL =====
            try:
                compra_completa = self.get_compra_completa(compra_id)
                
                if not compra_completa:
                    raise CompraError("Error obteniendo datos completos de la compra")
                
                print(f"🎉 COMPRA COMPLETADA EXITOSAMENTE")
                print(f"   ID: {compra_id}")
                print(f"   Total: ${total_compra}")
                print(f"   Items: {len(lotes_creados)}")
                print(f"   Lotes creados: {[l['lote_id'] for l in lotes_creados]}")
                
                return compra_completa
                
            except Exception as final_error:
                print(f"❌ ERROR obteniendo compra completa: {str(final_error)}")
                # No hacer rollback aquí porque la compra ya está creada correctamente
                # Solo loggear el error y retornar datos básicos
                return {
                    'id': compra_id,
                    'Total': float(total_compra),
                    'detalles': lotes_creados,
                    'error_detalle': str(final_error)
                }
        
        except Exception as e:
            print(f"❌ ERROR GENERAL EN CREAR_COMPRA: {str(e)}")
            
            # ROLLBACK COMPLETO si estamos en medio del proceso
            if compra_id:
                self._rollback_compra_completa(compra_id, lotes_creados)
            
            # Re-lanzar excepción para que el modelo la maneje
            raise CompraError(f"Error creando compra: {str(e)}")
    
    @ExceptionHandler.handle_exception
    def eliminar_compra_completa(self, compra_id: int) -> bool:
        """
        Elimina compra completa revirtiendo stock automáticamente
        
        Returns:
            True si se eliminó correctamente
        """
        validate_required(compra_id, "compra_id")
        
        print(f"🗑️ INICIANDO ELIMINACIÓN - Compra: {compra_id}")
        
        # 1. Obtener compra completa antes de eliminar
        try:
            compra = self.get_compra_completa(compra_id)
            if not compra:
                raise CompraError(f"Compra {compra_id} no encontrada")
            
            print(f"📋 Compra a eliminar: {compra['Proveedor_Nombre']} - ${compra['Total']}")
            
        except Exception as e:
            raise CompraError(f"Error obteniendo datos de compra: {str(e)}")
        
        # 2. Revertir stock por cada detalle
        stock_revertido = []
        try:
            for detalle in compra.get('detalles', []):
                # Obtener info del lote
                lote_query = "SELECT * FROM Lote WHERE id = ?"
                lote = self._execute_query(lote_query, (detalle['Id_Lote'],), fetch_one=True)
                
                if lote:
                    # Revertir stock del producto
                    producto_id = lote['Id_Producto']
                    cantidad_caja = lote['Cantidad_Caja']
                    cantidad_unitario = lote['Cantidad_Unitario']
                    
                    # Reducir stock del producto
                    reducir_stock_query = """
                    UPDATE Productos 
                    SET Stock_Caja = Stock_Caja - ?, Stock_Unitario = Stock_Unitario - ?
                    WHERE id = ?
                    """
                    self._execute_query(reducir_stock_query, (cantidad_caja, cantidad_unitario, producto_id), fetch_all=False, use_cache=False)
                    
                    stock_revertido.append({
                        'producto_id': producto_id,
                        'codigo': detalle.get('Producto_Codigo', ''),
                        'cantidad_caja': cantidad_caja,
                        'cantidad_unitario': cantidad_unitario
                    })
                    
                    print(f"  📦 Stock revertido - {detalle.get('Producto_Codigo', '')}: -{cantidad_caja}c/{cantidad_unitario}u")
            
        except Exception as e:
            print(f"❌ Error revirtiendo stock: {str(e)}")
            raise CompraError(f"Error revirtiendo stock: {str(e)}")
        
        # 3. Eliminar en orden correcto
        try:
            # 3.1 Eliminar detalles de compra
            delete_detalles_query = "DELETE FROM DetalleCompra WHERE Id_Compra = ?"
            detalles_eliminados = self._execute_query(delete_detalles_query, (compra_id,), fetch_all=False, use_cache=False)
            
            # 3.2 Eliminar lotes asociados
            lotes_eliminados = 0
            for detalle in compra.get('detalles', []):
                delete_lote_query = "DELETE FROM Lote WHERE id = ?"
                resultado = self._execute_query(delete_lote_query, (detalle['Id_Lote'],), fetch_all=False, use_cache=False)
                if resultado > 0:
                    lotes_eliminados += 1
            
            # 3.3 Eliminar compra principal
            delete_compra_query = "DELETE FROM Compra WHERE id = ?"
            compra_eliminada = self._execute_query(delete_compra_query, (compra_id,), fetch_all=False, use_cache=False)
            
            if compra_eliminada > 0:
                print(f"✅ ELIMINACIÓN EXITOSA:")
                print(f"   Compra: {compra_id}")
                print(f"   Detalles: {detalles_eliminados}")
                print(f"   Lotes: {lotes_eliminados}")
                print(f"   Productos afectados: {len(stock_revertido)}")
                return True
            else:
                raise CompraError("No se pudo eliminar la compra principal")
                
        except Exception as e:
            print(f"❌ ERROR ELIMINANDO: {str(e)}")
            raise CompraError(f"Error eliminando compra: {str(e)}")
    
    def _rollback_compra_completa(self, compra_id: int, lotes_creados: List[Dict[str, Any]]):
        """
        Rollback completo: elimina compra, lotes y restaura stocks
        """
        print(f"🔄 EJECUTANDO ROLLBACK COMPLETO - Compra: {compra_id}")
        
        try:
            # 1. Eliminar detalles de compra
            delete_detalles_query = "DELETE FROM DetalleCompra WHERE Id_Compra = ?"
            self._execute_query(delete_detalles_query, (compra_id,), fetch_all=False, use_cache=False)
            print(f"  ✅ Detalles de compra eliminados")
            
            # 2. Eliminar lotes y restaurar stocks
            for lote_info in lotes_creados:
                try:
                    lote_id = lote_info.get('lote_id')
                    if lote_id:
                        # Obtener info del lote antes de eliminarlo
                        lote_query = "SELECT * FROM Lote WHERE id = ?"
                        lote = self._execute_query(lote_query, (lote_id,), fetch_one=True)
                        
                        if lote:
                            # Eliminar lote
                            delete_lote_query = "DELETE FROM Lote WHERE id = ?"
                            self._execute_query(delete_lote_query, (lote_id,), fetch_all=False, use_cache=False)
                            
                            # Restaurar stock del producto
                            self._restaurar_stock_producto(lote['Id_Producto'], lote['Cantidad_Caja'], lote['Cantidad_Unitario'])
                            
                            print(f"  ✅ Lote {lote_id} eliminado y stock restaurado")
                            
                except Exception as lote_error:
                    print(f"  ❌ Error eliminando lote {lote_info.get('lote_id', 'N/A')}: {str(lote_error)}")
            
            # 3. Eliminar compra principal
            delete_compra_query = "DELETE FROM Compra WHERE id = ?"
            self._execute_query(delete_compra_query, (compra_id,), fetch_all=False, use_cache=False)
            print(f"  ✅ Compra {compra_id} eliminada")
            
            print(f"🎯 ROLLBACK COMPLETADO - Compra {compra_id} y todos sus datos eliminados")
            
        except Exception as rollback_error:
            print(f"❌ ERROR CRÍTICO EN ROLLBACK: {str(rollback_error)}")
            print(f"⚠️  DATOS INCONSISTENTES - Compra: {compra_id}, revisar manualmente")
    
    def get_productos_resumen_compra(self, compra_id: int) -> List[Dict[str, Any]]:
        """Obtiene lista simplificada de productos de una compra para mostrar en tabla principal"""
        validate_required(compra_id, "compra_id")
        
        query = """
        SELECT DISTINCT
            p.Codigo as Producto_Codigo,
            p.Nombre as Producto_Nombre,
            m.Nombre as Marca_Nombre,
            COUNT(dc.id) as Items_Compra,
            SUM(dc.Cantidad_Caja * dc.Cantidad_Unitario) as Total_Unidades
        FROM DetalleCompra dc
        INNER JOIN Lote l ON dc.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        LEFT JOIN Marca m ON p.ID_Marca = m.id
        WHERE dc.Id_Compra = ?
        GROUP BY p.id, p.Codigo, p.Nombre, m.Nombre
        ORDER BY p.Nombre
        """
        
        return self._execute_query(query, (compra_id,))
    
    def _restaurar_stock_producto(self, producto_id: int, cantidad_caja: int, cantidad_unitario: int):
        """
        Restaura stock de un producto específico
        """
        try:
            producto = self.producto_repo.get_by_id(producto_id)
            if producto:
                nuevo_stock_caja = max(0, producto['Stock_Caja'] - cantidad_caja)
                nuevo_stock_unitario = max(0, producto['Stock_Unitario'] - cantidad_unitario)
                
                restore_query = """
                UPDATE Productos 
                SET Stock_Caja = ?, Stock_Unitario = ?
                WHERE id = ?
                """
                self._execute_query(restore_query, (nuevo_stock_caja, nuevo_stock_unitario, producto_id), fetch_all=False, use_cache=False)
                
        except Exception as e:
            print(f"❌ Error restaurando stock producto {producto_id}: {str(e)}")

    def _validar_y_preparar_item(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """Valida y prepara un item para la compra - CORREGIDO FECHAS"""
        # Validaciones básicas
        codigo = item.get('codigo', '').strip()
        cantidad_caja = item.get('cantidad_caja', 0)
        cantidad_unitario = item.get('cantidad_unitario', 0)
        precio_unitario = item.get('precio_unitario', 0)
        fecha_vencimiento = item.get('fecha_vencimiento', '').strip()
        
        validate_required(codigo, "codigo")
        validate_positive_number(precio_unitario, "precio_unitario")
        
        if cantidad_caja <= 0 and cantidad_unitario <= 0:
            raise ValidationError("cantidad", f"{cantidad_caja}/{cantidad_unitario}", 
                                "Debe especificar cantidad de cajas o unitarios")
        
        # VALIDACIÓN DE FECHA CORREGIDA
        fecha_vencimiento_bd = None
        if fecha_vencimiento and fecha_vencimiento.lower() not in ["sin vencimiento", ""]:
            # Validar formato YYYY-MM-DD
            try:
                datetime.strptime(fecha_vencimiento, '%Y-%m-%d')
                fecha_vencimiento_bd = fecha_vencimiento
            except ValueError:
                raise ValidationError("fecha_vencimiento", fecha_vencimiento, 
                                    "Formato debe ser YYYY-MM-DD")
        
        # Obtener producto
        producto = self.producto_repo.get_by_codigo(codigo)
        if not producto:
            raise ProductoNotFoundError(codigo=codigo)
        
        # Calcular totales
        cantidad_total = cantidad_caja * cantidad_unitario
        
        return {
            'codigo': codigo,
            'producto_id': producto['id'],
            'producto_nombre': producto['Nombre'],
            'cantidad_caja': cantidad_caja,
            'cantidad_unitario': cantidad_unitario,
            'cantidad_total': cantidad_total,
            'precio_unitario': precio_unitario,
            'fecha_vencimiento': fecha_vencimiento_bd,  # NULL si está vacío
            'producto': producto
        }
    
    def _procesar_item_con_lote(self, compra_id: int, item: Dict[str, Any]) -> Dict[str, Any]:
        """Procesa un item creando lote y detalle de compra - FECHAS CORREGIDAS"""
        print(f"🔄 Procesando item: {item['codigo']} - Cajas: {item['cantidad_caja']}, Unitarios: {item['cantidad_unitario']}")
        
        # 1. Validar compra_id
        if not compra_id or compra_id <= 0:
            raise CompraError(f"ID de compra inválido: {compra_id}")
        
        # 2. Crear nuevo lote - FECHA CORREGIDA
        try:
            precio_por_unidad = item['precio_unitario'] / item['cantidad_total'] if item['cantidad_total'] > 0 else 0
            
            lote_id = self.producto_repo.aumentar_stock_compra(
                producto_id=item['producto_id'],
                cantidad_caja=item['cantidad_caja'],
                cantidad_unitario=item['cantidad_unitario'],
                fecha_vencimiento=item['fecha_vencimiento'],  # Puede ser None
                precio_compra=precio_por_unidad
            )
            
            if not lote_id or lote_id <= 0:
                raise CompraError(f"❌ FALLO CRÍTICO: No se pudo crear lote para producto {item['codigo']}")
            
            print(f"✅ Lote creado exitosamente - ID: {lote_id} para producto {item['codigo']}")
            
        except Exception as e:
            print(f"❌ ERROR creando lote para {item['codigo']}: {str(e)}")
            raise CompraError(f"Error creando lote para producto {item['codigo']}: {str(e)}")
        
        # 3. Crear detalle de compra - El precio_unitario aquí es el COSTO TOTAL
        try:
            detalle_data = {
                'Id_Compra': compra_id,
                'Id_Lote': lote_id,
                'Cantidad_Caja': item['cantidad_caja'],
                'Cantidad_Unitario': item['cantidad_unitario'],
                'Precio_Unitario': item['precio_unitario']  # COSTO TOTAL del producto
            }
            
            # Usar método insert del BaseRepository para consistencia
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
            
            # VALIDACIÓN DEL RESULTADO
            if not detalle_result or not isinstance(detalle_result, dict) or 'id' not in detalle_result:
                # ROLLBACK: Si falló el detalle, eliminar el lote creado
                print(f"❌ ERROR: Fallo creando DetalleCompra, eliminando lote {lote_id}")
                self._rollback_lote_created(lote_id, item['producto_id'], item['cantidad_caja'], item['cantidad_unitario'])
                raise CompraError(f"Error creando detalle de compra para {item['codigo']}")
            
            detalle_id = detalle_result['id']
            print(f"✅ Detalle creado - ID: {detalle_id}, Lote: {lote_id}, Producto: {item['codigo']}")
            
            return {
                'detalle_id': detalle_id,
                'lote_id': lote_id,
                'producto_codigo': item['codigo'],
                'cantidad_total': item['cantidad_total'],
                'precio_unitario': item['precio_unitario'],  # COSTO TOTAL
                'costo_total': item['precio_unitario']  # COSTO TOTAL
            }
            
        except Exception as e:
            # ROLLBACK: Si algo falló, eliminar el lote creado
            print(f"❌ ERROR en detalle de compra para {item['codigo']}: {str(e)}")
            self._rollback_lote_created(lote_id, item['producto_id'], item['cantidad_caja'], item['cantidad_unitario'])
            raise CompraError(f"Error procesando item {item['codigo']}: {str(e)}")
    
    def _rollback_lote_created(self, lote_id: int, producto_id: int, cantidad_caja: int, cantidad_unitario: int):
        """
        Método de rollback para eliminar lote creado si falla el detalle
        """
        try:
            print(f"🔄 Ejecutando rollback - Lote: {lote_id}, Producto: {producto_id}")
            
            # 1. Eliminar lote
            delete_lote_query = "DELETE FROM Lote WHERE id = ?"
            self._execute_query(delete_lote_query, (lote_id,), fetch_all=False, use_cache=False)
            
            # 2. Restaurar stock del producto
            producto = self.producto_repo.get_by_id(producto_id)
            if producto:
                nuevo_stock_caja = producto['Stock_Caja'] - cantidad_caja
                nuevo_stock_unitario = producto['Stock_Unitario'] - cantidad_unitario
                
                # Evitar stocks negativos
                nuevo_stock_caja = max(0, nuevo_stock_caja)
                nuevo_stock_unitario = max(0, nuevo_stock_unitario)
                
                restore_stock_query = """
                UPDATE Productos 
                SET Stock_Caja = ?, Stock_Unitario = ?
                WHERE id = ?
                """
                self._execute_query(restore_stock_query, (nuevo_stock_caja, nuevo_stock_unitario, producto_id), fetch_all=False, use_cache=False)
                
            print(f"✅ Rollback completado - Lote {lote_id} eliminado, stock restaurado")
            
        except Exception as rollback_error:
            print(f"❌ ERROR EN ROLLBACK: {str(rollback_error)} - Lote: {lote_id}")
    
    # ===============================
    # GESTIÓN DE PROVEEDORES
    # ===============================
    
    def get_proveedores_activos(self) -> List[Dict[str, Any]]:
        """Obtiene TODOS los proveedores (con y sin compras)"""
        query = """
        SELECT p.id, p.Nombre, p.Direccion, 
               COUNT(c.id) as Total_Compras,
               ISNULL(MAX(c.Fecha), NULL) as Ultima_Compra,
               ISNULL(SUM(c.Total), 0) as Monto_Total,
               ISNULL(AVG(c.Total), 0) as Compra_Promedio,
               CASE 
                   WHEN COUNT(c.id) = 0 THEN 'Sin_Compras'
                   WHEN MAX(c.Fecha) >= DATEADD(MONTH, -3, GETDATE()) THEN 'Activo'
                   WHEN MAX(c.Fecha) >= DATEADD(MONTH, -12, GETDATE()) THEN 'Inactivo'
                   ELSE 'Obsoleto'
               END as Estado
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        GROUP BY p.id, p.Nombre, p.Direccion
        ORDER BY p.Nombre ASC
        """
        
        result = self._execute_query(query, use_cache=False)
        
        if result:
            print(f"📋 get_proveedores_activos: {len(result)} proveedores obtenidos")
            for proveedor in result:
                print(f"  - {proveedor.get('Nombre', 'Sin nombre')} (ID: {proveedor.get('id', 'N/A')}, Estado: {proveedor.get('Estado', 'N/A')})")
        else:
            print("⚠️ get_proveedores_activos: No se obtuvieron proveedores")
            
        return result or []
    
    def get_proveedores_for_combo(self) -> List[Dict[str, Any]]:
        """Obtiene proveedores específicamente para ComboBox (solo campos necesarios)"""
        query = """
        SELECT id, Nombre
        FROM Proveedor
        ORDER BY Nombre ASC
        """
        
        result = self._execute_query(query, use_cache=False)
        
        print(f"📋 get_proveedores_for_combo: {len(result) if result else 0} proveedores")
        return result or []
    
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
        """Productos más comprados en período - CORREGIDO"""
        query = f"""
        SELECT TOP {limit}
            p.Codigo,
            p.Nombre as Producto_Nombre,
            m.Nombre as Marca_Nombre,
            SUM(dc.Cantidad_Caja * dc.Cantidad_Unitario) as Cantidad_Comprada,
            COUNT(DISTINCT c.id) as Num_Compras,
            SUM(dc.Precio_Unitario) as Costo_Total,
            AVG(dc.Precio_Unitario / (dc.Cantidad_Caja * dc.Cantidad_Unitario)) as Precio_Promedio_Unitario
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
        """Verifica la integridad de una compra - CORREGIDO"""
        compra = self.get_compra_completa(compra_id)
        
        if not compra:
            return {'valida': False, 'errores': ['Compra no encontrada']}
        
        errores = []
        
        # CORREGIDO: Solo sumar los precios sin multiplicar
        total_calculado = sum(
            detalle['Precio_Unitario']  # Ya es el costo total
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
            elif (lote['Cantidad_Caja'] * lote['Cantidad_Unitario']) <= 0:
                errores.append(f"Lote {detalle['Id_Lote']} sin stock")
        
        return {
            'valida': len(errores) == 0,
            'errores': errores,
            'total_db': compra['Total'],
            'total_calculado': total_calculado
        }
    
    # ===============================
    # MÉTODO ADICIONAL PARA ESTADÍSTICAS DE FILTROS
    # ===============================

    def get_estadisticas_filtros(self, fecha_desde: str = None, fecha_hasta: str = None,
                            proveedor_id: int = None) -> Dict[str, Any]:
        """Obtiene estadísticas de compras filtradas"""
        try:
            where_conditions = []
            params = []
            
            if fecha_desde and fecha_hasta:
                where_conditions.append("c.Fecha BETWEEN ? AND ?")
                params.extend([fecha_desde, fecha_hasta])
            
            if proveedor_id and proveedor_id > 0:
                where_conditions.append("c.Id_Proveedor = ?")
                params.append(proveedor_id)
            
            where_clause = ""
            if where_conditions:
                where_clause = "WHERE " + " AND ".join(where_conditions)
            
            query = f"""
            SELECT 
                COUNT(c.id) as Total_Compras,
                ISNULL(SUM(c.Total), 0) as Monto_Total,
                ISNULL(AVG(c.Total), 0) as Compra_Promedio,
                ISNULL(MIN(c.Total), 0) as Compra_Minima,
                ISNULL(MAX(c.Total), 0) as Compra_Maxima,
                COUNT(DISTINCT c.Id_Proveedor) as Proveedores_Distintos
            FROM Compra c
            {where_clause}
            """
            
            result = self._execute_query(query, tuple(params) if params else (), 
                                    fetch_one=True, use_cache=False)
            
            return result or {
                'Total_Compras': 0,
                'Monto_Total': 0,
                'Compra_Promedio': 0,
                'Compra_Minima': 0,
                'Compra_Maxima': 0,
                'Proveedores_Distintos': 0
            }
            
        except Exception as e:
            print(f"❌ Error estadísticas filtros: {str(e)}")
            return {
                'Total_Compras': 0,
                'Monto_Total': 0,
                'Compra_Promedio': 0,
                'Compra_Minima': 0,
                'Compra_Maxima': 0,
                'Proveedores_Distintos': 0
            }