"""
CompraRepository - VERSIÓN 2.0 SIMPLIFICADA
✅ CAMBIOS:
- Precio TOTAL en lugar de precio unitario (calcula automático)
- Sin cálculos de márgenes ni ganancias
- Soporte para actualizar precio_venta del producto en compras
- Validación de edición de lotes con ventas
"""

from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from decimal import Decimal
import hashlib
import json

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    CompraError, ProductoNotFoundError, ValidationError,
    ExceptionHandler, validate_required, validate_positive_number
)
from .producto_repository import ProductoRepository
from ..core.config_fifo import config_fifo

class CompraRepository(BaseRepository):
    """Repository para compras con creación automática de lotes - VERSIÓN 2.0"""
    
    def __init__(self):
        super().__init__('Compra', 'compras')
        self.producto_repo = ProductoRepository()
        print("🛒 CompraRepository v2.0 inicializado - Sin márgenes, con precio total")
    
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
        """Obtiene compras con filtro de fechas preciso (solo el período solicitado)"""
        where_clause = ""
        params = []
        
        if fecha_desde and fecha_hasta:
            where_clause = """
            WHERE CAST(c.Fecha AS DATE) >= CAST(? AS DATE)
              AND CAST(c.Fecha AS DATE) < CAST(? AS DATE)
            """
            params = [fecha_desde, fecha_hasta]
            print(f"📅 Filtro de compras: {fecha_desde} a {fecha_hasta} (exclusivo)")
        elif fecha_desde:
            where_clause = "WHERE CAST(c.Fecha AS DATE) >= CAST(? AS DATE)"
            params = [fecha_desde]
            print(f"📅 Filtro de compras: desde {fecha_desde}")
        elif fecha_hasta:
            where_clause = "WHERE CAST(c.Fecha AS DATE) < CAST(? AS DATE)"
            params = [fecha_hasta]
            print(f"📅 Filtro de compras: hasta {fecha_hasta} (exclusivo)")
        else:
            print("⚠️ Sin filtro de fechas - retornando TODAS las compras")
        
        query = f"""
        SELECT 
            c.id as Compra_ID,
            c.Fecha,
            c.Total as Compra_Total,
            p.Nombre as Proveedor,
            p.Direccion as Proveedor_Direccion,
            u.Nombre + ' ' + u.Apellido_Paterno as Usuario,
            COUNT(dc.id) as Items_Comprados,
            SUM(dc.Cantidad_Unitario) as Unidades_Totales
        FROM Compra c
        INNER JOIN Proveedor p ON c.Id_Proveedor = p.id
        INNER JOIN Usuario u ON c.Id_Usuario = u.id
        LEFT JOIN DetalleCompra dc ON c.id = dc.Id_Compra
        {where_clause}
        GROUP BY c.id, c.Fecha, c.Total, p.Nombre, p.Direccion, u.Nombre, u.Apellido_Paterno
        ORDER BY c.Fecha DESC
        """
        
        resultado = self._execute_query(query, tuple(params))
        
        if resultado:
            print(f"✅ Compras filtradas: {len(resultado)} compras encontradas")
            if len(resultado) > 0:
                primera_fecha = resultado[0].get('Fecha', '')
                ultima_fecha = resultado[-1].get('Fecha', '')
                print(f"   📅 Rango real: {ultima_fecha} a {primera_fecha}")
        else:
            print(f"⚠️ No se encontraron compras en el período")
        
        return resultado
    
    def get_compra_completa(self, compra_id: int) -> Dict[str, Any]:
        """
        Obtiene compra con todos sus detalles
        ✅ VERSIÓN 2.0: Sin cálculos de márgenes ni ganancias
        """
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
        
        # Detalles de la compra - SIN MÁRGENES
        detalles_query = """
            SELECT 
                dc.*,
                l.Fecha_Vencimiento,
                p.Codigo as Producto_Codigo,
                p.Nombre as Producto_Nombre,
                m.Nombre as Marca_Nombre,
                dc.Cantidad_Unitario as Cantidad_Total,
                
                -- Precio unitario de compra
                dc.Precio_Unitario as Precio_Unitario_Compra,
                
                -- Costo total del producto (cantidad × precio unitario)
                (dc.Cantidad_Unitario * dc.Precio_Unitario) as Subtotal,
                (dc.Cantidad_Unitario * dc.Precio_Unitario) as Costo_Total,
                
                -- Precio de venta actual del producto
                p.Precio_venta as Precio_Venta_Actual
                
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
    # CREACIÓN DE COMPRAS CON LOTES - VERSIÓN 2.0
    # ===============================
    
    def _validar_y_preparar_item(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """
        ✅ VERSIÓN 2.0: Validar y preparar item con PRECIO TOTAL
        
        Args:
            item: {
                'codigo': str,
                'cantidad_unitario': int,
                'precio_total': float,  # ← NUEVO: Total por todo el producto
                'precio_venta': float,  # ← NUEVO: Precio de venta a actualizar (opcional)
                'fecha_vencimiento': str (opcional)
            }
        
        Returns:
            Item preparado con precio_unitario calculado
        """
        # Validar campos requeridos
        validate_required(item.get('codigo'), 'codigo')
        validate_required(item.get('cantidad_unitario'), 'cantidad_unitario')
        validate_required(item.get('precio_total'), 'precio_total')
        
        codigo = str(item['codigo']).strip().upper()
        cantidad = int(item['cantidad_unitario'])
        precio_total = float(item['precio_total'])
        
        # Validar valores positivos
        if cantidad <= 0:
            raise ValidationError("Cantidad debe ser mayor a 0")
        
        if precio_total <= 0:
            raise ValidationError("Precio total debe ser mayor a 0")
        
        # ✅ CALCULAR precio unitario automáticamente
        precio_unitario = Decimal(str(precio_total)) / Decimal(str(cantidad))
        precio_unitario = float(precio_unitario)
        
        print(f"💰 Cálculo automático: Bs{precio_total} ÷ {cantidad} = Bs{precio_unitario:.4f} c/u")
        
        # Verificar que el producto existe
        producto = self.producto_repo.get_by_codigo(codigo)
        if not producto:
            raise ProductoNotFoundError(f"Producto no encontrado: {codigo}", codigo=codigo)
        
        # Preparar fecha de vencimiento
        fecha_venc = item.get('fecha_vencimiento', '').strip()
        fecha_procesada = None
        
        if fecha_venc:
            try:
                if isinstance(fecha_venc, str):
                    if len(fecha_venc) == 10:  # YYYY-MM-DD
                        fecha_dt = datetime.strptime(fecha_venc, '%Y-%m-%d')
                    elif len(fecha_venc) == 19:  # YYYY-MM-DD HH:MM:SS
                        fecha_dt = datetime.strptime(fecha_venc, '%Y-%m-%d %H:%M:%S')
                    else:
                        raise ValueError(f"Formato de fecha inválido: {fecha_venc}")
                    
                    if fecha_dt < datetime.now():
                        raise ValidationError(f"Fecha de vencimiento no puede ser pasada: {fecha_venc}")
                    
                    fecha_procesada = fecha_dt.strftime('%Y-%m-%d')
                    print(f"   📅 Fecha vencimiento guardada: '{fecha_procesada}' - Tipo: {type(fecha_procesada).__name__}")
                    
            except ValueError as e:
                raise ValidationError(f"Fecha de vencimiento inválida: {str(e)}")
        
        # ✅ NUEVO: Precio de venta (opcional)
        precio_venta = item.get('precio_venta')
        if precio_venta is not None:
            precio_venta = float(precio_venta)
            if precio_venta <= 0:
                raise ValidationError("Precio de venta debe ser mayor a 0")
        
        return {
            'codigo': codigo,
            'producto_id': producto['id'],
            'producto_nombre': producto['Nombre'],
            'cantidad_unitario': cantidad,
            'precio_unitario': precio_unitario,  # Calculado automáticamente
            'precio_total': precio_total,  # Guardamos también el total
            'precio_venta': precio_venta,  # Para actualizar Productos.Precio_venta
            'fecha_vencimiento': fecha_procesada
        }
    
    @ExceptionHandler.handle_exception
    def crear_compra(self, proveedor_id: int, usuario_id: int, items_compra: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        ✅ VERSIÓN 2.0: Crea nueva compra con precio TOTAL por item
        
        Args:
            proveedor_id: ID del proveedor
            usuario_id: ID del usuario comprador
            items_compra: Lista de items [
                {
                    'codigo': str, 
                    'cantidad_unitario': int, 
                    'precio_total': float,  # ← NUEVO
                    'precio_venta': float,  # ← NUEVO (opcional)
                    'fecha_vencimiento': str
                }
            ]
        
        Returns:
            Información completa de la compra creada
        """
        validate_required(proveedor_id, "proveedor_id")
        validate_required(usuario_id, "usuario_id")
        validate_required(items_compra, "items_compra")
        
        if not items_compra:
            raise CompraError("No se proporcionaron items para la compra")
        
        print(f"🛒 INICIANDO COMPRA v2.0 - Proveedor: {proveedor_id}, Items: {len(items_compra)}")
        
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
                    
                    # Sumar al total de la compra
                    precio_total_item = Decimal(str(item_preparado['precio_total']))
                    total_compra += precio_total_item
                    
                    print(f"  ✅ Item {i+1}: {item_preparado['codigo']} - {item_preparado['cantidad_unitario']}u × Bs{item_preparado['precio_unitario']:.4f} = Bs{precio_total_item}")
                    
                except Exception as e:
                    raise CompraError(f"Error en item {i+1} ({item.get('codigo', 'sin código')}): {str(e)}")
            
            print(f"💰 Total calculado: Bs{total_compra}")
            
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
                print(f"   Total: Bs{total_compra}")
                print(f"   Items: {len(lotes_creados)}")
                print(f"   Lotes creados: {[l['lote_id'] for l in lotes_creados]}")
                
                return compra_completa
                
            except Exception as final_error:
                print(f"❌ ERROR obteniendo compra completa: {str(final_error)}")
                # No hacer rollback aquí porque la compra ya está creada correctamente
                return {
                    'id': compra_id,
                    'Total': float(total_compra),
                    'detalles': lotes_creados,
                    'error_detalle': str(final_error)
                }
        
        except Exception as e:
            print(f"❌ ERROR CRÍTICO en crear_compra: {str(e)}")
            if compra_id:
                self._rollback_compra_completa(compra_id, lotes_creados)
            raise
    
    def _procesar_item_con_lote(self, compra_id: int, item: Dict[str, Any]) -> Dict[str, Any]:
        """
        ✅ VERSIÓN 2.0: Procesa un item creando su lote y actualizando precio_venta si se proporciona
        
        Args:
            compra_id: ID de la compra
            item: Item preparado con precio_unitario ya calculado
        
        Returns:
            Información del lote creado
        """
        try:
            producto_id = item['producto_id']
            cantidad = item['cantidad_unitario']
            precio_unitario = item['precio_unitario']
            fecha_venc = item['fecha_vencimiento']
            precio_venta = item.get('precio_venta')
            
            # 1. Crear lote
            lote_data = {
                'Id_Producto': producto_id,
                'Id_Compra': compra_id,
                'Cantidad_Inicial': cantidad,
                'Cantidad_Unitario': cantidad,
                'Precio_Compra': precio_unitario,  # Precio unitario calculado
                'Fecha_Vencimiento': fecha_venc if fecha_venc else None
            }
            
            lote_id = self._execute_insert('Lote', lote_data)
            
            if not lote_id or lote_id <= 0:
                raise CompraError(f"Error creando lote para producto {item['codigo']}")
            
            print(f"    ✅ Lote creado - ID: {lote_id}")
            
            # 2. Crear detalle de compra
            detalle_data = {
                'Id_Compra': compra_id,
                'Id_Lote': lote_id,
                'Cantidad_Unitario': cantidad,
                'Precio_Unitario': precio_unitario
            }
            
            detalle_id = self._execute_insert('DetalleCompra', detalle_data)
            
            if not detalle_id:
                raise CompraError(f"Error creando detalle de compra para lote {lote_id}")
            
            print(f"    ✅ Detalle de compra creado - ID: {detalle_id}")
            
            # ✅ 3. ACTUALIZAR precio_venta del producto si se proporcionó
            if precio_venta is not None:
                try:
                    update_query = """
                    UPDATE Productos 
                    SET Precio_venta = ?
                    WHERE id = ?
                    """
                    self._execute_query(update_query, (precio_venta, producto_id), fetch_one=False)
                    print(f"    💵 Precio venta actualizado: Bs{precio_venta}")
                except Exception as e:
                    print(f"    ⚠️ No se pudo actualizar precio venta: {e}")
                    # No es crítico, continuar
            
            return {
                'lote_id': lote_id,
                'detalle_id': detalle_id,
                'producto_id': producto_id,
                'codigo': item['codigo'],
                'cantidad': cantidad,
                'precio_unitario': precio_unitario
            }
            
        except Exception as e:
            print(f"❌ Error procesando item con lote: {str(e)}")
            raise CompraError(f"Error en _procesar_item_con_lote: {str(e)}")
    
    def _rollback_compra_completa(self, compra_id: int, lotes_creados: List[Dict[str, Any]]):
        """Rollback completo: elimina compra, lotes y detalles"""
        try:
            print(f"🔄 INICIANDO ROLLBACK de compra {compra_id}...")
            
            # 1. Eliminar detalles de compra
            for lote_info in lotes_creados:
                try:
                    detalle_id = lote_info.get('detalle_id')
                    if detalle_id:
                        delete_detalle = "DELETE FROM DetalleCompra WHERE id = ?"
                        self._execute_query(delete_detalle, (detalle_id,), fetch_one=False)
                        print(f"  ✅ Detalle {detalle_id} eliminado")
                except Exception as e:
                    print(f"  ⚠️ Error eliminando detalle: {e}")
            
            # 2. Eliminar lotes
            for lote_info in lotes_creados:
                try:
                    lote_id = lote_info.get('lote_id')
                    if lote_id:
                        delete_lote = "DELETE FROM Lote WHERE id = ?"
                        self._execute_query(delete_lote, (lote_id,), fetch_one=False)
                        print(f"  ✅ Lote {lote_id} eliminado")
                except Exception as e:
                    print(f"  ⚠️ Error eliminando lote: {e}")
            
            # 3. Eliminar compra principal
            try:
                delete_compra = "DELETE FROM Compra WHERE id = ?"
                self._execute_query(delete_compra, (compra_id,), fetch_one=False)
                print(f"  ✅ Compra {compra_id} eliminada")
            except Exception as e:
                print(f"  ⚠️ Error eliminando compra: {e}")
            
            print(f"✅ ROLLBACK COMPLETADO")
            
        except Exception as e:
            print(f"❌ ERROR CRÍTICO EN ROLLBACK: {str(e)}")
            # En este punto, puede haber inconsistencias en BD
            raise CompraError(f"Error en rollback: {str(e)}")
    
    # ===============================
    # EDICIÓN DE COMPRAS - CON VALIDACIONES
    # ===============================
    
    def validar_lote_editable(self, lote_id: int) -> Tuple[bool, str]:
        """
        Valida si un lote puede ser editado
        
        Returns:
            (es_editable, mensaje_error)
        """
        try:
            # Obtener información del lote
            query = """
            SELECT 
                l.Cantidad_Inicial,
                l.Cantidad_Unitario,
                ISNULL((SELECT COUNT(*) FROM DetallesVentas WHERE Id_Lote = l.id), 0) as Ventas_Count
            FROM Lote l
            WHERE l.id = ?
            """
            
            lote = self._execute_query(query, (lote_id,), fetch_one=True)
            
            if not lote:
                return False, "Lote no encontrado"
            
            cantidad_inicial = lote.get('Cantidad_Inicial', 0)
            cantidad_actual = lote.get('Cantidad_Unitario', 0)
            ventas_count = lote.get('Ventas_Count', 0)
            
            # Si ya hubo ventas (cantidad inicial != cantidad actual)
            if cantidad_inicial != cantidad_actual:
                return False, f"No se puede editar: el lote ya tiene ventas ({cantidad_inicial - cantidad_actual} unidades vendidas)"
            
            # Si hay registros en DetallesVentas
            if ventas_count > 0:
                return False, f"No se puede editar: el lote tiene {ventas_count} registros de ventas"
            
            return True, ""
            
        except Exception as e:
            print(f"❌ Error validando lote: {e}")
            return False, f"Error en validación: {str(e)}"
    
    def editar_lote(self, lote_id: int, cantidad: int = None, precio_total: float = None, 
                   fecha_vencimiento: str = None) -> bool:
        """
        ✅ VERSIÓN 2.0: Edita un lote con validaciones
        
        Args:
            lote_id: ID del lote
            cantidad: Nueva cantidad (opcional)
            precio_total: Nuevo precio TOTAL (calcula unitario automáticamente)
            fecha_vencimiento: Nueva fecha de vencimiento (opcional)
        
        Returns:
            True si se editó correctamente
        """
        # Validar que el lote sea editable
        es_editable, mensaje_error = self.validar_lote_editable(lote_id)
        
        if not es_editable:
            raise CompraError(mensaje_error)
        
        try:
            # Obtener lote actual
            lote_actual = self._execute_query(
                "SELECT * FROM Lote WHERE id = ?", 
                (lote_id,), 
                fetch_one=True
            )
            
            if not lote_actual:
                raise CompraError(f"Lote {lote_id} no encontrado")
            
            # Preparar datos para actualizar
            datos_actualizar = {}
            
            # Cantidad
            if cantidad is not None:
                if cantidad <= 0:
                    raise ValidationError("Cantidad debe ser mayor a 0")
                datos_actualizar['Cantidad_Inicial'] = cantidad
                datos_actualizar['Cantidad_Unitario'] = cantidad
            
            # Precio (con cantidad para calcular unitario)
            if precio_total is not None:
                if precio_total <= 0:
                    raise ValidationError("Precio total debe ser mayor a 0")
                
                cantidad_final = cantidad if cantidad is not None else lote_actual['Cantidad_Unitario']
                precio_unitario = Decimal(str(precio_total)) / Decimal(str(cantidad_final))
                datos_actualizar['Precio_Compra'] = float(precio_unitario)
                
                print(f"💰 Nuevo precio: Bs{precio_total} ÷ {cantidad_final} = Bs{precio_unitario:.4f} c/u")
            
            # Fecha de vencimiento
            if fecha_vencimiento is not None:
                if fecha_vencimiento.strip():
                    try:
                        fecha_dt = datetime.strptime(fecha_vencimiento.strip(), '%Y-%m-%d')
                        datos_actualizar['Fecha_Vencimiento'] = fecha_dt
                    except ValueError:
                        raise ValidationError(f"Fecha inválida: {fecha_vencimiento}")
                else:
                    datos_actualizar['Fecha_Vencimiento'] = None
            
            if not datos_actualizar:
                print("⚠️ No hay cambios para aplicar")
                return True
            
            # Actualizar lote
            self.update(lote_id, datos_actualizar, table_name='Lote')
            
            # Actualizar DetalleCompra si cambió cantidad o precio
            if 'Cantidad_Unitario' in datos_actualizar or 'Precio_Compra' in datos_actualizar:
                detalle_update = "UPDATE DetalleCompra SET "
                updates = []
                params = []
                
                if 'Cantidad_Unitario' in datos_actualizar:
                    updates.append("Cantidad_Unitario = ?")
                    params.append(datos_actualizar['Cantidad_Unitario'])
                
                if 'Precio_Compra' in datos_actualizar:
                    updates.append("Precio_Unitario = ?")
                    params.append(datos_actualizar['Precio_Compra'])
                
                detalle_update += ", ".join(updates) + " WHERE Id_Lote = ?"
                params.append(lote_id)
                
                self._execute_query(detalle_update, tuple(params), fetch_one=False)
                print(f"✅ DetalleCompra actualizado para lote {lote_id}")
            
            print(f"✅ Lote {lote_id} editado correctamente")
            return True
            
        except Exception as e:
            print(f"❌ Error editando lote: {e}")
            raise CompraError(f"Error editando lote: {str(e)}")
    
    # ===============================
    # ESTADÍSTICAS Y REPORTES
    # ===============================
    
    def get_estadisticas_mes(self) -> Dict[str, Any]:
        """Obtiene estadísticas del mes actual"""
        query = """
        SELECT 
            COUNT(*) as Total_Compras,
            ISNULL(SUM(Total), 0) as Gastos_Total,
            ISNULL(AVG(Total), 0) as Compra_Promedio,
            ISNULL(MAX(Total), 0) as Compra_Mayor
        FROM Compra
        WHERE MONTH(Fecha) = MONTH(GETDATE()) AND YEAR(Fecha) = YEAR(GETDATE())
        """
        return self._execute_query(query, fetch_one=True) or {}
    
    def get_top_productos_comprados(self, limite: int = 10) -> List[Dict[str, Any]]:
        """Obtiene los productos más comprados"""
        query = """
        SELECT TOP (?) 
            p.Codigo,
            p.Nombre,
            COUNT(DISTINCT c.id) as Veces_Comprado,
            SUM(dc.Cantidad_Unitario) as Total_Unidades,
            SUM(dc.Cantidad_Unitario * dc.Precio_Unitario) as Gasto_Total
        FROM DetalleCompra dc
        INNER JOIN Lote l ON dc.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        INNER JOIN Compra c ON dc.Id_Compra = c.id
        GROUP BY p.id, p.Codigo, p.Nombre
        ORDER BY Total_Unidades DESC
        """
        return self._execute_query(query, (limite,))