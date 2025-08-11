from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtQml import qmlRegisterType
from typing import List, Dict, Any, Optional
import json
from datetime import datetime, timedelta

from ..repositories.producto_repository import ProductoRepository
from ..repositories.venta_repository import VentaRepository
from ..repositories.compra_repository import CompraRepository
from ..core.excepciones import (
    ProductoNotFoundError, StockInsuficienteError, VentaError, CompraError,
    ExceptionHandler, safe_execute
)

class InventarioModel(QObject):
    """
    Model QObject para inventario de farmacia con FIFO automático
    Conecta directamente con QML mediante Signals/Slots/Properties
    """
    
    # ===============================
    # SIGNALS PARA QML
    # ===============================
    
    # Signals de datos
    productosChanged = Signal()
    lotesChanged = Signal()
    marcasChanged = Signal()
    proveedoresChanged = Signal()
    
    # Signals de notificaciones
    stockBajoAlert = Signal(str, int)  # codigo, stock_actual
    productoVencidoAlert = Signal(str, str)  # codigo, fecha_vencimiento
    operacionExitosa = Signal(str)  # mensaje
    operacionError = Signal(str)   # mensaje_error
    
    # Signals de estados
    loadingChanged = Signal()
    searchResultsChanged = Signal()
    alertasChanged = Signal()
    
    def __init__(self):
        super().__init__()
        
        # Repositories
        self.producto_repo = ProductoRepository()
        self.venta_repo = VentaRepository()
        self.compra_repo = CompraRepository()
        
        # Datos internos
        self._productos = []
        self._lotes_activos = []
        self._marcas = []
        self._proveedores = []
        self._search_results = []
        self._alertas = []
        self._loading = False
        
        # Timer para actualización automática
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._auto_update)
        self.update_timer.start(30000)  # 30 segundos
        
        # Cargar datos iniciales
        self._cargar_datos_iniciales()
        
        print("🏪 InventarioModel inicializado con auto-refresh")
    
    # ===============================
    # PROPERTIES PARA QML
    # ===============================
    
    @Property(list, notify=productosChanged)
    def productos(self):
        """Lista de productos con stock"""
        return self._productos
    
    @Property(list, notify=lotesChanged)
    def lotes_activos(self):
        """Lista de lotes activos"""
        return self._lotes_activos
    
    @Property(list, notify=marcasChanged)
    def marcas(self):
        """Lista de marcas disponibles"""
        return self._marcas
    
    @Property(list, notify=proveedoresChanged)
    def proveedores(self):
        """Lista de proveedores"""
        return self._proveedores
    
    @Property(list, notify=searchResultsChanged)
    def search_results(self):
        """Resultados de búsqueda"""
        return self._search_results
    
    @Property(list, notify=alertasChanged)
    def alertas(self):
        """Lista de alertas (stock bajo, vencimientos)"""
        return self._alertas
    
    @Property(bool, notify=loadingChanged)
    def loading(self):
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=productosChanged)
    def total_productos(self):
        """Total de productos"""
        return len(self._productos)
    
    @Property(int, notify=alertasChanged)
    def total_alertas(self):
        """Total de alertas"""
        return len(self._alertas)
    
    # ===============================
    # SLOTS PARA QML - CONSULTAS
    # ===============================
    
    @Slot()
    def refresh_productos(self):
        """Refresca la lista de productos"""
        self._set_loading(True)
        try:
            self._productos = safe_execute(self.producto_repo.get_productos_con_marca)
            self.productosChanged.emit()
            self.operacionExitosa.emit("Productos actualizados")
            print(f"🔄 Productos refrescados: {len(self._productos)}")
        except Exception as e:
            self.operacionError.emit(f"Error actualizando productos: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot(str)
    def buscar_productos(self, termino: str):
        """Busca productos por nombre o código"""
        if not termino or len(termino.strip()) < 2:
            self._search_results = []
            self.searchResultsChanged.emit()
            return
        
        try:
            self._search_results = safe_execute(
                self.producto_repo.buscar_productos, 
                termino.strip(), 
                True  # incluir_sin_stock
            )
            self.searchResultsChanged.emit()
            print(f"🔍 Búsqueda '{termino}': {len(self._search_results)} resultados")
        except Exception as e:
            self.operacionError.emit(f"Error en búsqueda: {str(e)}")
    
    @Slot(str, result='QVariant')
    def get_producto_by_codigo(self, codigo: str):
        """Obtiene producto específico por código"""
        if not codigo:
            return {}
        
        try:
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
            return producto if producto else {}
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo producto: {str(e)}")
            return {}
    
    @Slot(int, result='QVariant')
    def get_lotes_producto(self, producto_id: int):
        """Obtiene lotes de un producto específico"""
        if producto_id <= 0:
            return []
        
        try:
            lotes = safe_execute(self.producto_repo.get_lotes_producto, producto_id, True)
            return lotes if lotes else []
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo lotes: {str(e)}")
            return []
    
    @Slot(int, int, result='QVariant')
    def verificar_disponibilidad(self, producto_id: int, cantidad: int):
        """Verifica disponibilidad FIFO para una cantidad"""
        if producto_id <= 0 or cantidad <= 0:
            return {'disponible': False, 'error': 'Parámetros inválidos'}
        
        try:
            disponibilidad = safe_execute(
                self.producto_repo.verificar_disponibilidad_fifo,
                producto_id, cantidad
            )
            return disponibilidad
        except Exception as e:
            self.operacionError.emit(f"Error verificando disponibilidad: {str(e)}")
            return {'disponible': False, 'error': str(e)}
    
    # ===============================
    # SLOTS PARA QML - VENTAS
    # ===============================
    
    @Slot(int, str, result=bool)
    def procesar_venta_rapida(self, usuario_id: int, items_json: str):
        """
        Procesa venta rápida desde QML
        
        Args:
            usuario_id: ID del usuario vendedor
            items_json: JSON string con items [{'codigo': str, 'cantidad': int, 'precio': float}]
        """
        if usuario_id <= 0 or not items_json:
            self.operacionError.emit("Datos de venta inválidos")
            return False
        
        self._set_loading(True)
        try:
            # Parsear items JSON
            items = json.loads(items_json)
            if not items:
                raise VentaError("No hay items para vender")
            
            # Procesar venta
            venta = safe_execute(self.venta_repo.crear_venta, usuario_id, items)
            
            if venta:
                # Actualizar datos
                self.refresh_productos()
                self._actualizar_alertas()
                
                self.operacionExitosa.emit(f"Venta procesada: ID {venta['id']}, Total: ${venta['Total']:.2f}")
                print(f"💰 Venta exitosa - ID: {venta['id']}, Items: {len(items)}")
                return True
            else:
                raise VentaError("Error procesando venta")
                
        except json.JSONDecodeError:
            self.operacionError.emit("Error: Formato de datos inválido")
        except Exception as e:
            self.operacionError.emit(f"Error en venta: {str(e)}")
        finally:
            self._set_loading(False)
        
        return False
    
    @Slot(str, int, int, result=bool)
    def venta_producto_simple(self, codigo: str, cantidad: int, usuario_id: int):
        """Venta simple de un producto"""
        if not codigo or cantidad <= 0 or usuario_id <= 0:
            self.operacionError.emit("Parámetros de venta inválidos")
            return False
        
        try:
            # Obtener producto y precio
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
            return self.procesar_venta_rapida(usuario_id, json.dumps(items))
            
        except Exception as e:
            self.operacionError.emit(f"Error en venta simple: {str(e)}")
            return False
    
    # ===============================
    # SLOTS PARA QML - COMPRAS
    # ===============================
    
    @Slot(int, int, str, result=bool)
    def procesar_compra(self, proveedor_id: int, usuario_id: int, items_json: str):
        """
        Procesa compra desde QML
        
        Args:
            proveedor_id: ID del proveedor
            usuario_id: ID del usuario comprador
            items_json: JSON con items [{'codigo': str, 'cantidad_caja': int, 'cantidad_unitario': int, 
                                        'precio_unitario': float, 'fecha_vencimiento': str}]
        """
        if proveedor_id <= 0 or usuario_id <= 0 or not items_json:
            self.operacionError.emit("Datos de compra inválidos")
            return False
        
        self._set_loading(True)
        try:
            # Parsear items JSON
            items = json.loads(items_json)
            if not items:
                raise CompraError("No hay items para comprar")
            
            # Procesar compra
            compra = safe_execute(self.compra_repo.crear_compra, proveedor_id, usuario_id, items)
            
            if compra:
                # Actualizar datos
                self.refresh_productos()
                self._cargar_lotes_activos()
                
                self.operacionExitosa.emit(f"Compra procesada: ID {compra['id']}, Total: ${compra['Total']:.2f}")
                print(f"📦 Compra exitosa - ID: {compra['id']}, Items: {len(items)}")
                return True
            else:
                raise CompraError("Error procesando compra")
                
        except json.JSONDecodeError:
            self.operacionError.emit("Error: Formato de datos de compra inválido")
        except Exception as e:
            self.operacionError.emit(f"Error en compra: {str(e)}")
        finally:
            self._set_loading(False)
        
        return False
    
    @Slot(str, result=int)
    def crear_proveedor_rapido(self, nombre: str, direccion: str = ""):
        """Crea proveedor rápidamente"""
        if not nombre:
            self.operacionError.emit("Nombre de proveedor requerido")
            return 0
        
        try:
            proveedor_id = safe_execute(
                self.compra_repo.crear_proveedor, 
                nombre.strip(), 
                direccion.strip() or "No especificada"
            )
            
            if proveedor_id:
                # Actualizar lista de proveedores
                self._cargar_proveedores()
                self.operacionExitosa.emit(f"Proveedor creado: {nombre}")
                return proveedor_id
            else:
                raise CompraError("Error creando proveedor")
                
        except Exception as e:
            self.operacionError.emit(f"Error creando proveedor: {str(e)}")
            return 0
    
    # ===============================
    # SLOTS PARA QML - ALERTAS
    # ===============================
    
    @Slot()
    def actualizar_alertas(self):
        """Actualiza alertas de stock y vencimientos"""
        self._actualizar_alertas()
    
    @Slot(int)
    def configurar_stock_minimo(self, stock_minimo: int):
        """Configura el stock mínimo para alertas"""
        if stock_minimo < 0:
            stock_minimo = 10
        
        try:
            productos_bajo_stock = safe_execute(
                self.producto_repo.get_productos_bajo_stock, 
                stock_minimo
            )
            
            # Emitir alertas individuales
            for producto in productos_bajo_stock:
                self.stockBajoAlert.emit(
                    producto['Codigo'], 
                    producto['Stock_Total']
                )
            
            print(f"⚠️ Stock bajo: {len(productos_bajo_stock)} productos")
            
        except Exception as e:
            self.operacionError.emit(f"Error verificando stock: {str(e)}")
    
    @Slot(int)
    def verificar_vencimientos(self, dias_adelante: int = 90):
        """Verifica productos por vencer"""
        try:
            lotes_por_vencer = safe_execute(
                self.producto_repo.get_lotes_por_vencer, 
                dias_adelante
            )
            
            # Emitir alertas de vencimiento
            for lote in lotes_por_vencer:
                self.productoVencidoAlert.emit(
                    lote['Codigo'],
                    lote['Fecha_Vencimiento']
                )
            
            print(f"⏰ Por vencer: {len(lotes_por_vencer)} lotes")
            
        except Exception as e:
            self.operacionError.emit(f"Error verificando vencimientos: {str(e)}")
    
    # ===============================
    # SLOTS PARA QML - REPORTES
    # ===============================
    
    @Slot(result='QVariant')
    def get_reporte_vencimientos(self):
        """Obtiene reporte completo de vencimientos"""
        try:
            reporte = safe_execute(self.producto_repo.get_reporte_vencimientos, 180)
            return reporte if reporte else {}
        except Exception as e:
            self.operacionError.emit(f"Error en reporte vencimientos: {str(e)}")
            return {}
    
    @Slot(result='QVariant')
    def get_valor_inventario(self):
        """Obtiene valor total del inventario"""
        try:
            valor = safe_execute(self.producto_repo.get_valor_inventario)
            return valor if valor else {}
        except Exception as e:
            self.operacionError.emit(f"Error calculando valor inventario: {str(e)}")
            return {}
    
    @Slot(int, result='QVariant')
    def get_productos_mas_vendidos(self, dias: int = 30):
        """Obtiene productos más vendidos"""
        try:
            productos = safe_execute(self.producto_repo.get_productos_mas_vendidos, dias)
            return productos if productos else []
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo más vendidos: {str(e)}")
            return []
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga datos iniciales al crear el model"""
        self._set_loading(True)
        try:
            self._productos = safe_execute(self.producto_repo.get_productos_con_marca) or []
            self._marcas = safe_execute(self._cargar_marcas) or []
            self._proveedores = safe_execute(self.compra_repo.get_proveedores_activos) or []
            self._cargar_lotes_activos()
            self._actualizar_alertas()
            
            print(f"📊 Datos iniciales cargados - Productos: {len(self._productos)}")
            
            # Emitir signals de cambio
            self.productosChanged.emit()
            self.marcasChanged.emit()
            self.proveedoresChanged.emit()
            
        except Exception as e:
            print(f"❌ Error cargando datos iniciales: {e}")
            self.operacionError.emit(f"Error cargando datos: {str(e)}")
        finally:
            self._set_loading(False)
    
    def _cargar_marcas(self):
        """Carga lista de marcas"""
        query = "SELECT * FROM Marca ORDER BY Nombre"
        return self.producto_repo._execute_query(query)
    
    def _cargar_lotes_activos(self):
        """Carga lotes activos"""
        try:
            query = """
            SELECT l.*, p.Codigo, p.Nombre as Producto_Nombre,
                   (l.Cantidad_Caja + l.Cantidad_Unitario) as Stock_Lote
            FROM Lote l
            INNER JOIN Productos p ON l.Id_Producto = p.id
            WHERE (l.Cantidad_Caja + l.Cantidad_Unitario) > 0
            ORDER BY l.Fecha_Vencimiento ASC
            """
            self._lotes_activos = self.producto_repo._execute_query(query) or []
            self.lotesChanged.emit()
        except Exception as e:
            print(f"❌ Error cargando lotes activos: {e}")
    
    def _cargar_proveedores(self):
        """Recarga lista de proveedores"""
        try:
            self._proveedores = safe_execute(self.compra_repo.get_proveedores_activos) or []
            self.proveedoresChanged.emit()
        except Exception as e:
            print(f"❌ Error cargando proveedores: {e}")
    
    def _actualizar_alertas(self):
        """Actualiza lista de alertas"""
        try:
            alertas = []
            
            # Alertas de stock bajo
            productos_bajo_stock = safe_execute(
                self.producto_repo.get_productos_bajo_stock, 10
            ) or []
            
            for producto in productos_bajo_stock:
                alertas.append({
                    'tipo': 'stock_bajo',
                    'codigo': producto['Codigo'],
                    'mensaje': f"Stock bajo: {producto['Stock_Total']} unidades",
                    'prioridad': 'media'
                })
            
            # Alertas de vencimiento
            lotes_por_vencer = safe_execute(
                self.producto_repo.get_lotes_por_vencer, 30
            ) or []
            
            for lote in lotes_por_vencer:
                alertas.append({
                    'tipo': 'vencimiento',
                    'codigo': lote['Codigo'],
                    'mensaje': f"Vence: {lote['Fecha_Vencimiento']} ({lote['Dias_Para_Vencer']} días)",
                    'prioridad': 'alta' if lote['Dias_Para_Vencer'] <= 7 else 'media'
                })
            
            self._alertas = alertas
            self.alertasChanged.emit()
            
        except Exception as e:
            print(f"❌ Error actualizando alertas: {e}")
    
    def _auto_update(self):
        """Actualización automática periódica"""
        if not self._loading:
            try:
                # Solo actualizar alertas en background
                self._actualizar_alertas()
            except Exception as e:
                print(f"❌ Error en auto-update: {e}")
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()

# Registrar el tipo para QML
def register_inventario_model():
    qmlRegisterType(InventarioModel, "ClinicaModels", 1, 0, "InventarioModel")