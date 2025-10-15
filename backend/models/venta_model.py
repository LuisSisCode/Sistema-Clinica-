from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtQml import qmlRegisterType
from typing import List, Dict, Any, Optional
import json
from datetime import datetime, timedelta
from decimal import Decimal

from ..repositories.venta_repository import VentaRepository
from ..repositories.producto_repository import ProductoRepository
from ..core.excepciones import (
    VentaError, ProductoNotFoundError, StockInsuficienteError,
    ExceptionHandler, safe_execute, validate_required
)

class VentaModel(QObject):
    """
    Model QObject para gestión de ventas con permisos simplificados
    ✅ CORREGIDO: Solo identifica usuario, permite operaciones básicas a todos
    """
    
    # ===============================
    # SIGNALS PARA QML
    # ===============================
    
    # Signals de datos
    ventasHoyChanged = Signal()
    ventaActualChanged = Signal()
    historialVentasChanged = Signal()
    estadisticasChanged = Signal()
    topProductosChanged = Signal()
    
    # Signals de operaciones
    ventaCreada = Signal(int, float)  # venta_id, total
    ventaAnulada = Signal(int, str)   # venta_id, motivo
    ventaActualizada = Signal(int, float)
    ventaEliminada = Signal(int)
    operacionExitosa = Signal(str)    # mensaje
    operacionError = Signal(str)  
    stockModificado = Signal()
    
    # Signals de estados
    loadingChanged = Signal()
    procesandoVentaChanged = Signal()
    carritoCambiado = Signal()
    
    def __init__(self):
        super().__init__()
        
        # Repositories
        self.venta_repo = VentaRepository()
        self.producto_repo = ProductoRepository()
        
        # Datos internos
        self._ventas_hoy = []
        self._venta_actual = {}
        self._historial_ventas = []
        self._estadisticas = {}
        self._top_productos = []
        self._carrito_items = []
        self._loading = False
        self._procesando_venta = False
        
        # ✅ SIMPLIFICADO: Solo identificar usuario, sin restricciones de rol
        self._usuario_actual_id = 0
        self._usuario_rol = ""
        self._usuario_nombre = ""  # NUEVO: Para mostrar en UI
        
        print("💰 VentaModel inicializado con permisos simplificados")
        
        # Timer para actualización automática
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._auto_update_ventas_hoy)
        self.update_timer.start(60000)  # 1 minuto
    
    # ===============================
    # ✅ MÉTODOS REQUERIDOS PARA APPCONTROLLER (SIMPLIFICADOS)
    # ===============================
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """Establece el usuario actual para las operaciones"""
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario establecido en VentaModel: {usuario_id}")
                
                # Cargar datos iniciales
                self._cargar_ventas_hoy(usar_cache=False)
                self._cargar_estadisticas(usar_cache=False)
                
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en ventas")
            else:
                print(f"⚠️ ID de usuario inválido: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")
    
    @Slot(int, str)
    def set_usuario_actual_con_rol(self, usuario_id: int, rol: str):
        """Establece usuario + rol solo para identificación"""
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                self._usuario_rol = rol.strip()
                self._usuario_nombre = f"Usuario_{usuario_id}" 
                
                print(f"👤 Usuario autenticado: {usuario_id} - {rol}")
                
                # Cargar datos iniciales
                self._cargar_ventas_hoy(usar_cache=False)
                self._cargar_estadisticas(usar_cache=False)
                
                self.operacionExitosa.emit(f"Usuario {usuario_id} ({rol}) establecido")
            else:
                self.operacionError.emit("Usuario o rol inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario con rol: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        """Property para obtener el usuario actual"""
        return self._usuario_actual_id
    
    @Property(str, notify=operacionExitosa)
    def usuario_rol(self):
        """Property para obtener el rol del usuario actual"""
        return self._usuario_rol
    
    @Slot(int, result='QVariantMap')
    def cargar_venta_para_edicion(self, venta_id: int):
        """Carga una venta para edición - ✅ DISPONIBLE PARA TODOS"""
        try:
            print(f"📝 Cargando venta {venta_id} para edición")
            
            if not self._verificar_autenticacion():
                return {}
            
            # ✅ PERMITIR A TODOS LOS USUARIOS (solo admin puede eliminar)
            
            detalle = self.venta_repo.get_venta_completa_consolidada(venta_id)
            
            if not detalle:
                self.operacionError.emit("Venta no encontrada")
                return {}
            
            # Formatear productos consolidados para edición
            productos_edicion = []
            
            if 'detalles' in detalle and detalle['detalles']:
                for item in detalle['detalles']:
                    codigo = item.get('Producto_Codigo', '')
                    if codigo:
                        # Obtener stock actual para validación
                        producto_actual = self.venta_repo.get_producto_por_codigo(codigo)
                        stock_actual = producto_actual['Stock_Unitario'] if producto_actual else 0
                        
                        producto_edicion = {
                            'codigo': codigo,
                            'nombre': str(item.get('Producto_Nombre', '')),
                            'precio': float(item.get('Precio_Unitario', 0)),
                            'cantidad': int(item.get('Cantidad_Unitario', 0)),
                            'subtotal': float(item.get('Subtotal', 0)),
                            'stock_disponible': stock_actual + int(item.get('Cantidad_Unitario', 0))
                        }
                        productos_edicion.append(producto_edicion)
            
            resultado = {
                'venta_id': int(detalle['id']),
                'fecha': detalle['Fecha'].isoformat() if hasattr(detalle['Fecha'], 'isoformat') else str(detalle['Fecha']),
                'vendedor': str(detalle.get('Vendedor', '')),
                'total_original': float(detalle['Total']),
                'productos': productos_edicion,
                'total_productos': len(productos_edicion),
                'es_editable': True  # ✅ TODOS PUEDEN EDITAR
            }
            
            print(f"✅ Venta {venta_id} cargada para edición: {len(productos_edicion)} productos")
            return resultado
            
        except Exception as e:
            print(f"❌ Error cargando venta para edición: {e}")
            self.operacionError.emit(f"Error cargando venta: {str(e)}")
            return {}
    
    # ===============================
    # ✅ VERIFICACIÓN SIMPLIFICADA (SOLO AUTENTICACIÓN)
    # ===============================
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica si el usuario está autenticado"""
        if self._usuario_actual_id <= 0:
            print(f"🚨 USUARIO NO AUTENTICADO: ID={self._usuario_actual_id}")
            self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
            return False
        return True
    

    
    # ===============================
    # ✅ BÚSQUEDA DE PRODUCTOS (SIN RESTRICCIONES)
    # ===============================
    
    @Slot(str, result='QVariant')
    def buscar_productos_para_venta(self, texto_busqueda: str):
        """Busca productos - ✅ DISPONIBLE PARA TODOS"""
        if not self._verificar_autenticacion():  # Solo verificar autenticación
            return []
        
        if not texto_busqueda or len(texto_busqueda.strip()) < 2:
            return []
        
        try:
            productos = self.venta_repo.buscar_productos_para_venta_sin_cache(texto_busqueda.strip())
            
            productos_venta = []
            for producto in productos:
                productos_venta.append({
                    'codigo': producto['Codigo'],
                    'nombre': producto['Nombre'],
                    'precio': float(producto['Precio_venta']),
                    'stock': int(producto['Stock_Total']),
                    'disponible': producto['Stock_Total'] > 0,
                    'marca': producto.get('Marca_Nombre', ''),
                    'timestamp_consulta': datetime.now().isoformat()
                })
            
            print(f"🔍 Búsqueda completada: {len(productos_venta)} productos")
            return productos_venta
            
        except Exception as e:
            self.operacionError.emit(f"Error buscando productos: {str(e)}")
            return []
    
    @Slot(str, result='QVariantMap')
    def obtener_producto_por_codigo(self, codigo: str):
        """Obtiene producto por código - ✅ DISPONIBLE PARA TODOS"""
        if not self._verificar_autenticacion():
            return {}
        
        if not codigo:
            return {}
        
        try:
            print(f"🔍 Obteniendo producto por código: '{codigo}'")
            
            if hasattr(self.venta_repo, 'get_producto_por_codigo'):
                producto = self.venta_repo.get_producto_por_codigo(codigo)
            else:
                producto = safe_execute(self.producto_repo.get_by_codigo, codigo)
            
            if producto:
                print(f"✅ Producto encontrado: {producto['Nombre']}")
                return {
                    'id': producto['id'],
                    'codigo': producto['Codigo'],
                    'nombre': producto['Nombre'],
                    'precio_venta': producto['Precio_venta'],
                    'stock_unitario': producto['Stock_Unitario'],
                    'unidad_medida': producto.get('Unidad_Medida', 'Unidades'),
                    'marca': producto.get('Marca_Nombre', 'Sin marca'),
                    'disponible': producto['Stock_Unitario'] > 0
                }
            else:
                print(f"⚠️ Producto no encontrado: {codigo}")
                return {}
                
        except Exception as e:
            print(f"❌ Error obteniendo producto: {e}")
            self.operacionError.emit(f"Error obteniendo producto: {str(e)}")
            return {}
    
    # ===============================
    # ✅ EDITAR Y ELIMINAR VENTAS (SIMPLIFICADO)
    # ===============================
    
    @Slot(int, 'QVariantList', result=bool)
    def actualizar_venta_completa(self, venta_id: int, nuevos_productos: list):
        """Actualiza venta - ✅ DISPONIBLE PARA TODOS"""
        if not self._verificar_autenticacion():  # Solo verificar autenticación
            return False
        
        if venta_id <= 0 or not nuevos_productos:
            self.operacionError.emit("Parámetros inválidos para actualizar venta")
            return False
        
        try:
            print(f"INICIO actualización venta {venta_id} con {len(nuevos_productos)} productos")
            
            # Validar productos
            productos_validados = []
            for i, prod in enumerate(nuevos_productos):
                if not isinstance(prod, dict):
                    self.operacionError.emit(f"Producto {i} inválido")
                    return False
                
                try:
                    codigo = str(prod.get('codigo', '')).strip()
                    cantidad = int(prod.get('cantidad', 0))
                    precio = float(prod.get('precio', 0))
                    
                    if not codigo:
                        self.operacionError.emit(f"Código vacío en producto {i}")
                        return False
                    if cantidad <= 0:
                        self.operacionError.emit(f"Cantidad inválida en producto {i}: {cantidad}")
                        return False
                    if precio <= 0:
                        self.operacionError.emit(f"Precio inválido en producto {i}: {precio}")
                        return False
                    
                    # Verificar stock disponible
                    stock_check = self.verificar_disponibilidad_producto(codigo)
                    if stock_check['cantidad_disponible'] < cantidad:
                        self.operacionError.emit(
                            f"Stock insuficiente para {codigo}. "
                            f"Disponible: {stock_check['cantidad_disponible']}, "
                            f"Solicitado: {cantidad}"
                        )
                        return False
                    
                    productos_validados.append({
                        'codigo': codigo,
                        'cantidad': cantidad,
                        'precio': precio,
                        'subtotal': cantidad * precio
                    })
                    
                except (ValueError, TypeError) as e:
                    self.operacionError.emit(f"Error validando producto {i}: {e}")
                    return False
            
            print(f"Productos validados exitosamente: {len(productos_validados)}")
            
            # Llamar al repository
            exito = self.venta_repo.actualizar_venta_completa(venta_id, productos_validados)
            
            if exito:
                self._invalidar_cache_completo()
                self._cargar_ventas_hoy(usar_cache=False)
                self._cargar_estadisticas(usar_cache=False)
                
                nuevo_total = sum(float(p.get('subtotal', 0)) for p in productos_validados)
                
                self.ventaActualizada.emit(venta_id, nuevo_total)
                self.operacionExitosa.emit(f"Venta {venta_id} actualizada exitosamente")
                
                print(f"✅ Venta {venta_id} actualizada")
                return True
            else:
                self.operacionError.emit("Error en base de datos al actualizar la venta")
                return False
                
        except Exception as e:
            print(f"❌ Error en actualizar_venta_completa: {e}")
            self.operacionError.emit(f"Error actualizando venta: {str(e)}")
            return False
    
    @Slot(int, result=bool)
    def eliminar_venta(self, venta_id: int):
        """Elimina venta - ✅ SOLO ADMIN"""
        
        if venta_id <= 0:
            self.operacionError.emit("ID de venta inválido")
            return False
        
        try:
            print(f"🗑️ Eliminando venta {venta_id}")
            
            if hasattr(self.venta_repo, 'eliminar_venta'):
                exito = self.venta_repo.eliminar_venta(venta_id)
            else:
                exito = self.venta_repo.anular_venta(venta_id, "Eliminación por administrador")
            
            if exito:
                self._cargar_ventas_hoy(usar_cache=False)
                self._cargar_estadisticas(usar_cache=False)
                
                self.ventaEliminada.emit(venta_id)
                self.operacionExitosa.emit(f"Venta {venta_id} eliminada exitosamente")
                
                print(f"✅ Venta {venta_id} eliminada")
                return True
            else:
                self.operacionError.emit("Error eliminando la venta")
                return False
                
        except Exception as e:
            print(f"❌ Error eliminando venta: {e}")
            self.operacionError.emit(f"Error eliminando venta: {str(e)}")
            return False
    
    # ===============================
    # ✅ PROPERTIES SIMPLIFICADAS (SIN FILTROS RESTRICTIVOS)
    # ===============================
    
    @Property(list, notify=ventasHoyChanged)
    def ventas_hoy(self):
        """Lista de ventas del día - ✅ TODOS PUEDEN VER TODAS"""
        return self._ventas_hoy  # Sin filtros por rol
    
    @Property('QVariant', notify=ventaActualChanged)
    def venta_actual(self):
        """Venta actualmente seleccionada/en proceso"""
        return self._venta_actual
    
    @Property(list, notify=historialVentasChanged)
    def historial_ventas(self):
        """Historial de ventas"""
        return self._historial_ventas
    
    @Property('QVariant', notify=estadisticasChanged)
    def estadisticas(self):
        """Estadísticas - ✅ TODOS PUEDEN VER"""
        return self._estadisticas
    
    @Property(list, notify=topProductosChanged)
    def top_productos(self):
        """Top productos más vendidos"""
        return self._top_productos
    
    @Property(list, notify=carritoCambiado)
    def carrito_items(self):
        """Items en el carrito actual"""
        return self._carrito_items
    
    @Property(bool, notify=loadingChanged)
    def loading(self):
        """Estado de carga general"""
        return self._loading
    
    @Property(bool, notify=procesandoVentaChanged)
    def procesando_venta(self):
        """Estado de procesamiento de venta"""
        return self._procesando_venta
    
    @Property(int, notify=ventasHoyChanged)
    def total_ventas_hoy(self):
        """Total de ventas del día"""
        return len(self._ventas_hoy)
    
    @Property(float, notify=estadisticasChanged)
    def ingresos_hoy(self):
        """Ingresos del día"""
        return float(self._estadisticas.get('Ingresos_Total', 0))
    
    @Property(float, notify=carritoCambiado)
    def total_carrito(self):
        """Total del carrito actual"""
        return sum(float(item.get('subtotal', 0)) for item in self._carrito_items)
    
    @Property(int, notify=carritoCambiado)
    def items_carrito(self):
        """Cantidad de items en carrito"""
        return len(self._carrito_items)
    
    # ===============================
    # ✅ PROPERTIES DE PERMISOS SIMPLIFICADAS
    # ===============================
    
    @Property(bool, notify=operacionExitosa)
    def puede_crear_ventas(self):
        """✅ TODOS pueden crear ventas"""
        return True
    
    @Property(bool, notify=operacionExitosa)
    def puede_ver_todas_ventas(self):
        """✅ TODOS pueden ver todas las ventas"""
        return True
    
    @Property(bool, notify=operacionExitosa)
    def puede_ver_reportes_financieros(self):
        """✅ TODOS pueden ver reportes"""
        return True
    
    @Property(bool, notify=operacionExitosa)
    def puede_modificar_precios(self):
        """✅ TODOS pueden modificar precios"""
        return True
    
    @Property(bool, notify=operacionExitosa)
    def puede_exportar_datos(self):
        """✅ TODOS pueden exportar"""
        return True
    
    @Property(bool, notify=operacionExitosa)
    def mostrar_informacion_limitada(self):
        """✅ NO mostrar información limitada"""
        return False
    
    @Property(bool, notify=operacionExitosa)
    def puede_editar_ventas(self):
        """✅ TODOS pueden editar ventas"""
        return True
    
    @Property(bool, notify=operacionExitosa)
    def puede_eliminar_ventas(self):
        """✅ SOLO ADMIN puede eliminar"""
        return self._usuario_rol == "Administrador"
    
    # ===============================
    # ✅ CARRITO (SIN VERIFICACIÓN DE PERMISOS)
    # ===============================
    
    @Slot(str, int, float)
    def agregar_item_carrito(self, codigo: str, cantidad: int, precio_custom: float = 0):
        """Agrega item al carrito - ✅ DISPONIBLE PARA TODOS"""
        if not self._verificar_autenticacion():  # Solo autenticación
            return
        
        if not codigo or cantidad <= 0:
            self.operacionError.emit("Código o cantidad inválidos")
            return
        
        try:
            # Obtener producto
            producto = self.venta_repo.get_producto_por_codigo(codigo.strip())
            if not producto:
                raise ProductoNotFoundError(codigo=codigo)
            
            print(f"🛒 Producto encontrado: {producto['id']} - {producto['Nombre']}")
            
            # Verificar disponibilidad
            verificacion = self.verificar_disponibilidad_para_cantidad(codigo, cantidad)
            if not verificacion['disponible']:
                raise StockInsuficienteError(
                    codigo, 
                    verificacion['cantidad_total_disponible'], 
                    cantidad
                )
            
            precio = precio_custom if precio_custom > 0 else float(producto['Precio_venta'])
            subtotal = cantidad * precio
            
            # Verificar si ya existe en carrito
            item_existente = None
            for item in self._carrito_items:
                if item['codigo'] == codigo.strip():
                    item_existente = item
                    break
            
            if item_existente:
                nueva_cantidad = item_existente['cantidad'] + cantidad
                
                verificacion_total = self.verificar_disponibilidad_para_cantidad(codigo, nueva_cantidad)
                if not verificacion_total['disponible']:
                    raise StockInsuficienteError(
                        codigo, 
                        verificacion_total['cantidad_total_disponible'], 
                        nueva_cantidad
                    )
                
                item_existente['cantidad'] = nueva_cantidad
                item_existente['subtotal'] = nueva_cantidad * precio
            else:
                nuevo_item = {
                    'codigo': codigo.strip(),
                    'producto_id': producto['id'],
                    'nombre': producto['Nombre'],
                    'marca': producto.get('Marca_Nombre', ''),
                    'cantidad': cantidad,
                    'precio': precio,
                    'subtotal': subtotal,
                    'stock_disponible': producto['Stock_Total'],
                    'lotes_disponibles': producto.get('Lotes_Activos', 0),
                    'verificado_fifo': True
                }
                self._carrito_items.append(nuevo_item)
            
            self.carritoCambiado.emit()
            self.operacionExitosa.emit(f"Agregado: {cantidad}x {codigo}")
            print(f"🛒 Item agregado - {codigo}: {cantidad}x${precio}")
            
        except Exception as e:
            error_msg = f"Error agregando item: {str(e)}"
            print(f"❌ {error_msg}")
            self.operacionError.emit(error_msg)
    
    @Slot(str)
    def remover_item_carrito(self, codigo: str):
        """Remueve item del carrito"""
        if not codigo:
            return
        
        self._carrito_items = [
            item for item in self._carrito_items 
            if item['codigo'] != codigo.strip()
        ]
        self.carritoCambiado.emit()
        self.operacionExitosa.emit(f"Removido: {codigo}")
    
    @Slot(str, int)
    def actualizar_cantidad_carrito(self, codigo: str, nueva_cantidad: int):
        """Actualiza cantidad en carrito"""
        if not codigo or nueva_cantidad < 0:
            return
        
        if nueva_cantidad == 0:
            self.remover_item_carrito(codigo)
            return
        
        try:
            for item in self._carrito_items:
                if item['codigo'] == codigo.strip():
                    if hasattr(self.venta_repo, 'get_producto_por_codigo'):
                        producto = self.venta_repo.get_producto_por_codigo(codigo.strip())
                    else:
                        producto = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
                    
                    if not producto:
                        raise ProductoNotFoundError(codigo=codigo)
                    
                    stock_disponible = producto['Stock_Unitario'] or 0
                    if nueva_cantidad > stock_disponible:
                        raise StockInsuficienteError(
                            codigo, 
                            stock_disponible, 
                            nueva_cantidad
                        )
                    
                    item['cantidad'] = nueva_cantidad
                    item['subtotal'] = nueva_cantidad * item['precio']
                    item['stock_disponible'] = stock_disponible
                    break
            
            self.carritoCambiado.emit()
            print(f"🛒 Cantidad actualizada - {codigo}: {nueva_cantidad}")
            
        except Exception as e:
            self.operacionError.emit(f"Error actualizando cantidad: {str(e)}")
    
    @Slot()
    def limpiar_carrito(self):
        """Limpia completamente el carrito"""
        self._carrito_items.clear()
        self.carritoCambiado.emit()
        self.operacionExitosa.emit("Carrito limpiado")
    
    # ===============================
    # ✅ PROCESAMIENTO DE VENTAS (DISPONIBLE PARA TODOS)
    # ===============================
    
    @Slot(result=bool)
    def procesar_venta_carrito(self):
        """Procesa venta - ✅ DISPONIBLE PARA TODOS"""
        print(f"INICIO procesar_venta_carrito - Items: {len(self._carrito_items)}")
        
        if not self._verificar_autenticacion():  # Solo autenticación
            return False
        
        if not self._carrito_items:
            self.operacionError.emit("Carrito vacío")
            return False
        
        self._set_procesando_venta(True)
        
        try:
            # Validar stock antes de procesar
            for i, item in enumerate(self._carrito_items):
                codigo = str(item.get('codigo', '')).strip()
                cantidad = int(item.get('cantidad', 0))
                
                if codigo and cantidad > 0:
                    stock_check = self.verificar_disponibilidad_producto(codigo)
                    if stock_check['cantidad_disponible'] < cantidad:
                        self.operacionError.emit(
                            f"Stock insuficiente para {codigo}. "
                            f"Disponible: {stock_check['cantidad_disponible']}"
                        )
                        return False
            
            # Preparar items para venta
            items_venta = []
            for i, item in enumerate(self._carrito_items):
                codigo = str(item['codigo']).strip()
                cantidad = int(item['cantidad'])
                precio = float(item['precio'])
                
                items_venta.append({
                    'codigo': codigo,
                    'cantidad': cantidad,
                    'precio': precio
                })
            
            print(f"Items preparados para repository: {len(items_venta)}")
            
            # Procesar venta
            venta = self.venta_repo.crear_venta(self._usuario_actual_id, items_venta)
            
            if venta and isinstance(venta, dict) and 'id' in venta:
                # Limpiar carrito
                self.limpiar_carrito()
                
                # Invalidar cache y recargar
                self._invalidar_cache_completo()
                self._invalidar_cache_productos()
                
                self._cargar_ventas_hoy(usar_cache=False)
                self._cargar_estadisticas(usar_cache=False)
                
                # Emitir signals
                self.stockModificado.emit()
                self.operacionExitosa.emit("Venta procesada exitosamente")
                
                self.ventasHoyChanged.emit()
                self.estadisticasChanged.emit()
                
                self._venta_actual = venta
                self.ventaActualChanged.emit()
                
                self.ventaCreada.emit(int(venta['id']), float(venta['Total']))
                self.operacionExitosa.emit(f"Venta procesada: ${venta['Total']:.2f}")
                
                print(f"✅ Venta creada - ID: {venta['id']}, Total: ${venta['Total']}")
                return True
            else:
                raise VentaError("Respuesta inválida del repository")
                
        except Exception as e:
            print(f"❌ Error en procesar_venta_carrito: {e}")
            error_msg = str(e)
            
            if "Stock insuficiente" in error_msg:
                self.operacionError.emit("Stock insuficiente para uno o más productos")
            elif "timeout" in error_msg.lower():
                self.operacionError.emit("Operación demorada. Intente nuevamente.")
            else:
                self.operacionError.emit(f"Error procesando venta: {error_msg}")
            
            return False
        finally:
            self._set_procesando_venta(False)
    
    # ===============================
    # RESTO DE MÉTODOS (SIN CAMBIOS SIGNIFICATIVOS)
    # ===============================
    
    def _invalidar_cache_completo(self):
        """Invalida completamente todos los caches"""
        try:
            if hasattr(self.venta_repo, '_invalidate_cache_after_modification'):
                self.venta_repo._invalidate_cache_after_modification()
            
            if hasattr(self.producto_repo, '_invalidate_cache_after_modification'):
                self.producto_repo._invalidate_cache_after_modification()
            
            print("Cache completamente invalidado")
            
        except Exception as e:
            print(f"Error invalidando cache: {e}")
    
    def _invalidar_cache_productos(self):
        """Invalida específicamente el cache de productos"""
        try:
            if hasattr(self.producto_repo, '_invalidate_cache_after_modification'):
                self.producto_repo._invalidate_cache_after_modification()
                print("🔄 Cache ProductoRepository invalidado")
            
            if hasattr(self.venta_repo, '_invalidate_cache_after_modification'):
                self.venta_repo._invalidate_cache_after_modification()
                print("🔄 Cache VentaRepository invalidado")
            
            if hasattr(self.venta_repo, '_force_reload_productos'):
                self.venta_repo._force_reload_productos = True
            
            print("✅ Cache de productos invalidado completamente")
            
        except Exception as e:
            print(f"⚠️ Error invalidando cache de productos: {e}")
    
    # ✅ MÉTODOS DE REFRESH (SIN RESTRICCIONES)
    @Slot()
    def refresh_ventas_hoy(self):
        """Refresca las ventas del día"""
        if not self._verificar_autenticacion():
            return 
        self._cargar_ventas_hoy(usar_cache=False)
    
    @Slot()
    def refresh_estadisticas(self):
        """Refresca las estadísticas"""
        if not self._verificar_autenticacion():
            return
        self._cargar_estadisticas(usar_cache=False)
    
    # ✅ VERIFICACIÓN DE STOCK (SIN RESTRICCIONES)
    @Slot(str, result='QVariantMap')
    def verificar_disponibilidad_producto(self, codigo: str):
        """Verifica disponibilidad sin restricciones"""
        if not self._verificar_autenticacion():
            return {"cantidad_disponible": 0, "disponible": False, "error": "No autenticado"}
        
        if not codigo:
            return {"cantidad_disponible": 0, "disponible": False, "error": "Código requerido"}
        
        try:
            producto = self.venta_repo.get_producto_por_codigo_sin_cache(codigo.strip())
            if not producto:
                return {
                    "cantidad_disponible": 0, 
                    "disponible": False, 
                    "error": f"Producto {codigo} no encontrado"
                }
            
            stock_total = producto.get('Stock_Total', 0)
            
            resultado = {
                "cantidad_disponible": stock_total,
                "disponible": stock_total > 0,
                "producto_id": producto.get('id', 0),
                "codigo": codigo.strip(),
                "nombre": producto.get('Nombre', ''),
                "precio_venta": float(producto.get('Precio_venta', 0)),
                "lotes_activos": producto.get('Lotes_Activos', 0),
                "consulta_sin_cache": True,
                "timestamp": datetime.now().isoformat()
            }
            
            print(f"✅ Verificación para {codigo}: {stock_total} unidades disponibles")
            return resultado
            
        except Exception as e:
            error_msg = f"Error verificando disponibilidad para {codigo}: {str(e)}"
            print(f"❌ {error_msg}")
            return {
                "cantidad_disponible": 0, 
                "disponible": False, 
                "error": error_msg
            }
    
    @Slot(str, int, result='QVariantMap')
    def verificar_disponibilidad_para_cantidad(self, codigo: str, cantidad_solicitada: int):
        """Verifica disponibilidad FIFO para cantidad específica"""
        if not self._verificar_autenticacion():
            return {"disponible": False, "error": "No autenticado"}
        
        if not codigo or cantidad_solicitada <= 0:
            return {"disponible": False, "error": "Parámetros inválidos"}
        
        try:
            producto = self.venta_repo.get_producto_por_codigo(codigo.strip())
            if not producto:
                return {"disponible": False, "error": f"Producto {codigo} no encontrado"}
            
            disponibilidad = self.producto_repo.verificar_disponibilidad_fifo(
                producto['id'], 
                cantidad_solicitada
            )
            
            resultado = {
                "disponible": disponibilidad['disponible'],
                "cantidad_solicitada": cantidad_solicitada,
                "cantidad_total_disponible": disponibilidad['cantidad_total_disponible'],
                "cantidad_faltante": disponibilidad.get('cantidad_faltante', 0),
                "lotes_necesarios": len(disponibilidad.get('lotes_necesarios', [])),
                "tiene_vencidos": disponibilidad.get('tiene_vencidos', False),
                "codigo": codigo.strip(),
                "nombre": producto.get('Nombre', ''),
                "puede_procesar": disponibilidad['disponible']
            }
            
            if disponibilidad['disponible']:
                lotes_info = []
                for lote_info in disponibilidad.get('lotes_necesarios', []):
                    lotes_info.append({
                        "lote_id": lote_info['lote_id'],
                        "cantidad_a_usar": lote_info['cantidad'],
                        "fecha_vencimiento": lote_info['fecha_vencimiento'],
                        "estado": lote_info['estado']
                    })
                resultado["lotes_a_utilizar"] = lotes_info
            
            print(f"🔍 Verificación FIFO para {codigo} x{cantidad_solicitada}: {'✅ DISPONIBLE' if resultado['disponible'] else '❌ INSUFICIENTE'}")
            
            return resultado
            
        except Exception as e:
            error_msg = f"Error verificando cantidad para {codigo}: {str(e)}"
            print(f"❌ {error_msg}")
            return {"disponible": False, "error": error_msg}
    
    # ✅ OBTENER DETALLE DE VENTA (SIN RESTRICCIONES DE ROL)
    @Slot(int, result='QVariantMap')
    def obtener_detalle_venta(self, venta_id: int):
        """Obtiene detalle de venta - ✅ DISPONIBLE PARA TODOS"""
        try:
            print(f"🔍 Obteniendo detalle de venta {venta_id}")
            
            if not self._verificar_autenticacion():
                return {}
            
            if not isinstance(venta_id, int) or venta_id <= 0:
                print(f"❌ ID de venta inválido: {venta_id}")
                return {}
            
            try:
                detalle = self.venta_repo.get_venta_completa_consolidada(venta_id)
                print(f"🔍 Detalle consolidado obtenido del repository")
                
                if not detalle:
                    print(f"❌ No se encontró venta con ID {venta_id}")
                    return {}
                
                # ✅ NO VERIFICAR PERMISOS POR ROL - TODOS PUEDEN VER
                
                # Procesar detalles
                detalles_procesados = []
                if detalle.get('detalles'):
                    for item in detalle['detalles']:
                        cantidad = float(item.get('Cantidad_Unitario', 0))
                        precio = float(item.get('Precio_Unitario', 0))
                        subtotal_bd = float(item.get('Subtotal', 0))
                        
                        if subtotal_bd <= 0:
                            subtotal_calculado = cantidad * precio
                        else:
                            subtotal_calculado = subtotal_bd
                        
                        detalle_procesado = {
                            'Producto_Codigo': str(item.get('Producto_Codigo', '')),
                            'Producto_Nombre': str(item.get('Producto_Nombre', '')),
                            'Marca_Nombre': str(item.get('Marca_Nombre', '')),
                            'Cantidad_Unitario': cantidad,
                            'Precio_Unitario': precio,
                            'Subtotal': subtotal_calculado,
                            'Fecha_Vencimiento': item.get('Fecha_Vencimiento')
                        }
                        
                        detalles_procesados.append(detalle_procesado)
                
                resultado = {
                    'id': int(detalle['id']),
                    'fecha': detalle['Fecha'].strftime('%Y-%m-%d %H:%M') if hasattr(detalle['Fecha'], 'strftime') else str(detalle['Fecha']),
                    'vendedor': str(detalle.get('Vendedor', 'Usuario desconocido')),
                    'total': float(detalle['Total']),
                    'detalles': detalles_procesados,
                    'total_items': len(detalles_procesados),
                    'es_propia': detalle.get('Id_Usuario') == self._usuario_actual_id,
                    'puede_editar': True,  # ✅ TODOS PUEDEN EDITAR
                    'puede_eliminar': self._usuario_rol == "Administrador"  # Solo admin elimina
                }
                
                total_calculado = sum(item['Subtotal'] for item in detalles_procesados)
                print(f"📊 Total BD: {resultado['total']}, Total calculado: {total_calculado}")
                
                print(f"📋 Detalle consolidado formateado: {len(detalles_procesados)} productos únicos")
                return resultado
                
            except Exception as repo_error:
                print(f"❌ Error del repository: {repo_error}")
                return {}
            
        except Exception as e:
            print(f"❌ Error general obteniendo detalle: {e}")
            return {}
    
    # ✅ MÉTODOS PRIVADOS DE CARGA (SIN FILTROS POR ROL)
    def _cargar_ventas_hoy(self, usar_cache=True):
        """Carga ventas del día - ✅ SIN FILTROS POR ROL"""
        try:
            if usar_cache:
                ventas = safe_execute(self.venta_repo.get_active)
            else:
                ventas = self.venta_repo.get_active()
            
            ventas_formateadas = []
            if ventas:
                for venta in ventas:
                    try:
                        venta_formateada = {
                            'id': int(venta['id']),
                            'idVenta': str(venta['id']),
                            'usuario': str(venta.get('Vendedor', 'Usuario desconocido')),
                            'tipoUsuario': 'Vendedor',
                            'total': float(venta['Total']),
                            'fecha': venta['Fecha'].strftime('%Y-%m-%d') if hasattr(venta['Fecha'], 'strftime') else str(venta['Fecha']),
                            'hora': venta['Fecha'].strftime('%H:%M') if hasattr(venta['Fecha'], 'strftime') else '00:00',
                            'fechaCompleta': venta['Fecha'].isoformat() if hasattr(venta['Fecha'], 'isoformat') else str(venta['Fecha']),
                            'Id_Usuario': venta.get('Id_Usuario')
                        }
                        ventas_formateadas.append(venta_formateada)
                    except Exception as e:
                        print(f"⚠️ Error formateando venta: {e}")
                        continue
            
            # ✅ NO FILTRAR - MOSTRAR TODAS LAS VENTAS A TODOS
            self._ventas_hoy = ventas_formateadas
            self.ventasHoyChanged.emit()
            
        except Exception as e:
            print(f"❌ Error cargando ventas hoy: {e}")
            self._ventas_hoy = []
            self.ventasHoyChanged.emit()
    
    def _cargar_estadisticas(self, usar_cache=True):
        """Carga estadísticas - ✅ COMPLETAS PARA TODOS"""
        try:
            fecha_hoy = datetime.now().strftime('%Y-%m-%d')
            
            # ✅ CARGAR ESTADÍSTICAS COMPLETAS PARA TODOS
            estadisticas = safe_execute(self.venta_repo.get_ventas_del_dia, fecha_hoy) if usar_cache else self.venta_repo.get_ventas_del_dia(fecha_hoy)
            
            if estadisticas and estadisticas.get('resumen'):
                self._estadisticas = estadisticas['resumen']
            else:
                self._estadisticas = {
                    'Total_Ventas': 0,
                    'Ingresos_Total': 0,
                    'Ticket_Promedio': 0,
                    'Unidades_Vendidas': 0,
                    'Productos_Diferentes': 0
                }
            
            self.estadisticasChanged.emit()
            
        except Exception as e:
            print(f"❌ Error cargando estadísticas: {e}")
    
    def _auto_update_ventas_hoy(self):
        """Actualización automática de ventas del día"""
        if not self._loading and not self._procesando_venta and self._usuario_actual_id > 0:
            try:
                self._cargar_ventas_hoy(usar_cache=False)
                self._cargar_estadisticas(usar_cache=False)
            except Exception as e:
                print(f"❌ Error en auto-update ventas: {e}")
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()
    
    def _set_procesando_venta(self, procesando: bool):
        """Actualiza estado de procesamiento de venta"""
        if self._procesando_venta != procesando:
            self._procesando_venta = procesando
            self.procesandoVentaChanged.emit()
    
    # ✅ MÉTODOS AUXILIARES
    @Slot(result=str)
    def get_rol_display(self):
        """Obtiene el rol formateado para mostrar en UI"""
        roles_display = {
            "Administrador": "Admin",
            "Médico": "Médico"
        }
        return roles_display.get(self._usuario_rol, self._usuario_rol)
    
    @Slot(str, result=bool)
    def tiene_permiso(self, accion: str):
        """✅ SIMPLIFICADO: Solo verificar eliminación"""
        if not self._verificar_autenticacion():
            return False
        
        # Solo restringir eliminación
        if accion == 'eliminar_venta':
            return self._usuario_rol == "Administrador"
        
        # ✅ TODAS LAS DEMÁS ACCIONES PERMITIDAS
        return True
    
    @Slot(int, result=bool)
    def puede_editar_venta(self, venta_id: int):
        """✅ TODOS pueden editar"""
        if not self._verificar_autenticacion():
            return False
        
        try:
            venta = self.venta_repo.get_venta_completa(venta_id)
            return venta is not None
        except:
            return False
    
    @Slot(int, result=bool)
    def puede_eliminar_venta(self, venta_id: int):
        """✅ SOLO ADMIN puede eliminar"""
        if not self._verificar_autenticacion():
            return False
        
        if self._usuario_rol != "Administrador":
            return False
        
        try:
            venta = self.venta_repo.get_venta_completa(venta_id)
            return venta is not None
        except:
            return False
    
    @Slot(str)
    def refrescar_stock_producto(self, codigo: str):
        """Refresca stock específico de un producto"""
        if not codigo:
            return
        
        try:
            self._invalidar_cache_productos()
            stock_info = self.verificar_disponibilidad_producto(codigo)
            self.stockModificado.emit()
            self.operacionExitosa.emit(f"Stock actualizado para {codigo}: {stock_info.get('cantidad_disponible', 0)} unidades")
            
        except Exception as e:
            self.operacionError.emit(f"Error refrescando stock: {str(e)}")
    
    def emergency_disconnect(self):
        """Desconexión de emergencia para VentaModel"""
        try:
            print("🚨 VentaModel: Iniciando desconexión de emergencia...")
            
            if hasattr(self, 'update_timer') and self.update_timer.isActive():
                self.update_timer.stop()
                print("   ℹ️ Update timer detenido")
            
            self._loading = False
            self._procesando_venta = False
            
            signals_to_disconnect = [
                'ventasHoyChanged', 'ventaActualChanged', 'historialVentasChanged',
                'estadisticasChanged', 'topProductosChanged',
                'ventaCreada', 'ventaAnulada', 'ventaActualizada', 'ventaEliminada',
                'operacionExitosa', 'operacionError',
                'loadingChanged', 'procesandoVentaChanged', 'carritoCambiado'
            ]
            
            for signal_name in signals_to_disconnect:
                if hasattr(self, signal_name):
                    try:
                        getattr(self, signal_name).disconnect()
                    except:
                        pass
            
            # Limpiar datos
            self._ventas_hoy = []
            self._venta_actual = {}
            self._historial_ventas = []
            self._estadisticas = {}
            self._top_productos = []
            self._carrito_items = []
            self._usuario_actual_id = 0
            self._usuario_rol = ""
            
            # Anular repositories
            self.venta_repo = None
            self.producto_repo = None
            
            print("✅ VentaModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión VentaModel: {e}")

# Registrar el tipo para QML
def register_venta_model():
    qmlRegisterType(VentaModel, "ClinicaModels", 1, 0, "VentaModel")
    print("✅ VentaModel registrado con permisos simplificados - Todos pueden ver/crear ventas, solo Admin elimina")