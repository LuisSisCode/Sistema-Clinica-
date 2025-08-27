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
    
    CORREGIDO: Manejo consistente de nomenclatura de campos y conversión de datos
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

    # Signals adicionales para el frontend
    stockActualizado = Signal(str, int)  # codigo, nuevo_stock
    productoCreado = Signal(str)         # codigo
    productoEliminado = Signal(str)      # codigo
    precioActualizado = Signal(str, float)  # codigo, nuevo_precio
    
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
            productos_raw = safe_execute(self.producto_repo.get_productos_con_marca) or []
            
            # CORREGIDO: Normalizar productos con nomenclatura consistente
            self._productos = []
            for producto in productos_raw:
                producto_normalizado = self._normalizar_producto(producto)
                self._productos.append(producto_normalizado)
            
            self.productosChanged.emit()
            self.operacionExitosa.emit("Productos actualizados")
            print(f"🔄 Productos refrescados: {len(self._productos)}")
            
        except Exception as e:
            print(f"❌ Error refrescando productos: {e}")
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
            resultados_raw = safe_execute(
                self.producto_repo.buscar_productos, 
                termino.strip(), 
                True  # incluir_sin_stock
            ) or []
            
            # CORREGIDO: Normalizar resultados de búsqueda
            self._search_results = []
            for resultado in resultados_raw:
                resultado_normalizado = self._normalizar_producto(resultado)
                self._search_results.append(resultado_normalizado)
            
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
            producto_raw = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
            if producto_raw:
                producto_normalizado = self._normalizar_producto(producto_raw)
                return producto_normalizado
            return {}
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo producto: {str(e)}")
            return {}
    
    @Slot(int, result='QVariant')
    def get_lotes_producto(self, producto_id: int):
        """Obtiene lotes de un producto específico"""
        if producto_id <= 0:
            return []
        
        try:
            lotes = safe_execute(self.producto_repo.get_lotes_producto, producto_id, True) or []
            # CORREGIDO: Normalizar lotes si es necesario
            return lotes
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
            ) or {'disponible': False, 'error': 'Error en verificación'}
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
    
    @Slot(str, str, result=int)
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
            ) or []
            
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
            ) or []
            
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
            reporte = safe_execute(self.producto_repo.get_reporte_vencimientos, 180) or {}
            return reporte
        except Exception as e:
            self.operacionError.emit(f"Error en reporte vencimientos: {str(e)}")
            return {}
    
    @Slot(result='QVariant')
    def get_valor_inventario(self):
        """Obtiene valor total del inventario"""
        try:
            valor = safe_execute(self.producto_repo.get_valor_inventario) or {}
            return valor
        except Exception as e:
            self.operacionError.emit(f"Error calculando valor inventario: {str(e)}")
            return {}
    
    @Slot(int, result='QVariant')
    def get_productos_mas_vendidos(self, dias: int = 30):
        """Obtiene productos más vendidos"""
        try:
            productos = safe_execute(self.producto_repo.get_productos_mas_vendidos, dias) or []
            return productos
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo más vendidos: {str(e)}")
            return []
    
    # ===============================
    # SLOTS PARA QML - CRUD PRODUCTOS
    # ===============================
    
    @Slot(str, result=bool)
    def crear_producto(self, producto_json: str):
        """
        Crea un nuevo producto desde QML
        
        Args:
            producto_json: JSON string con datos del producto
            {
                'codigo': str,
                'nombre': str,
                'detalles': str,  // CORREGIDO: Usar 'detalles' consistentemente
                'precio_compra': float,
                'precio_venta': float,
                'stock_caja': int,
                'stock_unitario': int,
                'unidad_medida': str,
                'id_marca': int
            }
        """
        if not producto_json:
            self.operacionError.emit("Datos de producto requeridos")
            return False
        
        self._set_loading(True)
        try:
            # Parsear datos JSON
            datos = json.loads(producto_json)
            
            # Validar datos
            if not self._validar_datos_producto(datos):
                return False
            
            # Verificar que el código no exista
            producto_existente = safe_execute(self.producto_repo.get_by_codigo, datos['codigo'])
            if producto_existente:
                raise ValueError(f"El código {datos['codigo']} ya existe")
            
            # CORREGIDO: Preparar datos con nomenclatura de BD
            nuevo_producto = {
                'Codigo': datos['codigo'],
                'Nombre': datos['nombre'],
                'Detalles': datos.get('detalles', ''),  # CORREGIDO: Mapear correctamente
                'Precio_compra': float(datos['precio_compra']),
                'Precio_venta': float(datos['precio_venta']),
                'Stock_Caja': int(datos.get('stock_caja', 0)),
                'Stock_Unitario': int(datos.get('stock_unitario', 0)),
                'Unidad_Medida': datos.get('unidad_medida', 'Tabletas'),
                'ID_Marca': int(datos.get('id_marca', 1)),  # Default marca 1
                'Fecha_Venc': datetime.now().strftime('%Y-%m-%d')
            }
            
            # Insertar producto
            producto_id = safe_execute(self.producto_repo.insert, nuevo_producto)
            
            if producto_id:
                # Crear lote inicial si hay stock
                if nuevo_producto['Stock_Caja'] > 0 or nuevo_producto['Stock_Unitario'] > 0:
                    self._crear_lote_inicial(producto_id, nuevo_producto)
                
                # Refrescar datos
                self.refresh_productos()
                
                self.operacionExitosa.emit(f"Producto creado: {datos['codigo']}")
                self.productoCreado.emit(datos['codigo'])
                print(f"✅ Producto creado - ID: {producto_id}, Código: {datos['codigo']}")
                return True
            else:
                raise Exception("Error creando producto en base de datos")
                
        except json.JSONDecodeError:
            self.operacionError.emit("Error: Formato de datos inválido")
        except ValueError as e:
            self.operacionError.emit(f"Error de validación: {str(e)}")
        except Exception as e:
            self.operacionError.emit(f"Error creando producto: {str(e)}")
        finally:
            self._set_loading(False)
        
        return False
    
    @Slot(str, float, result=bool)
    def actualizar_precio_venta(self, codigo: str, nuevo_precio: float):
        """
        Actualiza el precio de venta de un producto
        
        Args:
            codigo: Código del producto
            nuevo_precio: Nuevo precio de venta
        """
        if not codigo or nuevo_precio <= 0:
            self.operacionError.emit("Código y precio válido requeridos")
            return False
        
        self._set_loading(True)
        try:
            # Obtener producto
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
            if not producto:
                raise ProductoNotFoundError(codigo=codigo)
            
            # Actualizar precio
            datos_actualizacion = {'Precio_venta': nuevo_precio}
            exito = safe_execute(self.producto_repo.update, producto['id'], datos_actualizacion)
            
            if exito:
                # Refrescar datos
                self.refresh_productos()
                
                self.operacionExitosa.emit(f"Precio actualizado: {codigo} - Bs{nuevo_precio:.2f}")
                self.precioActualizado.emit(codigo, nuevo_precio)
                print(f"💰 Precio actualizado - {codigo}: Bs{nuevo_precio:.2f}")
                return True
            else:
                raise Exception("Error actualizando precio en base de datos")
                
        except ProductoNotFoundError:
            self.operacionError.emit(f"Producto no encontrado: {codigo}")
        except Exception as e:
            self.operacionError.emit(f"Error actualizando precio: {str(e)}")
        finally:
            self._set_loading(False)
        
        return False
    
    @Slot(str, int, int, str, float, result=bool)
    def agregar_stock_producto(self, codigo: str, cantidad_caja: int, cantidad_unitario: int, 
                            fecha_vencimiento: str, precio_compra: float = 0):
        """
        Agrega stock a un producto creando un nuevo lote
        
        Args:
            codigo: Código del producto
            cantidad_caja: Cantidad en cajas
            cantidad_unitario: Cantidad unitaria
            fecha_vencimiento: Fecha de vencimiento (YYYY-MM-DD)
            precio_compra: Precio de compra (opcional)
        """
        if not codigo or (cantidad_caja <= 0 and cantidad_unitario <= 0):
            self.operacionError.emit("Código y cantidad válida requeridos")
            return False
        
        self._set_loading(True)
        try:
            # Obtener producto
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
            if not producto:
                raise ProductoNotFoundError(codigo=codigo)
            
            # Validar fecha de vencimiento
            if not fecha_vencimiento:
                fecha_vencimiento = (datetime.now() + timedelta(days=365)).strftime('%Y-%m-%d')
            
            # Crear nuevo lote y aumentar stock
            lote_id = safe_execute(
                self.producto_repo.aumentar_stock_compra,
                producto['id'],
                cantidad_caja,
                cantidad_unitario,
                fecha_vencimiento,
                precio_compra if precio_compra > 0 else None
            )
            
            if lote_id:
                # Refrescar datos
                self.refresh_productos()
                self._cargar_lotes_activos()
                
                total_agregado = cantidad_caja + cantidad_unitario
                self.operacionExitosa.emit(f"Stock agregado: {codigo} (+{total_agregado} unidades)")
                self.stockActualizado.emit(codigo, self.obtener_stock_total_producto(codigo))
                print(f"📈 Stock agregado - {codigo}: +{total_agregado} unidades, Lote: {lote_id}")
                return True
            else:
                raise Exception("Error creando lote de stock")
                
        except ProductoNotFoundError:
            self.operacionError.emit(f"Producto no encontrado: {codigo}")
        except Exception as e:
            self.operacionError.emit(f"Error agregando stock: {str(e)}")
        finally:
            self._set_loading(False)
        
        return False
    
    @Slot(result='QVariant')
    def get_marcas_disponibles(self):
        """Obtiene lista de marcas disponibles para productos - CORREGIDO"""
        try:
            # CORREGIDO: Asegurar que las marcas estén actualizadas
            marcas = self._cargar_marcas() or []
            
            # Actualizar marcas internas si es necesario
            if marcas:
                self._marcas = marcas
                self.marcasChanged.emit()
            
            print(f"🏷️ Marcas disponibles: {len(marcas)}")
            return marcas
        except Exception as e:
            print(f"❌ Error obteniendo marcas: {e}")
            self.operacionError.emit(f"Error obteniendo marcas: {str(e)}")
            return []

    @Slot(str, result='QVariant')
    def get_producto_detalle_completo(self, codigo: str):
        """
        Obtiene detalles completos de un producto incluyendo lotes
        
        Returns:
            {
                'producto': {...},
                'lotes': [...],
                'stock_total': int,
                'valor_inventario': float
            }
        """
        if not codigo:
            return {}
        
        try:
            # Obtener producto
            producto_raw = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
            if not producto_raw:
                return {}
            
            # CORREGIDO: Normalizar producto
            producto = self._normalizar_producto(producto_raw)
            
            # Obtener lotes
            lotes = safe_execute(self.producto_repo.get_lotes_producto, producto['id'], True) or []
            
            # Calcular totales
            stock_total = (producto.get('stockCaja', 0) + producto.get('stockUnitario', 0))
            valor_inventario = stock_total * producto.get('precioCompra', 0)
            
            return {
                'producto': producto,
                'lotes': lotes,
                'stock_total': stock_total,
                'valor_inventario': valor_inventario,
                'lotes_count': len(lotes)
            }
            
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo detalles: {str(e)}")
            return {}
        
    @Slot(result='QVariant')
    def get_estadisticas_inventario(self):
        """Obtiene estadísticas completas del inventario"""
        try:
            # Valor total del inventario
            valor_inventario = safe_execute(self.producto_repo.get_valor_inventario) or {}
                
            # Productos con stock bajo
            productos_bajo_stock = safe_execute(self.producto_repo.get_productos_bajo_stock, 10) or []
                
            # Reporte de vencimientos
            reporte_vencimientos = safe_execute(self.producto_repo.get_reporte_vencimientos, 90) or {}
                
            return {
                'valor_inventario': valor_inventario,
                'productos_bajo_stock': len(productos_bajo_stock),
                'productos_vencidos': len(reporte_vencimientos.get('vencidos', [])),
                'productos_por_vencer': len(reporte_vencimientos.get('por_vencer', [])),
                'total_productos': len(self._productos),
                'alertas_activas': len(self._alertas)
            }
                
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo estadísticas: {str(e)}")
            return {}
    
    # ===============================
    # MÉTODOS PRIVADOS - CORREGIDOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga datos iniciales al crear el model"""
        self._set_loading(True)
        try:
            # CORREGIDO: Cargar y normalizar productos
            productos_raw = safe_execute(self.producto_repo.get_productos_con_marca) or []
            self._productos = []
            for producto in productos_raw:
                producto_normalizado = self._normalizar_producto(producto)
                self._productos.append(producto_normalizado)
            
            self._marcas = self._cargar_marcas() or []
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
        try:
            query = "SELECT * FROM Marca ORDER BY Nombre"
            marcas_raw = self.producto_repo._execute_query(query) or []
            
            # CORREGIDO: Normalizar marcas para QML
            marcas_normalizadas = []
            for marca in marcas_raw:
                marca_normalizada = {
                    'id': marca.get('id', 0),
                    'Nombre': marca.get('Nombre', ''),
                    'nombre': marca.get('Nombre', ''),  # Compatibilidad
                    'Detalles': marca.get('Detalles', ''),
                    'detalles': marca.get('Detalles', '')  # Compatibilidad
                }
                marcas_normalizadas.append(marca_normalizada)
            
            print(f"🏷️ Marcas cargadas desde BD: {len(marcas_normalizadas)}")
            return marcas_normalizadas
            
        except Exception as e:
            print(f"❌ Error cargando marcas: {e}")
            return []
        
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

    def _crear_lote_inicial(self, producto_id: int, datos_producto: dict):
        """Crea lote inicial para producto nuevo con stock"""
        try:
            fecha_vencimiento = (datetime.now() + timedelta(days=365)).strftime('%Y-%m-%d')
            
            lote_data = {
                'Id_Producto': producto_id,
                'Cantidad_Caja': datos_producto.get('Stock_Caja', 0),
                'Cantidad_Unitario': datos_producto.get('Stock_Unitario', 0),
                'Fecha_Vencimiento': fecha_vencimiento
            }
            
            lote_id = self._insert_lote(lote_data)
            print(f"📦 Lote inicial creado - ID: {lote_id}")
            
        except Exception as e:
            print(f"⚠️ Error creando lote inicial: {e}")

    def _insert_lote(self, lote_data: dict) -> int:
        """Método auxiliar para crear lotes"""
        try:
            query = """
            INSERT INTO Lote (Id_Producto, Cantidad_Caja, Cantidad_Unitario, Fecha_Vencimiento)
            OUTPUT INSERTED.id
            VALUES (?, ?, ?, ?)
            """
            
            result = self.producto_repo._execute_query(
                query, 
                (
                    lote_data['Id_Producto'],
                    lote_data['Cantidad_Caja'],
                    lote_data['Cantidad_Unitario'],
                    lote_data['Fecha_Vencimiento']
                ),
                fetch_one=True
            )
            
            return result['id'] if result and 'id' in result else None
        except Exception as e:
            print(f"❌ Error insertando lote: {e}")
            return None
    
    def _validar_datos_producto(self, datos: dict) -> bool:
        """Valida datos de producto antes de guardar"""
        # Validaciones básicas
        if not datos.get('codigo') or len(datos['codigo'].strip()) < 3:
            raise ValueError("Código debe tener al menos 3 caracteres")
        
        if not datos.get('nombre') or len(datos['nombre'].strip()) < 3:
            raise ValueError("Nombre debe tener al menos 3 caracteres")
        
        if datos.get('precio_compra', 0) <= 0:
            raise ValueError("Precio de compra debe ser mayor a 0")
        
        if datos.get('precio_venta', 0) <= 0:
            raise ValueError("Precio de venta debe ser mayor a 0")
        
        if datos.get('precio_venta', 0) <= datos.get('precio_compra', 0):
            raise ValueError("Precio de venta debe ser mayor al precio de compra")
        
        return True
    
    # NUEVA FUNCIÓN: Normalizar productos para consistencia en QML
    def _normalizar_producto(self, producto_raw: dict) -> dict:
        """
        Normaliza un producto de BD para uso consistente en QML
        
        Args:
            producto_raw: Producto raw de la BD con nomenclatura de BD
            
        Returns:
            Producto normalizado con nomenclatura consistente para QML
        """
        try:
            # Conversión segura de valores numéricos
            def safe_float(value):
                try:
                    return float(value) if value is not None else 0.0
                except (ValueError, TypeError):
                    return 0.0
            
            def safe_int(value):
                try:
                    return int(value) if value is not None else 0
                except (ValueError, TypeError):
                    return 0
            
            def safe_str(value):
                return str(value) if value is not None else ""
            
            # Producto normalizado con doble nomenclatura para compatibilidad
            producto_normalizado = {
                # ID
                'id': safe_int(producto_raw.get('id', 0)),
                
                # Código - múltiples variantes
                'codigo': safe_str(producto_raw.get('Codigo') or producto_raw.get('codigo', '')),
                'Codigo': safe_str(producto_raw.get('Codigo') or producto_raw.get('codigo', '')),
                
                # Nombre - múltiples variantes
                'nombre': safe_str(producto_raw.get('Nombre') or producto_raw.get('nombre', '')),
                'Nombre': safe_str(producto_raw.get('Nombre') or producto_raw.get('nombre', '')),
                
                # Detalles/Descripción - TODOS los nombres posibles
                'detalles': safe_str(
                    producto_raw.get('Detalles') or 
                    producto_raw.get('Producto_Detalles') or 
                    producto_raw.get('detalles') or 
                    producto_raw.get('descripcion', '')
                ),
                'Detalles': safe_str(
                    producto_raw.get('Detalles') or 
                    producto_raw.get('Producto_Detalles') or 
                    producto_raw.get('detalles', '')
                ),
                'Producto_Detalles': safe_str(
                    producto_raw.get('Producto_Detalles') or 
                    producto_raw.get('Detalles') or 
                    producto_raw.get('detalles', '')
                ),
                
                # Precios - múltiples nomenclaturas
                'precioCompra': safe_float(
                    producto_raw.get('Precio_compra') or 
                    producto_raw.get('precio_compra') or 
                    producto_raw.get('precioCompra', 0)
                ),
                'Precio_compra': safe_float(
                    producto_raw.get('Precio_compra') or 
                    producto_raw.get('precio_compra', 0)
                ),
                'precio_compra': safe_float(
                    producto_raw.get('precio_compra') or 
                    producto_raw.get('Precio_compra', 0)
                ),
                
                'precioVenta': safe_float(
                    producto_raw.get('Precio_venta') or 
                    producto_raw.get('precio_venta') or 
                    producto_raw.get('precioVenta', 0)
                ),
                'Precio_venta': safe_float(
                    producto_raw.get('Precio_venta') or 
                    producto_raw.get('precio_venta', 0)
                ),
                'precio_venta': safe_float(
                    producto_raw.get('precio_venta') or 
                    producto_raw.get('Precio_venta', 0)
                ),
                
                # Stock - múltiples nomenclaturas
                'stockCaja': safe_int(
                    producto_raw.get('Stock_Caja') or 
                    producto_raw.get('stock_caja') or 
                    producto_raw.get('stockCaja', 0)
                ),
                'Stock_Caja': safe_int(
                    producto_raw.get('Stock_Caja') or 
                    producto_raw.get('stock_caja', 0)
                ),
                'stock_caja': safe_int(
                    producto_raw.get('stock_caja') or 
                    producto_raw.get('Stock_Caja', 0)
                ),
                
                'stockUnitario': safe_int(
                    producto_raw.get('Stock_Unitario') or 
                    producto_raw.get('stock_unitario') or 
                    producto_raw.get('stockUnitario', 0)
                ),
                'Stock_Unitario': safe_int(
                    producto_raw.get('Stock_Unitario') or 
                    producto_raw.get('stock_unitario', 0)
                ),
                'stock_unitario': safe_int(
                    producto_raw.get('stock_unitario') or 
                    producto_raw.get('Stock_Unitario', 0)
                ),
                
                # Stock Total calculado
                'Stock_Total': safe_int(
                    producto_raw.get('Stock_Total') or
                    (safe_int(producto_raw.get('Stock_Caja', 0)) + safe_int(producto_raw.get('Stock_Unitario', 0)))
                ),
                
                # Unidad de medida
                'unidadMedida': safe_str(
                    producto_raw.get('Unidad_Medida') or 
                    producto_raw.get('unidad_medida') or 
                    'Tabletas'
                ),
                'Unidad_Medida': safe_str(
                    producto_raw.get('Unidad_Medida') or 
                    producto_raw.get('unidad_medida') or 
                    'Tabletas'
                ),
                
                # Marca - múltiples nomenclaturas
                'idMarca': safe_str(
                    producto_raw.get('Marca_Nombre') or 
                    producto_raw.get('marca_nombre') or 
                    producto_raw.get('ID_Marca') or 
                    producto_raw.get('idMarca') or 
                    'GENÉRICO'
                ),
                'ID_Marca': safe_int(
                    producto_raw.get('ID_Marca') or 
                    producto_raw.get('id_marca') or 
                    producto_raw.get('Marca_ID', 1)
                ),
                'Marca_Nombre': safe_str(
                    producto_raw.get('Marca_Nombre') or 
                    producto_raw.get('marca_nombre') or 
                    'GENÉRICO'
                ),
                'marca_nombre': safe_str(
                    producto_raw.get('marca_nombre') or 
                    producto_raw.get('Marca_Nombre') or 
                    'GENÉRICO'
                ),
                
                # Fecha de vencimiento
                'Fecha_Venc': safe_str(
                    producto_raw.get('Fecha_Venc') or 
                    producto_raw.get('fecha_vencimiento', '')
                ),
                
                # Campos adicionales para compatibilidad
                'Marca_Detalles': safe_str(producto_raw.get('Marca_Detalles', '')),
                'Marca_ID': safe_int(producto_raw.get('Marca_ID') or producto_raw.get('ID_Marca', 1))
            }
            
            return producto_normalizado
            
        except Exception as e:
            print(f"❌ Error normalizando producto: {e}")
            print(f"📦 Producto raw: {producto_raw}")
            # Retornar producto con valores por defecto en caso de error
            return {
                'id': 0,
                'codigo': 'ERROR',
                'nombre': 'Error cargando producto',
                'detalles': '',
                'precioCompra': 0.0,
                'precioVenta': 0.0,
                'stockCaja': 0,
                'stockUnitario': 0,
                'idMarca': 'ERROR'
            }
    
    def obtener_stock_total_producto(self, codigo: str) -> int:
        """Obtiene el stock total de un producto por código"""
        try:
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo)
            if producto:
                return (producto.get('Stock_Caja', 0) + producto.get('Stock_Unitario', 0))
            return 0
        except Exception:
            return 0

# Registrar el tipo para QML
def register_inventario_model():
    qmlRegisterType(InventarioModel, "ClinicaModels", 1, 0, "InventarioModel")