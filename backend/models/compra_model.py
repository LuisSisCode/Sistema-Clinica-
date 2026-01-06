"""
CompraModel - VERSIÓN 2.0 SIMPLIFICADA
✅ CAMBIOS:
- Precio TOTAL en lugar de precio unitario
- Sin cálculos de márgenes ni ganancias
- Soporte para actualizar precio_venta en compras
- Validación de edición de lotes
"""

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer, Qt
from PySide6.QtQml import qmlRegisterType
from typing import List, Dict, Any, Optional
import json
from datetime import datetime, timedelta
from decimal import Decimal

from ..repositories.compra_repository import CompraRepository
from ..repositories.producto_repository import ProductoRepository
from ..core.excepciones import (
    CompraError, ProductoNotFoundError, ValidationError,
    ExceptionHandler, safe_execute, validate_required
)

class CompraModel(QObject):
    """
    Model QObject para gestión de compras - VERSIÓN 2.0 SIMPLIFICADA
    ✅ Sin márgenes, con precio total y actualización de precio_venta
    """
    
    # ===============================
    # SIGNALS PARA QML
    # ===============================
    
    # Signals de datos
    comprasRecientesChanged = Signal()
    compraActualChanged = Signal()
    proveedoresChanged = Signal()
    historialComprasChanged = Signal()
    estadisticasChanged = Signal()
    topProductosCompradosChanged = Signal()
    
    # Signals de operaciones
    compraCreada = Signal(int, float)  # compra_id, total
    compraActualizada = Signal(int, float)  # compra_id, total
    proveedorCreado = Signal(int, str)  # proveedor_id, nombre
    operacionExitosa = Signal(str)     # mensaje
    operacionError = Signal(str)       # mensaje_error
    
    # Signals de estados
    loadingChanged = Signal()
    procesandoCompraChanged = Signal()
    itemsCompraCambiado = Signal()
    modoEdicionChanged = Signal()
    datosOriginalesChanged = Signal()
    
    # Signals para proveedores
    proveedorCompraCompletada = Signal(int, float)
    proveedorDatosActualizados = Signal()
    filtrosChanged = Signal()
    
    def __init__(self):
        super().__init__()
        
        # Repositories
        self.compra_repo = CompraRepository()
        self.producto_repo = ProductoRepository()
        
        # Datos internos
        self._compras_recientes = []
        self._compra_actual = {}
        self._proveedores = []
        self._historial_compras = []
        self._estadisticas = {}
        self._top_productos_comprados = []
        self._items_compra = []
        self._loading = False
        self._procesando_compra = False

        self._modo_edicion = False
        self._compra_id_edicion = 0
        self._datos_originales = {}
        self._items_originales = []
        
        # AUTENTICACIÓN
        self._usuario_actual_id = 0
        print("📦 CompraModel v2.0 inicializado - Esperando autenticación")
        
        # Configuración
        self._proveedor_seleccionado = 0
        
        # Timer para actualización automática
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._auto_update_compras)
        self.update_timer.start(120000)  # 2 minutos
        
        # Cargar datos iniciales
        self._cargar_compras_recientes()
        self._cargar_proveedores()
        self._cargar_estadisticas()
        print("📦 CompraModel v2.0 inicializado - Sin márgenes")
    
    # ===============================
    # AUTENTICACIÓN
    # ===============================
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """Establece el usuario actual para las operaciones"""
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario autenticado en CompraModel: {usuario_id}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de compras")
            else:
                print(f"⚠️ ID de usuario inválido: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario: {e}")
            self.operacionError.emit(f"Error: {str(e)}")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        """Property para obtener el usuario actual"""
        return self._usuario_actual_id
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica si el usuario está autenticado"""
        if self._usuario_actual_id <= 0:
            self.operacionError.emit("Usuario no autenticado")
            return False
        return True
    
    # ===============================
    # PROPERTIES PARA QML
    # ===============================
    
    @Property(list, notify=comprasRecientesChanged)
    def compras_recientes(self):
        """Lista de compras recientes"""
        return self._compras_recientes
    
    @Property('QVariant', notify=compraActualChanged)
    def compra_actual(self):
        """Compra actualmente seleccionada/en proceso"""
        return self._compra_actual
    
    @Property(list, notify=proveedoresChanged)
    def proveedores(self):
        """Lista de proveedores activos"""
        return self._proveedores
    
    @Property(list, notify=historialComprasChanged)
    def historial_compras(self):
        """Historial de compras"""
        return self._historial_compras
    
    @Property('QVariant', notify=estadisticasChanged)
    def estadisticas(self):
        """Estadísticas de compras del mes"""
        return self._estadisticas
    
    @Property(list, notify=topProductosCompradosChanged)
    def top_productos_comprados(self):
        """Top productos más comprados"""
        return self._top_productos_comprados
    
    @Property(list, notify=itemsCompraCambiado)
    def items_compra(self):
        """Items en la compra actual"""
        return self._items_compra
    
    @Property(bool, notify=loadingChanged)
    def loading(self):
        """Estado de carga general"""
        return self._loading
    
    @Property(bool, notify=procesandoCompraChanged)
    def procesando_compra(self):
        """Estado de procesamiento de compra"""
        return self._procesando_compra
    
    @Property(int, notify=comprasRecientesChanged)
    def total_compras_mes(self):
        """Total de compras del mes"""
        return len(self._compras_recientes)
    
    @Property(float, notify=estadisticasChanged)
    def gastos_mes(self):
        """Gastos totales del mes"""
        return float(self._estadisticas.get('Gastos_Total', 0))
    
    @Property(float, notify=itemsCompraCambiado)
    def total_compra_actual(self):
        """Total de la compra actual"""
        return sum(float(item.get('subtotal', 0)) for item in self._items_compra)
    
    @Property(int, notify=itemsCompraCambiado)
    def items_en_compra(self):
        """Cantidad de items en compra actual"""
        return len(self._items_compra)
    
    @Property(int, notify=proveedoresChanged)
    def total_proveedores(self):
        """Total de proveedores activos"""
        return len(self._proveedores)
    
    @Property(bool, notify=modoEdicionChanged)
    def modo_edicion(self):
        """Indica si está en modo edición"""
        return self._modo_edicion
    
    @Property(int, notify=modoEdicionChanged)
    def compra_id_edicion(self):
        """ID de la compra en edición"""
        return self._compra_id_edicion
    
    @Property('QVariant', notify=datosOriginalesChanged)
    def datos_originales(self):
        """Datos originales para comparación"""
        return self._datos_originales
    
    # ===============================
    # SLOTS DE CARGA DE DATOS
    # ===============================
    
    def _cargar_compras_recientes(self):
        """Carga compras del mes actual"""
        try:
            compras = safe_execute(self.compra_repo.get_active) or []
            self._compras_recientes = compras
            self.comprasRecientesChanged.emit()
            print(f"📦 Compras recientes cargadas: {len(compras)}")
        except Exception as e:
            print(f"❌ Error cargando compras: {e}")
    
    def _cargar_proveedores(self):
        """Carga lista de proveedores"""
        try:
            # Importar aquí para evitar circular import
            from ..repositories.proveedor_repository import ProveedorRepository
            proveedor_repo = ProveedorRepository()
            
            proveedores = safe_execute(proveedor_repo.get_active) or []
            self._proveedores = proveedores
            self.proveedoresChanged.emit()
            print(f"🏢 Proveedores cargados: {len(proveedores)}")
        except Exception as e:
            print(f"❌ Error cargando proveedores: {e}")
    
    def _cargar_estadisticas(self):
        """Carga estadísticas del mes"""
        try:
            stats = safe_execute(self.compra_repo.get_estadisticas_mes) or {}
            self._estadisticas = stats
            self.estadisticasChanged.emit()
            print(f"📊 Estadísticas cargadas: {stats}")
        except Exception as e:
            print(f"❌ Error cargando estadísticas: {e}")
    
    def _auto_update_compras(self):
        """Actualización automática periódica"""
        try:
            self._cargar_compras_recientes()
            self._cargar_estadisticas()
        except Exception as e:
            print(f"⚠️ Error en auto-update: {e}")
    
    # ===============================
    # SLOTS PRINCIPALES - VERSIÓN 2.0
    # ===============================
    
    @Slot(str, result='QVariant')
    def buscar_producto(self, termino: str):
        """
        Busca productos disponibles para agregar a compra
        """
        if not termino or len(termino) < 2:
            return []
        
        try:
            productos = safe_execute(
                self.producto_repo.buscar_productos,
                termino,
                incluir_sin_stock=True
            ) or []
            
            print(f"🔍 Búsqueda '{termino}': {len(productos)} productos encontrados (FIFO habilitado)")
            return productos
            
        except Exception as e:
            print(f"❌ Error buscando producto: {e}")
            return []
    
    @Slot(str, result='QVariant')
    def obtener_datos_precio_producto(self, codigo: str):
        """
        ✅ VERSIÓN 2.0: Obtiene datos de un producto para determinar si es primera compra
        
        Returns:
            {
                'Precio_Venta': float,
                'es_primera': bool,  # True si no tiene stock
                'tiene_stock': bool,
                'stock_actual': int,
                'codigo': str,
                'nombre': str
            }
        """
        try:
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo)
            
            if not producto:
                self.operacionError.emit(f"Producto no encontrado: {codigo}")
                return None
            
            stock_actual = producto.get('Stock_Total', 0) or producto.get('Stock_Unitario', 0)
            es_primera = stock_actual == 0
            
            resultado = {
                'Precio_Venta': producto.get('Precio_venta', 0.0),
                'es_primera': es_primera,
                'tiene_stock': stock_actual > 0,
                'stock_actual': stock_actual,
                'codigo': codigo,
                'nombre': producto.get('Nombre', '')
            }
            
            print(f"💰 Datos precio producto {producto['id']}: {resultado}")
            
            return resultado
            
        except Exception as e:
            print(f"❌ Error obteniendo datos precio: {e}")
            return None
    
    @Slot(str, int, float, float, str)
    def agregar_item_compra(self, codigo: str, cantidad: int, precio_total: float,
                           precio_venta: float, fecha_vencimiento: str = ""):
        """
        ✅ VERSIÓN 2.0: Agrega item a compra con PRECIO TOTAL
        
        Args:
            codigo: Código del producto
            cantidad: Cantidad de unidades
            precio_total: Precio TOTAL por todas las unidades
            precio_venta: Precio de venta del producto (para actualizar)
            fecha_vencimiento: Fecha vencimiento (opcional)
        """
        if not codigo:
            self.operacionError.emit("Código de producto requerido")
            return
        
        if cantidad <= 0:
            self.operacionError.emit("Cantidad debe ser mayor a 0")
            return
        
        if precio_total <= 0:
            self.operacionError.emit("Precio total debe ser mayor a 0")
            return
        
        if precio_venta <= 0:
            self.operacionError.emit("Precio de venta debe ser mayor a 0")
            return
        
        try:
            # Calcular precio unitario
            precio_unitario = precio_total / cantidad
            
            # Verificar que el producto existe
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo)
            if not producto:
                self.operacionError.emit(f"Producto no encontrado: {codigo}")
                return
            
            # Validar fecha si se proporciona
            fecha_procesada = fecha_vencimiento.strip() if fecha_vencimiento else ""
            if fecha_procesada and not self._validar_fecha_formato(fecha_procesada):
                self.operacionError.emit("Fecha debe ser formato YYYY-MM-DD o vacía")
                return
            
            # Crear item
            item = {
                'codigo': codigo,
                'nombre': producto['Nombre'],
                'cantidad_unitario': cantidad,
                'cantidad_total': cantidad,
                'precio_total': precio_total,
                'precio_unitario': precio_unitario,
                'precio_venta': precio_venta,
                'fecha_vencimiento': fecha_procesada if fecha_procesada else None,
                'subtotal': precio_total  # El total ES el subtotal
            }
            
            self._items_compra.append(item)
            self.itemsCompraCambiado.emit()
            
            mensaje = f"Agregado: {codigo} - {cantidad} unidades - Bs{precio_total:.2f} (Bs{precio_unitario:.2f} c/u)"
            self.operacionExitosa.emit(mensaje)
            
            print(f"✅ {mensaje}")
            print(f"   Precio venta: Bs{precio_venta:.2f}")
            
        except Exception as e:
            self.operacionError.emit(f"Error agregando item: {str(e)}")
            print(f"❌ Error: {str(e)}")
    
    @Slot(int)
    def eliminar_item_compra(self, index: int):
        """Elimina un item de la compra"""
        if index < 0 or index >= len(self._items_compra):
            self.operacionError.emit(f"Índice inválido: {index}")
            return
        
        item = self._items_compra[index]
        del self._items_compra[index]
        self.itemsCompraCambiado.emit()
        
        self.operacionExitosa.emit(f"Eliminado: {item['codigo']}")
        print(f"🗑️ Item eliminado: {item['codigo']}")
    
    @Slot(int)
    def completar_compra(self, proveedor_id: int):
        """
        ✅ VERSIÓN 2.0: Completa y guarda la compra
        """
        if not self._verificar_autenticacion():
            return
        
        if proveedor_id <= 0:
            self.operacionError.emit("Seleccione un proveedor")
            return
        
        if not self._items_compra:
            self.operacionError.emit("Agregue al menos un producto")
            return
        
        self._set_procesando(True)
        
        try:
            # Preparar items para el repository
            items_repo = []
            for item in self._items_compra:
                items_repo.append({
                    'codigo': item['codigo'],
                    'cantidad_unitario': item['cantidad_unitario'],
                    'precio_total': item['precio_total'],  # ← NUEVO
                    'precio_venta': item.get('precio_venta'),  # ← NUEVO
                    'fecha_vencimiento': item.get('fecha_vencimiento', '')
                })
            
            # Crear compra
            resultado = safe_execute(
                self.compra_repo.crear_compra,
                proveedor_id,
                self._usuario_actual_id,
                items_repo
            )
            
            if resultado and resultado.get('id'):
                compra_id = resultado['id']
                total = resultado.get('Total', 0)
                
                # Limpiar items
                self._items_compra.clear()
                self.itemsCompraCambiado.emit()
                
                # Recargar datos
                self._cargar_compras_recientes()
                self._cargar_estadisticas()
                
                # Emitir señales
                self.compraCreada.emit(compra_id, total)
                self.operacionExitosa.emit(f"Compra #{compra_id} registrada - Bs{total:.2f}")
                
                print(f"✅ Compra completada: #{compra_id} - Bs{total:.2f}")
                return compra_id
            else:
                raise CompraError("Error en procedimiento de compra")
        
        except Exception as e:
            self.operacionError.emit(f"Error: {str(e)}")
            print(f"❌ Error completando compra: {e}")
            return -1
        finally:
            self._set_procesando(False)
    
    @Slot()
    def limpiar_items(self):
        """Limpia todos los items de la compra"""
        self._items_compra.clear()
        self.itemsCompraCambiado.emit()
        print("🧹 Items limpiados")
    
    # ===============================
    # EDICIÓN DE COMPRAS
    # ===============================
    
    @Slot(int, result=bool)
    def iniciar_edicion_compra(self, compra_id: int):
        """Inicia el modo edición para una compra"""
        if not self._verificar_autenticacion():
            return False
        
        if compra_id <= 0:
            self.operacionError.emit("ID de compra inválido")
            return False
        
        try:
            print(f"📝 Iniciando edición de compra {compra_id}")
            
            # Cargar datos completos
            compra_completa = self.get_compra_detalle(compra_id)
            
            if not compra_completa:
                self.operacionError.emit("No se pudo cargar la compra")
                return False
            
            # Establecer modo edición
            self._modo_edicion = True
            self._compra_id_edicion = compra_id
            
            # Guardar datos originales
            self._datos_originales = {
                'id': compra_completa['id'],
                'proveedor': compra_completa['proveedor'],
                'proveedor_id': compra_completa.get('proveedor_id', 0),
                'total': compra_completa['total'],
                'fecha': compra_completa['fecha'],
                'usuario': compra_completa['usuario']
            }
            
            # Guardar items originales
            self._items_originales = []
            for detalle in compra_completa.get('detalles', []):
                self._items_originales.append({
                    'codigo': detalle['codigo'],
                    'nombre': detalle['nombre'],
                    'cantidad_unitario': detalle['cantidad_unitario'],
                    'precio_total': detalle['costo_total'],
                    'fecha_vencimiento': detalle['fecha_vencimiento']
                })
            
            # Cargar items en el modelo actual
            self._items_compra.clear()
            for item in self._items_originales:
                self._items_compra.append({
                    'codigo': item['codigo'],
                    'nombre': item['nombre'],
                    'cantidad_unitario': item['cantidad_unitario'],
                    'cantidad_total': item['cantidad_unitario'],
                    'precio_total': item['precio_total'],
                    'precio_unitario': item['precio_total'] / item['cantidad_unitario'],
                    'fecha_vencimiento': item['fecha_vencimiento'],
                    'subtotal': item['precio_total']
                })
            
            # Establecer proveedor
            self._proveedor_seleccionado = self._datos_originales['proveedor_id']
            
            # Emitir signals
            self.modoEdicionChanged.emit()
            self.datosOriginalesChanged.emit()
            self.itemsCompraCambiado.emit()
            
            self.operacionExitosa.emit(f"Compra #{compra_id} cargada para edición")
            print(f"✅ Compra {compra_id} cargada - {len(self._items_compra)} items")
            
            return True
            
        except Exception as e:
            print(f"❌ Error iniciando edición: {e}")
            self.operacionError.emit(f"Error: {str(e)}")
            return False
    
    @Slot()
    def cancelar_edicion(self):
        """Cancela el modo edición"""
        print("🚫 Cancelando edición de compra")
        
        self._modo_edicion = False
        self._compra_id_edicion = 0
        self._datos_originales = {}
        self._items_originales = []
        self._items_compra.clear()
        self._proveedor_seleccionado = 0
        
        self.modoEdicionChanged.emit()
        self.datosOriginalesChanged.emit()
        self.itemsCompraCambiado.emit()
        
        self.operacionExitosa.emit("Edición cancelada")
    
    # ===============================
    # HELPERS
    # ===============================
    
    def _validar_fecha_formato(self, fecha: str) -> bool:
        """Valida formato YYYY-MM-DD"""
        try:
            datetime.strptime(fecha, '%Y-%m-%d')
            return True
        except ValueError:
            return False
    
    def _set_procesando(self, estado: bool):
        """Actualiza estado de procesamiento"""
        if self._procesando_compra != estado:
            self._procesando_compra = estado
            self.procesandoCompraChanged.emit()
    
    @Slot(int, result='QVariant')
    def get_compra_detalle(self, compra_id: int):
        """Obtiene detalle completo de una compra"""
        try:
            compra = safe_execute(self.compra_repo.get_compra_completa, compra_id)
            
            if compra:
                # Formatear para QML
                resultado = {
                    'id': compra['id'],
                    'fecha': str(compra.get('Fecha', '')),
                    'total': float(compra.get('Total', 0)),
                    'proveedor': compra.get('Proveedor_Nombre', ''),
                    'proveedor_direccion': compra.get('Proveedor_Direccion', ''),
                    'usuario': compra.get('Usuario', ''),
                    'proveedor_id': compra.get('Id_Proveedor', 0),
                    'detalles': []
                }
                
                for det in compra.get('detalles', []):
                    resultado['detalles'].append({
                        'id': det.get('id'),
                        'codigo': det.get('Producto_Codigo', ''),
                        'nombre': det.get('Producto_Nombre', ''),
                        'marca': det.get('Marca_Nombre', ''),
                        'cantidad_unitario': int(det.get('Cantidad_Total', 0)),
                        'precio_unitario_compra': float(det.get('Precio_Unitario_Compra', 0)),
                        'costo_total': float(det.get('Costo_Total', 0)),
                        'precio_venta_actual': float(det.get('Precio_Venta_Actual', 0)),
                        'fecha_vencimiento': str(det.get('Fecha_Vencimiento', ''))
                    })
                
                print(f"📋 Detalle compra {compra_id} obtenido - {len(resultado['detalles'])} items")
                return resultado
            
            return None
            
        except Exception as e:
            print(f"❌ Error obteniendo detalle: {e}")
            return None
    
    @Slot()
    def refresh_proveedores(self):
        """Refresca lista de proveedores"""
        self._cargar_proveedores()
    
    @Slot()
    def refresh_compras(self):
        """Refresca lista de compras"""
        self._cargar_compras_recientes()
        self._cargar_estadisticas()

# Registrar el tipo para QML
def register_compra_model():
    qmlRegisterType(CompraModel, "ClinicaModels", 1, 0, "CompraModel")
    print("🔗 CompraModel v2.0 registrado para QML - Sin márgenes")