"""
InventarioModel - ACTUALIZADO con autenticación estandarizada
Migrado del patrón sin autenticación al patrón de ConsultaModel
"""

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
    Model QObject para inventario de farmacia con FIFO automático - ACTUALIZADO con autenticación
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
        
        # ✅ AUTENTICACIÓN ESTANDARIZADA - COMO CONSULTAMODEL
        self._usuario_actual_id = 0  # Cambio de hardcoded a dinámico
        print("🏪 InventarioModel inicializado - Esperando autenticación")
        
        # Timer para actualización automática
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._auto_update)
        self.update_timer.start(30000)  # 30 segundos
        
        # Cargar datos iniciales
        self._cargar_datos_iniciales()
        
        print("🏪 InventarioModel inicializado con autenticación estandarizada")
    
    # ===============================
    # ✅ MÉTODO REQUERIDO PARA APPCONTROLLER
    # ===============================
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """
        Establece el usuario actual para las operaciones - MÉTODO REQUERIDO por AppController
        """
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario autenticado establecido en InventarioModel: {usuario_id}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de inventario")
            else:
                print(f"⚠️ ID de usuario inválido en InventarioModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en InventarioModel: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        """Property para obtener el usuario actual"""
        return self._usuario_actual_id
    
    # ===============================
    # PROPIEDADES DE AUTENTICACIÓN
    # ===============================
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica si el usuario está autenticado"""
        if self._usuario_actual_id <= 0:
            self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
            return False
        return True
    
    # ===============================
    # PROPERTIES PARA QML (SIN CAMBIOS)
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
    # SLOTS PARA QML - CONSULTAS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot()
    def refresh_productos(self):
        """Refresca la lista de productos - SIN VERIFICACIÓN (solo lectura)"""
        self._set_loading(True)
        try:
            productos_raw = safe_execute(self.producto_repo.get_productos_con_marca) or []
            
            # Normalizar productos con nomenclatura consistente
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
        """Busca productos por nombre o código - SIN VERIFICACIÓN (solo lectura)"""
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
            
            # Normalizar resultados de búsqueda
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
        """Obtiene producto específico por código - SIN VERIFICACIÓN (solo lectura)"""
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
        """Obtiene lotes de un producto específico - SIN VERIFICACIÓN (solo lectura)"""
        if producto_id <= 0:
            return []
        
        try:
            lotes = safe_execute(self.producto_repo.get_lotes_producto, producto_id, True) or []
            return lotes
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo lotes: {str(e)}")
            return []
    
    @Slot(int, result='QVariant')
    def get_lotes_por_producto(self, producto_id: int):
        """Obtiene lotes de un producto específico - ALIAS para QML - SIN VERIFICACIÓN (solo lectura)"""
        return self.get_lotes_producto(producto_id)

    @Slot(int, result='QVariant') 
    def get_lotes_por_vencer(self, dias_adelante: int = 60):
        """Obtiene lotes que vencen en X días - SIN VERIFICACIÓN (solo lectura)"""
        if dias_adelante <= 0:
            dias_adelante = 60
            
        try:
            lotes = safe_execute(
                self.producto_repo.get_lotes_por_vencer, 
                dias_adelante
            ) or []
            print(f"📅 Lotes por vencer en {dias_adelante} días: {len(lotes)}")
            return lotes
        except Exception as e:
            print(f"❌ Error obteniendo lotes por vencer: {e}")
            self.operacionError.emit(f"Error obteniendo lotes por vencer: {str(e)}")
            return []

    @Slot(result='QVariant')
    def get_lotes_vencidos(self):
        """Obtiene lotes vencidos con stock - SIN VERIFICACIÓN (solo lectura)"""
        try:
            lotes = safe_execute(self.producto_repo.get_lotes_vencidos) or []
            print(f"⚠️ Lotes vencidos: {len(lotes)}")
            return lotes
        except Exception as e:
            print(f"❌ Error obteniendo lotes vencidos: {e}")
            self.operacionError.emit(f"Error obteniendo lotes vencidos: {str(e)}")
            return []

    @Slot(int, result='QVariant')
    def get_productos_bajo_stock(self, stock_minimo: int = 10):
        """Obtiene productos con stock bajo - SIN VERIFICACIÓN (solo lectura)"""
        if stock_minimo <= 0:
            stock_minimo = 10
            
        try:
            productos = safe_execute(
                self.producto_repo.get_productos_bajo_stock, 
                stock_minimo
            ) or []
            print(f"📊 Productos bajo stock (≤{stock_minimo}): {len(productos)}")
            return productos
        except Exception as e:
            print(f"❌ Error obteniendo productos bajo stock: {e}")
            self.operacionError.emit(f"Error obteniendo productos bajo stock: {str(e)}")
            return []
    
    @Slot(int, int, result='QVariant')
    def verificar_disponibilidad(self, producto_id: int, cantidad: int):
        """Verifica disponibilidad FIFO para una cantidad - SIN VERIFICACIÓN (solo lectura)"""
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
    # SLOTS PARA QML - VENTAS - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(int, str, result=bool)
    def procesar_venta_rapida(self, usuario_id: int, items_json: str):
        """
        Procesa venta rápida desde QML - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
        
        Args:
            usuario_id: ID del usuario vendedor (debe coincidir con autenticado)
            items_json: JSON string con items [{'codigo': str, 'cantidad': int, 'precio': float}]
        """
        # ✅ VERIFICAR AUTENTICACIÓN PRIMERO
        if not self._verificar_autenticacion():
            return False
        
        # ✅ VERIFICAR QUE EL USUARIO COINCIDA
        if usuario_id != self._usuario_actual_id:
            self.operacionError.emit("ID de usuario no coincide con el autenticado")
            return False
        
        if usuario_id <= 0 or not items_json:
            self.operacionError.emit("Datos de venta inválidos")
            return False
        
        self._set_loading(True)
        try:
            print(f"💰 Procesando venta - Usuario: {self._usuario_actual_id}")
            
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
                print(f"💰 Venta exitosa - ID: {venta['id']}, Items: {len(items)}, Usuario: {self._usuario_actual_id}")
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
        """Venta simple de un producto - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        # ✅ VERIFICAR QUE EL USUARIO COINCIDA
        if usuario_id != self._usuario_actual_id:
            self.operacionError.emit("ID de usuario no coincide con el autenticado")
            return False
        
        if not codigo or cantidad <= 0 or usuario_id <= 0:
            self.operacionError.emit("Parámetros de venta inválidos")
            return False
        
        try:
            print(f"🛒 Venta simple - Producto: {codigo}, Usuario: {self._usuario_actual_id}")
            
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
    # SLOTS PARA QML - COMPRAS - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(int, int, str, result=bool)
    def procesar_compra(self, proveedor_id: int, usuario_id: int, items_json: str):
        """
        Procesa compra desde QML - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
        
        Args:
            proveedor_id: ID del proveedor
            usuario_id: ID del usuario comprador (debe coincidir con autenticado)
            items_json: JSON con items [{'codigo': str, 'cantidad_caja': int, 'cantidad_unitario': int, 
                                        'precio_unitario': float, 'fecha_vencimiento': str}]
        """
        # ✅ VERIFICAR AUTENTICACIÓN PRIMERO
        if not self._verificar_autenticacion():
            return False
        
        # ✅ VERIFICAR QUE EL USUARIO COINCIDA
        if usuario_id != self._usuario_actual_id:
            self.operacionError.emit("ID de usuario no coincide con el autenticado")
            return False
        
        if proveedor_id <= 0 or usuario_id <= 0 or not items_json:
            self.operacionError.emit("Datos de compra inválidos")
            return False
        
        self._set_loading(True)
        try:
            print(f"📦 Procesando compra - Proveedor: {proveedor_id}, Usuario: {self._usuario_actual_id}")
            
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
                print(f"📦 Compra exitosa - ID: {compra['id']}, Items: {len(items)}, Usuario: {self._usuario_actual_id}")
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
        """Crea proveedor rápidamente - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return 0
        
        if not nombre:
            self.operacionError.emit("Nombre de proveedor requerido")
            return 0
        
        try:
            print(f"🏢 Creando proveedor - Usuario: {self._usuario_actual_id}")
            
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
    # SLOTS PARA QML - ALERTAS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot()
    def actualizar_alertas(self):
        """Actualiza alertas de stock y vencimientos - SIN VERIFICACIÓN (solo lectura)"""
        self._actualizar_alertas()
    
    @Slot(int)
    def configurar_stock_minimo(self, stock_minimo: int):
        """Configura el stock mínimo para alertas - SIN VERIFICACIÓN (solo lectura)"""
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
        """Verifica productos por vencer - SIN VERIFICACIÓN (solo lectura)"""
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
    # SLOTS PARA QML - REPORTES (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(result='QVariant')
    def get_reporte_vencimientos(self):
        """Obtiene reporte completo de vencimientos - SIN VERIFICACIÓN (solo lectura)"""
        try:
            reporte = safe_execute(self.producto_repo.get_reporte_vencimientos, 180) or {}
            return reporte
        except Exception as e:
            self.operacionError.emit(f"Error en reporte vencimientos: {str(e)}")
            return {}
    
    @Slot(result='QVariant')
    def get_valor_inventario(self):
        """Obtiene valor total del inventario - SIN VERIFICACIÓN (solo lectura)"""
        try:
            valor = safe_execute(self.producto_repo.get_valor_inventario) or {}
            return valor
        except Exception as e:
            self.operacionError.emit(f"Error calculando valor inventario: {str(e)}")
            return {}
    
    @Slot(int, result='QVariant')
    def get_productos_mas_vendidos(self, dias: int = 30):
        """Obtiene productos más vendidos - SIN VERIFICACIÓN (solo lectura)"""
        try:
            productos = safe_execute(self.producto_repo.get_productos_mas_vendidos, dias) or []
            return productos
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo más vendidos: {str(e)}")
            return []
    
    @Slot(result='QVariant')
    def get_estadisticas_inventario(self):
        """Obtiene estadísticas completas del inventario - SIN VERIFICACIÓN (solo lectura)"""
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
    # SLOTS PARA QML - CRUD PRODUCTOS - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
        
    @Slot(str, result=bool)
    def crear_producto(self, producto_json: str):
        """
        Crea un nuevo producto desde QML CON PRIMER LOTE - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
        
        Args:
            producto_json: JSON string con datos del producto + primer lote
            {
                'codigo': str,
                'nombre': str,
                'detalles': str,
                'precio_compra': float,
                'precio_venta': float,
                'unidad_medida': str,
                'id_marca': int,
                # CAMPOS PARA PRIMER LOTE:
                'stock_caja': int,
                'stock_unitario': int,
                'fecha_vencimiento': str,
                'proveedor': str (opcional)
            }
        """
        # ✅ VERIFICAR AUTENTICACIÓN PRIMERO
        if not self._verificar_autenticacion():
            return False
        
        if not producto_json:
            self.operacionError.emit("Datos de producto requeridos")
            return False

        self._set_loading(True)
        try:
            print(f"📦 Creando producto - Usuario: {self._usuario_actual_id}")
            
            # Parsear datos JSON
            datos = json.loads(producto_json)
            
            # Validar datos
            if not self._validar_datos_producto(datos):
                return False
            
            # Validar stock inicial
            stock_inicial = int(datos.get('stock_caja', 0)) + int(datos.get('stock_unitario', 0))
            if stock_inicial <= 0:
                raise ValueError("Debe especificar stock inicial (cajas o unitarios)")
            
            # Validar fecha de vencimiento
            fecha_vencimiento = datos.get('fecha_vencimiento', '')
            if not fecha_vencimiento:
                raise ValueError("Fecha de vencimiento requerida")
            
            # Verificar que el código no exista
            producto_existente = safe_execute(self.producto_repo.get_by_codigo, datos['codigo'])
            if producto_existente:
                raise ValueError(f"El código {datos['codigo']} ya existe")
            
            # Preparar datos con nomenclatura de BD
            nuevo_producto = {
                'Codigo': datos['codigo'],
                'Nombre': datos['nombre'],
                'Detalles': datos.get('detalles', ''),
                'Precio_compra': float(datos['precio_compra']),
                'Precio_venta': float(datos['precio_venta']),
                'Stock_Caja': int(datos.get('stock_caja', 0)),
                'Stock_Unitario': int(datos.get('stock_unitario', 0)),
                'Unidad_Medida': datos.get('unidad_medida', 'Tabletas'),
                'ID_Marca': int(datos.get('id_marca', 1)),
                'Fecha_Venc': fecha_vencimiento
            }
            
            # PASO 1: Insertar producto
            producto_id = safe_execute(self.producto_repo.insert, nuevo_producto)
            
            if not producto_id:
                raise Exception("Error creando producto en base de datos")
            
            print(f"✅ Producto creado - ID: {producto_id}, Código: {datos['codigo']}, Usuario: {self._usuario_actual_id}")
            
            # PASO 2: Crear primer lote OBLIGATORIO
            lote_id = safe_execute(
                self.producto_repo.aumentar_stock_compra,
                producto_id,
                int(datos.get('stock_caja', 0)),
                int(datos.get('stock_unitario', 0)),
                fecha_vencimiento,
                float(datos['precio_compra'])
            )
            
            if not lote_id:
                # Si falla crear lote, eliminar producto para mantener consistencia
                safe_execute(self.producto_repo.delete, producto_id)
                raise Exception("Error creando lote inicial - Producto revertido")
            
            print(f"✅ Primer lote creado - ID: {lote_id}, Vencimiento: {fecha_vencimiento}")
            
            # PASO 3: Refrescar datos
            self.refresh_productos()
            self._cargar_lotes_activos()
            
            self.operacionExitosa.emit(f"Producto creado: {datos['codigo']} con lote inicial")
            self.productoCreado.emit(datos['codigo'])
            
            return True
            
        except json.JSONDecodeError:
            self.operacionError.emit("Error: Formato de datos inválido")
        except ValueError as e:
            self.operacionError.emit(f"Error de validación: {str(e)}")
        except Exception as e:
            self.operacionError.emit(f"Error creando producto: {str(e)}")
            print(f"❌ Error detallado: {str(e)}")
        finally:
            self._set_loading(False)

        return False
    
    @Slot(str, float, result=bool)
    def actualizar_precio_venta(self, codigo: str, nuevo_precio: float):
        """
        Actualiza el precio de venta de un producto - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
        
        Args:
            codigo: Código del producto
            nuevo_precio: Nuevo precio de venta
        """
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        if not codigo or nuevo_precio <= 0:
            self.operacionError.emit("Código y precio válido requeridos")
            return False
        
        self._set_loading(True)
        try:
            print(f"💰 Actualizando precio - Producto: {codigo}, Usuario: {self._usuario_actual_id}")
            
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
                print(f"💰 Precio actualizado - {codigo}: Bs{nuevo_precio:.2f}, Usuario: {self._usuario_actual_id}")
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
        Agrega stock a un producto creando un nuevo lote - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
        
        Args:
            codigo: Código del producto
            cantidad_caja: Cantidad en cajas
            cantidad_unitario: Cantidad unitaria
            fecha_vencimiento: Fecha de vencimiento (YYYY-MM-DD)
            precio_compra: Precio de compra (opcional)
        """
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        if not codigo or (cantidad_caja <= 0 and cantidad_unitario <= 0):
            self.operacionError.emit("Código y cantidad válida requeridos")
            return False
        
        self._set_loading(True)
        try:
            print(f"📈 Agregando stock - Producto: {codigo}, Usuario: {self._usuario_actual_id}")
            
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
                print(f"📈 Stock agregado - {codigo}: +{total_agregado} unidades, Lote: {lote_id}, Usuario: {self._usuario_actual_id}")
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
    
    # ===============================
    # SLOTS PARA CONSULTAS ESPECÍFICAS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(result='QVariant')
    def get_marcas_disponibles(self):
        """Obtiene lista de marcas disponibles para productos - SIN VERIFICACIÓN (solo lectura)"""
        try:
            # Asegurar que las marcas estén actualizadas
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
        Obtiene detalles completos de un producto incluyendo TODOS sus lotes - SIN VERIFICACIÓN (solo lectura)
        
        Returns:
            {
                'producto': {...},
                'lotes': [...],
                'stock_total': int,
                'valor_inventario': float,
                'lotes_vencidos': int,
                'lotes_por_vencer': int
            }
        """
        if not codigo:
            return {}
        
        try:
            # Obtener producto
            producto_raw = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
            if not producto_raw:
                print(f"❌ Producto no encontrado: {codigo}")
                return {}
            
            # Normalizar producto
            producto = self._normalizar_producto(producto_raw)
            
            # Obtener TODOS los lotes (incluyendo vacíos para historial)
            lotes = safe_execute(self.producto_repo.get_lotes_producto, producto['id'], False) or []
            
            # Calcular estadísticas
            stock_total = 0
            lotes_vencidos = 0
            lotes_por_vencer = 0
            
            from datetime import datetime
            hoy = datetime.now()
            
            for lote in lotes:
                stock_lote = (lote.get('Cantidad_Caja', 0) * lote.get('Cantidad_Unitario', 0))
                stock_total += stock_lote
                
                if stock_lote > 0:  # Solo contar lotes con stock
                    fecha_venc = lote.get('Fecha_Vencimiento')
                    if fecha_venc:
                        try:
                            vencimiento = datetime.strptime(fecha_venc, '%Y-%m-%d') if isinstance(fecha_venc, str) else fecha_venc
                            dias_diferencia = (vencimiento - hoy).days
                            
                            if dias_diferencia < 0:
                                lotes_vencidos += 1
                            elif dias_diferencia <= 60:
                                lotes_por_vencer += 1
                        except:
                            pass
            
            valor_inventario = stock_total * producto.get('precioCompra', 0)
            
            resultado = {
                'producto': producto,
                'lotes': lotes,
                'stock_total': stock_total,
                'valor_inventario': valor_inventario,
                'lotes_count': len([l for l in lotes if (l.get('Cantidad_Caja', 0) + l.get('Cantidad_Unitario', 0)) > 0]),
                'lotes_vencidos': lotes_vencidos,
                'lotes_por_vencer': lotes_por_vencer
            }
            
            print(f"📊 Detalles cargados para {codigo}: {len(lotes)} lotes, {stock_total} stock total")
            return resultado
            
        except Exception as e:
            print(f"❌ Error obteniendo detalles de {codigo}: {str(e)}")
            self.operacionError.emit(f"Error obteniendo detalles: {str(e)}")
            return {}
    
    # ===============================
    # MÉTODOS PRIVADOS (SIN CAMBIOS MAYORES)
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga datos iniciales al crear el model"""
        self._set_loading(True)
        try:
            # Cargar y normalizar productos
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
            
            # Normalizar marcas para QML
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
                (l.Cantidad_Caja * l.Cantidad_Unitario) as Stock_Lote
            FROM Lote l
            INNER JOIN Productos p ON l.Id_Producto = p.id
            WHERE (l.Cantidad_Caja * l.Cantidad_Unitario) > 0
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
                
                'precioVenta': safe_float(
                    producto_raw.get('Precio_venta') or 
                    producto_raw.get('precio_venta') or 
                    producto_raw.get('precioVenta', 0)
                ),
                'Precio_venta': safe_float(
                    producto_raw.get('Precio_venta') or 
                    producto_raw.get('precio_venta', 0)
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
                
                'stockUnitario': safe_int(
                    producto_raw.get('Stock_Unitario') or 
                    producto_raw.get('stock_unitario') or 
                    producto_raw.get('stockUnitario', 0)
                ),
                'Stock_Unitario': safe_int(
                    producto_raw.get('Stock_Unitario') or 
                    producto_raw.get('stock_unitario', 0)
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
                # CORRECCIÓN: Usar datos de lotes en lugar de tabla productos
                stock_total = producto.get('Stock_Total', 0)
                if stock_total == 0:
                    # Fallback: calcular desde stock individual
                    return (producto.get('Stock_Caja', 0) + producto.get('Stock_Unitario', 0))
                return stock_total
            return 0
        except Exception:
            return 0

    def emergency_disconnect(self):
        """Desconexión de emergencia para InventarioModel"""
        try:
            print("🚨 InventarioModel: Iniciando desconexión de emergencia...")
            
            # Detener timer
            if hasattr(self, 'update_timer') and self.update_timer.isActive():
                self.update_timer.stop()
                print("   ⏹️ Update timer detenido")
            
            # Establecer estado shutdown
            self._loading = False
            
            # Desconectar todas las señales
            signals_to_disconnect = [
                'productosChanged', 'lotesChanged', 'marcasChanged', 'proveedoresChanged',
                'stockBajoAlert', 'productoVencidoAlert', 'operacionExitosa', 'operacionError',
                'stockActualizado', 'productoCreado', 'productoEliminado', 'precioActualizado',
                'loadingChanged', 'searchResultsChanged', 'alertasChanged'
            ]
            
            for signal_name in signals_to_disconnect:
                if hasattr(self, signal_name):
                    try:
                        getattr(self, signal_name).disconnect()
                    except:
                        pass
            
            # Limpiar datos
            self._productos = []
            self._lotes_activos = []
            self._marcas = []
            self._proveedores = []
            self._search_results = []
            self._alertas = []
            self._usuario_actual_id = 0  # ✅ RESETEAR USUARIO
            
            # Anular repositories
            self.producto_repo = None
            self.venta_repo = None
            self.compra_repo = None
            
            print("✅ InventarioModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión InventarioModel: {e}")

# Registrar el tipo para QML
def register_inventario_model():
    qmlRegisterType(InventarioModel, "ClinicaModels", 1, 0, "InventarioModel")
    print("🔗 InventarioModel registrado para QML con autenticación estandarizada")