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
        """✅ CORREGIDO: Obtiene compras con filtro de fechas preciso (solo el período solicitado)"""
        where_clause = ""
        params = []
        
        if fecha_desde and fecha_hasta:
            # ✅ CORRECCIÓN: Usar >= y < en lugar de BETWEEN
            # Esto asegura que solo se incluyan fechas del período exacto
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
        
        # ✅ Log de verificación
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
        """Obtiene compra con todos sus detalles - CORREGIDO SIN CAJAS"""
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
        
        # Detalles de la compra - CORREGIDO SIN CAJAS
        detalles_query = """
            SELECT 
                dc.*,
                l.Fecha_Vencimiento,
                p.Codigo as Producto_Codigo,
                p.Nombre as Producto_Nombre,
                m.Nombre as Marca_Nombre,
                dc.Cantidad_Unitario as Cantidad_Total,
                
                -- ✅ NUEVO: Precio unitario de compra
                dc.Precio_Unitario as Precio_Unitario_Compra,
                
                -- Costo total del producto
                dc.Precio_Unitario as Subtotal,
                dc.Precio_Unitario as Costo_Total,
                
                -- ✅ NUEVO: Precio de venta actual del producto
                p.Precio_venta as Precio_Venta_Actual,
                
                -- ✅ NUEVO: Calcular margen de ganancia
                CASE 
                    WHEN p.Precio_venta IS NOT NULL AND dc.Precio_Unitario > 0
                    THEN ((p.Precio_venta - dc.Precio_Unitario) / dc.Precio_Unitario) * 100
                    ELSE 0
                END AS Margen_Porcentaje,
                
                -- ✅ NUEVO: Ganancia unitaria
                CASE 
                    WHEN p.Precio_venta IS NOT NULL
                    THEN (p.Precio_venta - dc.Precio_Unitario)
                    ELSE 0
                END AS Ganancia_Unitaria
                
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
            items_compra: Lista de items [{'codigo': str, 'cantidad_unitario': int, 
                            'precio_unitario': float, 'fecha_vencimiento': str}]
        
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
                    
                    # ✅ CORREGIDO: Calcular costo total = precio_unitario × cantidad
                    precio_unit = Decimal(str(item_preparado['precio_unitario']))
                    cantidad = Decimal(str(item_preparado['cantidad_unitario']))
                    costo_total_item = precio_unit * cantidad
                    total_compra += costo_total_item
                    
                    print(f"  ✅ Item {i+1}: {item_preparado['codigo']} - {cantidad}u × Bs{precio_unit} = Bs{costo_total_item}")
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
        Elimina compra completa revirtiendo stock automáticamente - SIN CAJAS
        
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
        
        # 2. Revertir stock por cada detalle - SIN CAJAS
        stock_revertido = []
        try:
            for detalle in compra.get('detalles', []):
                # Obtener info del lote
                lote_query = "SELECT * FROM Lote WHERE id = ?"
                lote = self._execute_query(lote_query, (detalle['Id_Lote'],), fetch_one=True)
                
                if lote:
                    # Revertir stock del producto - SOLO UNITARIOS
                    producto_id = lote['Id_Producto']
                    cantidad_unitario = lote['Cantidad_Unitario']
                    
                    stock_revertido.append({
                        'producto_id': producto_id,
                        'codigo': detalle.get('Producto_Codigo', ''),
                        'cantidad_unitario': cantidad_unitario
                    })
                    
                    print(f"  📦 Stock revertido - {detalle.get('Producto_Codigo', '')}: -{cantidad_unitario}u")
            
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
        Rollback completo: elimina compra y lotes - CORREGIDO
        """
        print(f"🔄 EJECUTANDO ROLLBACK COMPLETO - Compra: {compra_id}")
        
        try:
            # 1. Eliminar detalles de compra
            delete_detalles_query = "DELETE FROM DetalleCompra WHERE Id_Compra = ?"
            self._execute_query(delete_detalles_query, (compra_id,), fetch_all=False, use_cache=False)
            print(f"  ✅ Detalles de compra eliminados")
            
            # 2. Eliminar lotes SOLAMENTE (sin restaurar stock manual)
            for lote_info in lotes_creados:
                try:
                    lote_id = lote_info.get('lote_id')
                    if lote_id:
                        # Solo eliminar lote - el stock se calcula automáticamente
                        delete_lote_query = "DELETE FROM Lote WHERE id = ?"
                        self._execute_query(delete_lote_query, (lote_id,), fetch_all=False, use_cache=False)
                        print(f"  ✅ Lote {lote_id} eliminado")
                        
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
            SUM(dc.Cantidad_Unitario) as Total_Unidades
        FROM DetalleCompra dc
        INNER JOIN Lote l ON dc.Id_Lote = l.id
        INNER JOIN Productos p ON l.Id_Producto = p.id
        LEFT JOIN Marca m ON p.ID_Marca = m.id
        WHERE dc.Id_Compra = ?
        GROUP BY p.id, p.Codigo, p.Nombre, m.Nombre
        ORDER BY p.Nombre
        """
        
        return self._execute_query(query, (compra_id,))

    def _validar_y_preparar_item(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """
        Valida y prepara un item para la compra - SIMPLIFICADO SOLO UNIDADES
        
        Args:
            item: Diccionario con datos del item desde QML
            
        Returns:
            Diccionario con item validado y preparado
            
        Raises:
            ValidationError: Si hay errores de validación
            ProductoNotFoundError: Si el producto no existe
        """
        # Validaciones básicas
        codigo = item.get('codigo', '').strip() if item.get('codigo') else ''
        cantidad_unitario = item.get('cantidad_unitario', 0)
        precio_unitario = item.get('precio_unitario', 0)
        fecha_vencimiento = item.get('fecha_vencimiento')  # Puede ser None, "", o string
        
        validate_required(codigo, "codigo")
        validate_positive_number(precio_unitario, "precio_unitario")
        
        if cantidad_unitario <= 0:
            raise ValueError(f"Cantidad unitaria debe ser mayor a 0 (recibido: {cantidad_unitario})")

        # VALIDACIÓN DE FECHA CORREGIDA - MANEJO SEGURO DE None Y STRINGS
        fecha_vencimiento_bd = None
        
        print(f"🔍 Validando fecha vencimiento para {codigo}: '{fecha_vencimiento}' (tipo: {type(fecha_vencimiento)})")
        
        # Manejo defensivo de fechas de vencimiento
        if fecha_vencimiento is not None and isinstance(fecha_vencimiento, str):
            fecha_clean = fecha_vencimiento.strip()
            print(f"🔍 Fecha después de strip: '{fecha_clean}'")
            
            if fecha_clean and fecha_clean.lower() not in ["sin vencimiento", "", "none", "null"]:
                # Validar formato YYYY-MM-DD
                try:
                    datetime.strptime(fecha_clean, '%Y-%m-%d')
                    fecha_vencimiento_bd = fecha_clean
                    print(f"✅ Fecha válida establecida: {fecha_vencimiento_bd}")
                except ValueError:
                    raise ValueError(f"Fecha vencimiento debe tener formato YYYY-MM-DD (recibido: '{fecha_clean}')")
            else:
                print(f"📅 Producto sin vencimiento (fecha vacía o especial)")
        else:
            print(f"📅 Producto sin vencimiento (fecha None o no string)")
        
        # Obtener producto
        try:
            producto = self.producto_repo.get_by_codigo(codigo)
            if not producto:
                raise ProductoNotFoundError(codigo=codigo)
            
            print(f"✅ Producto encontrado: {codigo} - {producto.get('Nombre', 'N/A')}")
            
        except Exception as e:
            print(f"❌ Error obteniendo producto {codigo}: {str(e)}")
            raise ProductoNotFoundError(codigo=codigo)
        
        # Calcular totales - SIMPLIFICADO
        cantidad_total = cantidad_unitario
        
        # Preparar item validado - SIN CANTIDAD_CAJA
        item_preparado = {
            'codigo': codigo,
            'producto_id': producto['id'],
            'producto_nombre': producto['Nombre'],
            'cantidad_unitario': cantidad_unitario,
            'cantidad_total': cantidad_total,
            'precio_unitario': precio_unitario,  # ✅ PRECIO POR UNIDAD de compra
            'fecha_vencimiento': fecha_vencimiento_bd,  # None o fecha válida
            'producto': producto,
            'sin_vencimiento': fecha_vencimiento_bd is None
        }
        
        print(f"✅ Item preparado - {codigo}: stock={cantidad_total}, precio=${precio_unitario}, vencimiento={fecha_vencimiento_bd or 'Sin vencimiento'}")
        
        return item_preparado
    def _procesar_item_con_lote(self, compra_id: int, item: Dict[str, Any]) -> Dict[str, Any]:
        """
        Procesa un item creando lote y detalle de compra - SIMPLIFICADO SOLO UNIDADES
        
        Args:
            compra_id: ID de la compra
            item: Diccionario con datos del item preparado
            
        Returns:
            Diccionario con información del item procesado
            
        Raises:
            CompraError: Si hay errores en el procesamiento
        """
        print(f"🔄 Procesando item: {item['codigo']} - Unitarios: {item['cantidad_unitario']}")
        
        # 1. Validar compra_id
        if not compra_id or compra_id <= 0:
            raise CompraError(f"ID de compra inválido: {compra_id}")
        
        # 2. Manejar fecha de vencimiento de forma segura
        fecha_venc_final = None
        fecha_venc_item = item.get('fecha_vencimiento')
        
        # Manejo defensivo de fechas de vencimiento
        if fecha_venc_item is not None and isinstance(fecha_venc_item, str):
            fecha_clean = fecha_venc_item.strip()
            if fecha_clean and fecha_clean.lower() not in ["sin vencimiento", "", "none", "null"]:
                fecha_venc_final = fecha_clean
                print(f"📅 Fecha vencimiento establecida: {fecha_venc_final}")
            else:
                print(f"📅 Producto sin vencimiento (fecha vacía o especial)")
        else:
            print(f"📅 Producto sin vencimiento (fecha None o no string)")
        
        # 3. Crear nuevo lote - SIN CANTIDAD_CAJA
        lote_id = None
        try:
            # ✅ CORREGIDO: precio_unitario YA es el precio por unidad, no dividir
            precio_por_unidad = item['precio_unitario']
            
            print(f"💰 Creando lote - Precio unitario: Bs{precio_por_unidad} × {item['cantidad_unitario']}u = Bs{precio_por_unidad * item['cantidad_unitario']}")
            
            lote_id = self.producto_repo.aumentar_stock_compra(
                producto_id=item['producto_id'],
                cantidad_unitario=item['cantidad_unitario'],
                fecha_vencimiento=fecha_venc_final,  # None para sin vencimiento, string para con vencimiento
                precio_compra=precio_por_unidad
            )
            
            if not lote_id or lote_id <= 0:
                raise CompraError(f"FALLO CRÍTICO: No se pudo crear lote para producto {item['codigo']}")
            
            print(f"✅ Lote creado exitosamente - ID: {lote_id} para producto {item['codigo']}")
            
        except Exception as e:
            print(f"❌ ERROR creando lote para {item['codigo']}: {str(e)}")
            raise CompraError(f"Error creando lote para producto {item['codigo']}: {str(e)}")
        
        # 4. Crear detalle de compra - SIN CANTIDAD_CAJA
        detalle_id = None
        try:
            detalle_data = {
                'Id_Compra': compra_id,
                'Id_Lote': lote_id,
                'Cantidad_Unitario': item['cantidad_unitario'],
                'Precio_Unitario': item['precio_unitario']  # ✅ PRECIO POR UNIDAD de compra
            }
            
            # Query SIN Cantidad_Caja
            detalle_query = """
            INSERT INTO DetalleCompra (Id_Compra, Id_Lote, Cantidad_Unitario, Precio_Unitario)
            OUTPUT INSERTED.id
            VALUES (?, ?, ?, ?)
            """
            
            detalle_result = self._execute_query(
                detalle_query,
                (compra_id, lote_id, item['cantidad_unitario'], item['precio_unitario']),
                fetch_one=True
            )
            
            # VALIDACIÓN DEL RESULTADO
            if not detalle_result or not isinstance(detalle_result, dict) or 'id' not in detalle_result:
                # ROLLBACK: Si falló el detalle, eliminar el lote creado
                print(f"❌ ERROR: Fallo creando DetalleCompra, ejecutando rollback para lote {lote_id}")
                self._rollback_lote_created(lote_id, item['producto_id'], item['cantidad_unitario'])
                raise CompraError(f"Error creando detalle de compra para {item['codigo']}")
            
            detalle_id = detalle_result['id']
            print(f"✅ Detalle creado - ID: {detalle_id}, Lote: {lote_id}, Producto: {item['codigo']}")
            
            # 5. Retornar información del item procesado
            return {
                'detalle_id': detalle_id,
                'lote_id': lote_id,
                'producto_codigo': item['codigo'],
                'cantidad_total': item['cantidad_total'],
                'precio_unitario': item['precio_unitario'],  # COSTO TOTAL
                'costo_total': item['precio_unitario'],  # COSTO TOTAL
                'fecha_vencimiento': fecha_venc_final,  # None o fecha válida
                'sin_vencimiento': fecha_venc_final is None
            }
            
        except Exception as e:
            # ROLLBACK: Si algo falló, eliminar el lote creado
            print(f"❌ ERROR en detalle de compra para {item['codigo']}: {str(e)}")
            if lote_id:
                self._rollback_lote_created(lote_id, item['producto_id'], item['cantidad_unitario'])
            raise CompraError(f"Error procesando item {item['codigo']}: {str(e)}")
    
    def _rollback_lote_created(self, lote_id: int, producto_id: int, cantidad_unitario: int):
        """
        Método de rollback para eliminar lote creado si falla el detalle - SIMPLIFICADO
        """
        try:
            print(f"🔄 Ejecutando rollback - Lote: {lote_id}, Producto: {producto_id}")
            
            # 1. Eliminar lote
            delete_lote_query = "DELETE FROM Lote WHERE id = ?"
            self._execute_query(delete_lote_query, (lote_id,), fetch_all=False, use_cache=False)
            
            print(f"✅ Rollback completado - Lote {lote_id} eliminado")
            
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
            #print(f"📋 get_proveedores_activos: {len(result)} proveedores obtenidos")
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
        """Productos más comprados en período - SIN CAJAS"""
        query = f"""
        SELECT TOP {limit}
            p.Codigo,
            p.Nombre as Producto_Nombre,
            m.Nombre as Marca_Nombre,
            SUM(dc.Cantidad_Unitario) as Cantidad_Comprada,
            COUNT(DISTINCT c.id) as Num_Compras,
            SUM(dc.Precio_Unitario) as Costo_Total,
            AVG(dc.Precio_Unitario / dc.Cantidad_Unitario) as Precio_Promedio_Unitario
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
        """Verifica la integridad de una compra - SIN CAJAS"""
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
        
        # Verificar que todos los lotes existen y tienen stock - SIN CAJAS
        for detalle in compra['detalles']:
            lote_query = "SELECT * FROM Lote WHERE id = ?"
            lote = self._execute_query(lote_query, (detalle['Id_Lote'],), fetch_one=True)
            if not lote:
                errores.append(f"Lote {detalle['Id_Lote']} no existe")
            elif lote['Cantidad_Unitario'] <= 0:
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
        
    @ExceptionHandler.handle_exception
    def actualizar_compra(self, compra_id: int, proveedor_id: int, usuario_id: int, 
                        items_compra: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Actualiza una compra existente - NUEVA FUNCIONALIDAD
        
        Args:
            compra_id: ID de la compra a actualizar
            proveedor_id: Nuevo ID del proveedor
            usuario_id: ID del usuario que realiza la actualización
            items_compra: Nueva lista de items
            
        Returns:
            Información completa de la compra actualizada
        """
        validate_required(compra_id, "compra_id")
        validate_required(proveedor_id, "proveedor_id")
        validate_required(usuario_id, "usuario_id")
        validate_required(items_compra, "items_compra")
        
        if not items_compra:
            raise CompraError("No se proporcionaron items para actualizar")
        
        print(f"📝 ACTUALIZANDO COMPRA {compra_id} - Proveedor: {proveedor_id}, Items: {len(items_compra)}")
        
        try:
            # ===== FASE 1: VALIDAR QUE LA COMPRA EXISTE =====
            compra_actual = self.get_compra_completa(compra_id)
            if not compra_actual:
                raise CompraError(f"Compra {compra_id} no encontrada")
            
            print(f"✅ Compra encontrada - Total original: ${compra_actual['Total']}")
            
            # ===== FASE 2: VALIDAR Y PREPARAR NUEVOS ITEMS =====
            items_preparados = []
            total_compra = Decimal('0.00')
            
            for i, item in enumerate(items_compra):
                try:
                    item_preparado = self._validar_y_preparar_item(item)
                    items_preparados.append(item_preparado)
                    total_compra += Decimal(str(item_preparado['precio_unitario']))
                    print(f"  ✅ Item {i+1}: {item_preparado['codigo']} - ${item_preparado['precio_unitario']}")
                except Exception as e:
                    raise CompraError(f"Error en item {i+1} ({item.get('codigo', 'sin código')}): {str(e)}")
            
            print(f"💰 Nuevo total calculado: ${total_compra}")
            
            # ===== FASE 3: ELIMINAR DETALLES Y LOTES ANTERIORES =====
            print("🗑️ Eliminando detalles y lotes anteriores...")
            
            # Obtener lotes asociados antes de eliminar detalles
            lotes_query = """
            SELECT DISTINCT dc.Id_Lote
            FROM DetalleCompra dc 
            WHERE dc.Id_Compra = ?
            """
            lotes_antiguos = self._execute_query(lotes_query, (compra_id,))
            
            # Eliminar detalles de compra
            delete_detalles_query = "DELETE FROM DetalleCompra WHERE Id_Compra = ?"
            detalles_eliminados = self._execute_query(delete_detalles_query, (compra_id,), 
                                                    fetch_all=False, use_cache=False)
            print(f"  ✅ {detalles_eliminados} detalles eliminados")
            
            # Eliminar lotes antiguos (esto actualiza automáticamente el stock)
            lotes_eliminados = 0
            for lote_info in lotes_antiguos:
                try:
                    lote_id = lote_info['Id_Lote']
                    delete_lote_query = "DELETE FROM Lote WHERE id = ?"
                    resultado = self._execute_query(delete_lote_query, (lote_id,), 
                                                fetch_all=False, use_cache=False)
                    if resultado > 0:
                        lotes_eliminados += 1
                        print(f"    ✅ Lote {lote_id} eliminado")
                except Exception as e:
                    print(f"    ⚠️ Error eliminando lote {lote_id}: {str(e)}")
            
            print(f"  ✅ {lotes_eliminados} lotes eliminados")
            
            # ===== FASE 4: ACTUALIZAR DATOS PRINCIPALES DE LA COMPRA =====
            print("📝 Actualizando datos principales...")
            
            update_compra_query = """
            UPDATE Compra 
            SET Id_Proveedor = ?, Total = ?, Fecha = GETDATE()
            WHERE id = ?
            """
            
            resultado_update = self._execute_query(
                update_compra_query, 
                (proveedor_id, float(total_compra), compra_id),
                fetch_all=False, use_cache=False
            )
            
            if resultado_update <= 0:
                raise CompraError("No se pudo actualizar la compra principal")
            
            print(f"  ✅ Compra principal actualizada")
            
            # ===== FASE 5: CREAR NUEVOS LOTES Y DETALLES =====
            print(f"📦 Creando nuevos lotes y detalles...")
            lotes_creados = []
            
            for i, item in enumerate(items_preparados):
                try:
                    print(f"  📦 Procesando item {i+1}/{len(items_preparados)}: {item['codigo']}")
                    lote_info = self._procesar_item_con_lote(compra_id, item)
                    lotes_creados.append(lote_info)
                    print(f"  ✅ Item {i+1} procesado - Lote: {lote_info['lote_id']}")
                    
                except Exception as item_error:
                    print(f"  ❌ ERROR en item {i+1} ({item['codigo']}): {str(item_error)}")
                    # ROLLBACK: eliminar lotes ya creados en esta actualización
                    self._rollback_lotes_creados_actualizacion(lotes_creados)
                    raise CompraError(f"Error procesando item {item['codigo']}: {str(item_error)}")
            
            # ===== FASE 6: VERIFICAR INTEGRIDAD FINAL =====
            if len(lotes_creados) != len(items_preparados):
                print(f"❌ ERROR DE INTEGRIDAD: Items esperados: {len(items_preparados)}, Lotes creados: {len(lotes_creados)}")
                self._rollback_lotes_creados_actualizacion(lotes_creados)
                raise CompraError("Error de integridad: No todos los items se procesaron correctamente")
            
            # ===== FASE 7: OBTENER RESULTADO FINAL =====
            try:
                compra_actualizada = self.get_compra_completa(compra_id)
                
                if not compra_actualizada:
                    raise CompraError("Error obteniendo datos actualizados de la compra")
                
                print(f"🎉 COMPRA ACTUALIZADA EXITOSAMENTE")
                print(f"   ID: {compra_id}")
                print(f"   Total anterior: ${compra_actual['Total']}")
                print(f"   Total nuevo: ${total_compra}")
                print(f"   Items: {len(lotes_creados)}")
                print(f"   Lotes creados: {[l['lote_id'] for l in lotes_creados]}")
                
                return compra_actualizada
                
            except Exception as final_error:
                print(f"❌ ERROR obteniendo compra actualizada: {str(final_error)}")
                # Retornar datos básicos si hay problemas obteniendo detalles
                return {
                    'id': compra_id,
                    'Total': float(total_compra),
                    'detalles': lotes_creados,
                    'error_detalle': str(final_error)
                }
        
        except Exception as e:
            print(f"❌ ERROR GENERAL EN ACTUALIZAR_COMPRA: {str(e)}")
            raise CompraError(f"Error actualizando compra: {str(e)}")

    def _rollback_lotes_creados_actualizacion(self, lotes_creados: List[Dict[str, Any]]):
        """
        Rollback específico para actualización: elimina solo lotes recién creados
        """
        print(f"🔄 EJECUTANDO ROLLBACK ACTUALIZACIÓN - {len(lotes_creados)} lotes")
        
        try:
            # Solo eliminar lotes creados en esta actualización
            for lote_info in lotes_creados:
                try:
                    lote_id = lote_info.get('lote_id')
                    if lote_id:
                        # Eliminar detalle primero
                        delete_detalle_query = "DELETE FROM DetalleCompra WHERE Id_Lote = ?"
                        self._execute_query(delete_detalle_query, (lote_id,), fetch_all=False, use_cache=False)
                        
                        # Eliminar lote
                        delete_lote_query = "DELETE FROM Lote WHERE id = ?"
                        self._execute_query(delete_lote_query, (lote_id,), fetch_all=False, use_cache=False)
                        print(f"  ✅ Lote {lote_id} eliminado en rollback")
                        
                except Exception as lote_error:
                    print(f"  ❌ Error en rollback lote {lote_info.get('lote_id', 'N/A')}: {str(lote_error)}")
            
            print(f"🎯 ROLLBACK ACTUALIZACIÓN COMPLETADO")
            
        except Exception as rollback_error:
            print(f"❌ ERROR CRÍTICO EN ROLLBACK ACTUALIZACIÓN: {str(rollback_error)}")

    def crear_proveedor(self, nombre: str, direccion: str) -> int:
        """Crea un nuevo proveedor - MÉTODO EXISTENTE MEJORADO"""
        try:
            # Verificar si ya existe
            if self.exists_proveedor(nombre):
                raise CompraError(f"Ya existe un proveedor con el nombre: {nombre}")
            
            # Crear proveedor
            proveedor_data = {
                'Nombre': nombre.strip(),
                'Direccion': direccion.strip()
            }
            
            proveedor_id = self.insert(proveedor_data, table_override='Proveedor')
            
            if proveedor_id and proveedor_id > 0:
                print(f"🏢 Proveedor creado - ID: {proveedor_id}, Nombre: {nombre}")
                
                # Invalidar caché de proveedores
                if hasattr(self, '_cache_manager'):
                    self._cache_manager.invalidate_pattern('proveedores*')
                
                return proveedor_id
            else:
                raise CompraError("Error insertando proveedor en base de datos")
                
        except Exception as e:
            print(f"❌ Error creando proveedor {nombre}: {str(e)}")
            raise CompraError(f"Error creando proveedor: {str(e)}")

    def get_proveedor_por_id(self, proveedor_id: int) -> Dict[str, Any]:
        """Obtiene un proveedor específico por ID"""
        if proveedor_id <= 0:
            return {}
        
        query = """
        SELECT p.*, 
            COUNT(c.id) as Total_Compras,
            ISNULL(SUM(c.Total), 0) as Monto_Total,
            ISNULL(MAX(c.Fecha), NULL) as Ultima_Compra
        FROM Proveedor p
        LEFT JOIN Compra c ON p.id = c.Id_Proveedor
        WHERE p.id = ?
        GROUP BY p.id, p.Nombre, p.Direccion
        """
        
        return self._execute_query(query, (proveedor_id,), fetch_one=True) or {}
   
    def registrar_compra_con_lotes(self, proveedor_id: int, usuario_id: int, detalles: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        🚀 FIFO 2.0: Registra compra usando procedimiento almacenado sp_Registrar_Compra_Con_Lotes
        ✅ VERSIÓN CORREGIDA - SIN VERIFICACIÓN PREVIA CON HASH
        """
        try:
            validate_required(proveedor_id, "proveedor_id")
            validate_required(usuario_id, "usuario_id")
            validate_required(detalles, "detalles")
            
            if not detalles:
                raise CompraError("No se proporcionaron items para la compra")
            
            import json
            detalles_json = json.dumps(detalles)
            
            print(f"🛒 Registrando compra con SP - Proveedor: {proveedor_id}, Items: {len(detalles)}")
            
            # ✅ VERIFICACIÓN SIMPLIFICADA: Solo por proveedor en últimos 30 segundos
            # Esto evita compras duplicadas muy rápidas
            duplicado_query = """
            SELECT TOP 1 id 
            FROM Compra 
            WHERE Id_Proveedor = ? 
                AND Id_Usuario = ?
                AND DATEDIFF(SECOND, Fecha, GETDATE()) <= 30
            ORDER BY Fecha DESC
            """
            
            duplicado = self._execute_query(
                duplicado_query,
                (proveedor_id, usuario_id),
                fetch_one=True,
                use_cache=False
            )
            
            if duplicado:
                raise CompraError(f"⚠️ Ya hay una compra reciente del proveedor {proveedor_id}. Espere unos segundos antes de intentar nuevamente.")
            
            # Ejecutar procedimiento almacenado
            query = """
            DECLARE @Total DECIMAL(12,2), @IdCompra INT;
            
            EXEC sp_Registrar_Compra_Con_Lotes 
                @Id_Proveedor = ?,
                @Id_Usuario = ?,
                @Detalles = ?,
                @Total = @Total OUTPUT,
                @Id_Compra = @IdCompra OUTPUT;
            
            SELECT @IdCompra as IdCompra, @Total as Total;
            """
            
            # Ejecutar con use_cache=False para evitar problemas
            result = self._execute_query(
                query, 
                (proveedor_id, usuario_id, detalles_json),
                fetch_one=True,
                use_cache=False
            )
            
            # ✅ CORREGIDO: Manejo seguro del resultado
            if result:
                try:
                    # Obtener valores de forma segura
                    if isinstance(result, dict):
                        id_compra = result.get('IdCompra') or result.get('id_compra')
                        total = float(result.get('Total') or result.get('total') or 0)
                    elif isinstance(result, (tuple, list)) and len(result) >= 2:
                        id_compra = result[0]
                        total = float(result[1])
                    else:
                        # Si no podemos obtener los valores, intentar con query separada
                        raise ValueError("Formato de resultado inesperado")
                    
                    if not id_compra or id_compra <= 0:
                        raise CompraError("El procedimiento almacenado no retornó ID de compra válido")
                    
                    # ✅ AHORA SÍ: Calcular hash DESPUÉS de crear la compra
                    import hashlib
                    compra_hash = hashlib.md5(
                        json.dumps({
                            'proveedor_id': proveedor_id,
                            'usuario_id': usuario_id,
                            'detalles': detalles,
                            'timestamp': datetime.now().isoformat()
                        }, sort_keys=True).encode()
                    ).hexdigest()
                    
                    # Actualizar hash en la compra recién creada
                    update_hash_query = "UPDATE Compra SET Compra_Hash = ? WHERE id = ?"
                    self._execute_query(
                        update_hash_query,
                        (compra_hash, id_compra),
                        fetch_all=False,
                        use_cache=False
                    )
                    
                    # Invalidar cachés
                    self._invalidate_cache_after_modification()
                    
                    print(f"✅ Compra registrada exitosamente - ID: {id_compra}, Total: ${total:.2f}, Hash: {compra_hash}")
                    
                    return {
                        "exito": True,
                        "id_compra": id_compra,
                        "total": total,
                        "mensaje": f"Compra {id_compra} registrada exitosamente",
                        "sistema": "FIFO 2.0"
                    }
                    
                except Exception as parse_error:
                    print(f"❌ Error procesando resultado del SP: {parse_error}")
                    # Intentar obtener el último ID insertado como fallback
                    last_id_query = "SELECT MAX(id) as last_id FROM Compra WHERE Id_Proveedor = ? AND Id_Usuario = ?"
                    last_result = self._execute_query(
                        last_id_query,
                        (proveedor_id, usuario_id),
                        fetch_one=True,
                        use_cache=False
                    )
                    
                    if last_result and last_result.get('last_id'):
                        id_compra = last_result['last_id']
                        total = sum(item.get('Precio_Unitario', 0) * item.get('Cantidad', 0) for item in detalles)
                        
                        print(f"⚠️ Usando fallback - Último ID: {id_compra}")
                        return {
                            "exito": True,
                            "id_compra": id_compra,
                            "total": total,
                            "mensaje": f"Compra {id_compra} registrada (fallback)",
                            "sistema": "FIFO 2.0 (fallback)"
                        }
                    else:
                        raise CompraError("No se pudo determinar el ID de la compra creada")
            else:
                raise CompraError("El procedimiento almacenado no retornó resultados")
                
        except Exception as e:
            error_msg = str(e)
            print(f"❌ Error en compra con SP: {error_msg}")
            
            # ❌ **IMPORTANTE**: NO usar fallback legacy automático
            # Esto podría causar más duplicaciones
            raise CompraError(f"Error registrando compra: {error_msg}")

    def _get_codigo_producto(self, producto_id: int) -> str:
        """Helper para obtener código de producto por ID"""
        try:
            result = self._execute_query(
                "SELECT Codigo FROM Productos WHERE id = ?",
                (producto_id,),
                fetch_one=True,
                use_cache=False
            )
            return result['Codigo'] if result else str(producto_id)
        except:
            return str(producto_id)
        
    
    def verificar_compra_duplicada(self, proveedor_id: int, items: List[Dict[str, Any]], ventana_segundos: int = 5) -> bool:
        """
        ✅ VERSIÓN CORREGIDA - Usa la columna Compra_Hash
        """
        try:
            
            # Calcular hash de la compra actual
            compra_hash = hashlib.md5(
                json.dumps({
                    'proveedor_id': proveedor_id,
                    'items': items
                }, sort_keys=True).encode()
            ).hexdigest()
            
            # Buscar compras idénticas recientes
            query = """
            SELECT TOP 1 id 
            FROM Compra 
            WHERE Compra_Hash = ?
                AND DATEDIFF(SECOND, Fecha, GETDATE()) <= ?
            """
            
            resultado = self._execute_query(
                query, 
                (compra_hash, ventana_segundos),
                fetch_one=True,
                use_cache=False
            )
            
            if resultado:
                print(f"⚠️ Compra duplicada detectada - Hash: {compra_hash}")
                return True
            
            return False
            
        except Exception as e:
            print(f"⚠️ Error verificando duplicado: {str(e)}")
            return False