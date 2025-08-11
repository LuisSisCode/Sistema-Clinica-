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
    Model QObject para gestión de ventas con integración FIFO
    Conecta directamente con QML mediante Signals/Slots/Properties
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
    operacionExitosa = Signal(str)    # mensaje
    operacionError = Signal(str)      # mensaje_error
    
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
        
        # Configuración
        self._usuario_actual = 0
        
        # Timer para actualización automática
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._auto_update_ventas_hoy)
        self.update_timer.start(60000)  # 1 minuto
        
        # Cargar datos iniciales
        self._cargar_ventas_hoy()
        self._cargar_estadisticas()
        
        print("💰 VentaModel inicializado")
    
    # ===============================
    # PROPERTIES PARA QML
    # ===============================
    
    @Property(list, notify=ventasHoyChanged)
    def ventas_hoy(self):
        """Lista de ventas del día actual"""
        return self._ventas_hoy
    
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
        """Estadísticas de ventas del día"""
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
        """Ingresos totales del día"""
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
    # SLOTS PARA QML - CONFIGURACIÓN
    # ===============================
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """Establece el usuario actual para las ventas"""
        if usuario_id > 0:
            self._usuario_actual = usuario_id
            print(f"👤 Usuario establecido para ventas: {usuario_id}")
    
    @Slot()
    def refresh_ventas_hoy(self):
        """Refresca las ventas del día"""
        self._cargar_ventas_hoy()
    
    @Slot()
    def refresh_estadisticas(self):
        """Refresca las estadísticas"""
        self._cargar_estadisticas()
    
    # ===============================
    # SLOTS PARA QML - CARRITO
    # ===============================
    
    @Slot(str, int, float)
    def agregar_item_carrito(self, codigo: str, cantidad: int, precio_custom: float = 0):
        """Agrega item al carrito de venta"""
        if not codigo or cantidad <= 0:
            self.operacionError.emit("Código o cantidad inválidos")
            return
        
        try:
            # Obtener producto
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
            if not producto:
                raise ProductoNotFoundError(codigo=codigo)
            
            # Verificar disponibilidad
            disponibilidad = safe_execute(
                self.producto_repo.verificar_disponibilidad_fifo,
                producto['id'], cantidad
            )
            
            if not disponibilidad['disponible']:
                raise StockInsuficienteError(
                    codigo, 
                    disponibilidad['cantidad_total_disponible'], 
                    cantidad
                )
            
            # Usar precio personalizado o precio del producto
            precio = precio_custom if precio_custom > 0 else float(producto['Precio_venta'])
            subtotal = cantidad * precio
            
            # Verificar si ya existe en carrito
            item_existente = None
            for item in self._carrito_items:
                if item['codigo'] == codigo.strip():
                    item_existente = item
                    break
            
            if item_existente:
                # Actualizar cantidad existente
                nueva_cantidad = item_existente['cantidad'] + cantidad
                
                # Verificar disponibilidad con nueva cantidad
                nueva_disponibilidad = safe_execute(
                    self.producto_repo.verificar_disponibilidad_fifo,
                    producto['id'], nueva_cantidad
                )
                
                if not nueva_disponibilidad['disponible']:
                    raise StockInsuficienteError(
                        codigo, 
                        nueva_disponibilidad['cantidad_total_disponible'], 
                        nueva_cantidad
                    )
                
                item_existente['cantidad'] = nueva_cantidad
                item_existente['subtotal'] = nueva_cantidad * precio
            else:
                # Agregar nuevo item
                nuevo_item = {
                    'codigo': codigo.strip(),
                    'producto_id': producto['id'],
                    'nombre': producto['Nombre'],
                    'marca': producto.get('Marca_Nombre', ''),
                    'cantidad': cantidad,
                    'precio': precio,
                    'subtotal': subtotal,
                    'stock_disponible': disponibilidad['cantidad_total_disponible']
                }
                self._carrito_items.append(nuevo_item)
            
            self.carritoCambiado.emit()
            self.operacionExitosa.emit(f"Agregado: {cantidad}x {codigo}")
            print(f"🛒 Item agregado - {codigo}: {cantidad}x${precio}")
            
        except Exception as e:
            self.operacionError.emit(f"Error agregando item: {str(e)}")
    
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
        """Actualiza cantidad de un item en carrito"""
        if not codigo or nueva_cantidad < 0:
            return
        
        if nueva_cantidad == 0:
            self.remover_item_carrito(codigo)
            return
        
        try:
            for item in self._carrito_items:
                if item['codigo'] == codigo.strip():
                    # Verificar disponibilidad
                    disponibilidad = safe_execute(
                        self.producto_repo.verificar_disponibilidad_fifo,
                        item['producto_id'], nueva_cantidad
                    )
                    
                    if not disponibilidad['disponible']:
                        raise StockInsuficienteError(
                            codigo, 
                            disponibilidad['cantidad_total_disponible'], 
                            nueva_cantidad
                        )
                    
                    item['cantidad'] = nueva_cantidad
                    item['subtotal'] = nueva_cantidad * item['precio']
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
    # SLOTS PARA QML - VENTAS
    # ===============================
    
    @Slot(result=bool)
    def procesar_venta_carrito(self):
        """Procesa la venta con los items del carrito"""
        if not self._carrito_items:
            self.operacionError.emit("Carrito vacío")
            return False
        
        if self._usuario_actual <= 0:
            self.operacionError.emit("Usuario no establecido")
            return False
        
        self._set_procesando_venta(True)
        
        try:
            # Preparar items para venta
            items_venta = []
            for item in self._carrito_items:
                items_venta.append({
                    'codigo': item['codigo'],
                    'cantidad': item['cantidad'],
                    'precio': item['precio']
                })
            
            # Procesar venta
            venta = safe_execute(
                self.venta_repo.crear_venta, 
                self._usuario_actual, 
                items_venta
            )
            
            if venta:
                # Limpiar carrito
                self.limpiar_carrito()
                
                # Actualizar datos
                self._cargar_ventas_hoy()
                self._cargar_estadisticas()
                
                # Establecer venta actual
                self._venta_actual = venta
                self.ventaActualChanged.emit()
                
                # Emitir signals
                self.ventaCreada.emit(venta['id'], float(venta['Total']))
                self.operacionExitosa.emit(f"Venta procesada: ${venta['Total']:.2f}")
                
                print(f"✅ Venta exitosa - ID: {venta['id']}, Total: ${venta['Total']}")
                return True
            else:
                raise VentaError("Error procesando venta")
                
        except Exception as e:
            self.operacionError.emit(f"Error en venta: {str(e)}")
            return False
        finally:
            self._set_procesando_venta(False)
    
    @Slot(str, int, int, result=bool)
    def venta_rapida(self, codigo: str, cantidad: int, usuario_id: int = 0):
        """Venta rápida de un producto sin usar carrito"""
        if not codigo or cantidad <= 0:
            self.operacionError.emit("Parámetros inválidos")
            return False
        
        usuario = usuario_id if usuario_id > 0 else self._usuario_actual
        if usuario <= 0:
            self.operacionError.emit("Usuario no establecido")
            return False
        
        self._set_procesando_venta(True)
        
        try:
            # Obtener producto
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
            if not producto:
                raise ProductoNotFoundError(codigo=codigo)
            
            # Crear item de venta
            items = [{
                'codigo': codigo.strip(),
                'cantidad': cantidad,
                'precio': float(producto['Precio_venta'])
            }]
            
            # Procesar venta
            venta = safe_execute(self.venta_repo.crear_venta, usuario, items)
            
            if venta:
                self._cargar_ventas_hoy()
                self._cargar_estadisticas()
                
                self.ventaCreada.emit(venta['id'], float(venta['Total']))
                self.operacionExitosa.emit(f"Venta rápida: ${venta['Total']:.2f}")
                
                return True
            else:
                raise VentaError("Error en venta rápida")
                
        except Exception as e:
            self.operacionError.emit(f"Error en venta rápida: {str(e)}")
            return False
        finally:
            self._set_procesando_venta(False)
    
    @Slot(int, result=bool)
    def anular_venta(self, venta_id: int):
        """Anula una venta existente"""
        if venta_id <= 0:
            self.operacionError.emit("ID de venta inválido")
            return False
        
        self._set_loading(True)
        
        try:
            success = safe_execute(
                self.venta_repo.anular_venta, 
                venta_id, 
                "Anulación desde interfaz"
            )
            
            if success:
                self._cargar_ventas_hoy()
                self._cargar_estadisticas()
                
                self.ventaAnulada.emit(venta_id, "Anulación exitosa")
                self.operacionExitosa.emit(f"Venta {venta_id} anulada")
                
                return True
            else:
                raise VentaError("Error anulando venta")
                
        except Exception as e:
            self.operacionError.emit(f"Error anulando venta: {str(e)}")
            return False
        finally:
            self._set_loading(False)
    
    # ===============================
    # SLOTS PARA QML - CONSULTAS
    # ===============================
    
    @Slot(int, result='QVariant')
    def get_venta_detalle(self, venta_id: int):
        """Obtiene detalle completo de una venta"""
        if venta_id <= 0:
            return {}
        
        try:
            venta = safe_execute(self.venta_repo.get_venta_completa, venta_id)
            return venta if venta else {}
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo venta: {str(e)}")
            return {}
    
    @Slot(str, str)
    def cargar_historial(self, fecha_desde: str, fecha_hasta: str):
        """Carga historial de ventas por período"""
        self._set_loading(True)
        
        try:
            if fecha_desde and fecha_hasta:
                ventas = safe_execute(
                    self.venta_repo.get_ventas_con_detalles,
                    fecha_desde, fecha_hasta
                )
            else:
                # Últimos 7 días por defecto
                fecha_desde = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
                ventas = safe_execute(
                    self.venta_repo.get_ventas_con_detalles,
                    fecha_desde, None
                )
            
            self._historial_ventas = ventas or []
            self.historialVentasChanged.emit()
            
            print(f"📊 Historial cargado: {len(self._historial_ventas)} ventas")
            
        except Exception as e:
            self.operacionError.emit(f"Error cargando historial: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot(int)
    def cargar_top_productos(self, dias: int = 30):
        """Carga top productos más vendidos"""
        try:
            productos = safe_execute(
                self.venta_repo.get_top_productos_vendidos, 
                dias, 10
            )
            self._top_productos = productos or []
            self.topProductosChanged.emit()
            
        except Exception as e:
            self.operacionError.emit(f"Error cargando top productos: {str(e)}")
    
    @Slot(str, result='QVariant')
    def get_ventas_por_periodo(self, periodo: str):
        """Obtiene ventas por período (hoy, semana, mes)"""
        try:
            ventas = safe_execute(self.venta_repo.get_ventas_por_periodo, periodo)
            return ventas if ventas else []
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo ventas por período: {str(e)}")
            return []
    
    @Slot(result='QVariant')
    def get_reporte_ingresos(self):
        """Obtiene reporte de ingresos"""
        try:
            reporte = safe_execute(self.venta_repo.get_reporte_ingresos, 30)
            return reporte if reporte else {}
        except Exception as e:
            self.operacionError.emit(f"Error en reporte ingresos: {str(e)}")
            return {}
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_ventas_hoy(self):
        """Carga ventas del día actual"""
        try:
            ventas = safe_execute(self.venta_repo.get_active)
            self._ventas_hoy = ventas or []
            self.ventasHoyChanged.emit()
            
        except Exception as e:
            print(f"❌ Error cargando ventas hoy: {e}")
    
    def _cargar_estadisticas(self):
        """Carga estadísticas del día"""
        try:
            fecha_hoy = datetime.now().strftime('%Y-%m-%d')
            estadisticas = safe_execute(self.venta_repo.get_ventas_del_dia, fecha_hoy)
            
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
        if not self._loading and not self._procesando_venta:
            try:
                self._cargar_ventas_hoy()
                self._cargar_estadisticas()
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

# Registrar el tipo para QML
def register_venta_model():
    qmlRegisterType(VentaModel, "ClinicaModels", 1, 0, "VentaModel")