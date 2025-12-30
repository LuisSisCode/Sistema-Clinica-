"""
InventarioModel - CORREGIDO - Gestión completa de productos y lotes FIFO
Incluye CRUD completo: Crear, Leer, Actualizar, Eliminar
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
    Model QObject para inventario COMPLETO con CRUD y FIFO automático - SIN CAJAS - Solo stock unitario
    CORREGIDO: Stock se calcula siempre desde lotes, no desde campo de producto
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
        self._force_refresh_no_cache = False
        
        # AUTENTICACIÓN ESTANDARIZADA
        self._usuario_actual_id = 10
        print("🏪 InventarioModel inicializado SIN CAJAS - Esperando autenticación")
        
        # Timer para actualización automática
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._auto_update)
        
        # ✅ NUEVO: Timer de debounce para evitar signal loops
        self._debounce_timer = QTimer()
        self._debounce_timer.setSingleShot(True)
        self._debounce_timer.timeout.connect(self._emit_productos_changed)
        self._pending_productos_emit = False
        
        # Cargar datos iniciales
        self._cargar_datos_iniciales()
        self._setup_venta_listener()
        
        print("🏪 InventarioModel CORREGIDO inicializado - CRUD COMPLETO - SOLO STOCK UNITARIO")
    
    # ===============================
    # MÉTODO REQUERIDO PARA APPCONTROLLER
    # ===============================
    def _setup_venta_listener(self):
        """Configura listener para actualizaciones automáticas después de ventas"""
        try:
            # Este método se ejecutará en AppController para conectar los modelos
            pass
        except Exception as e:
            print(f"Error configurando listener de ventas: {e}")
    @Slot()
    def actualizar_por_venta(self):
        """Actualiza productos después de una venta (llamado desde señal externa)"""
        try:
            print("📦 Actualizando inventario después de venta...")
            
            # ✅ MARCAR para invalidación sin cache
            self._force_refresh_no_cache = True
            
            # Forzar actualización SIN caché
            self.refresh_productos()
            
        except Exception as e:
            print(f"Error actualizando inventario por venta: {e}")
            self.operacionError.emit(f"Error actualizando inventario: {str(e)}")
    
    def set_usuario_actual(self, usuario_id: int):
        """Establece el usuario actual para las operaciones - MÉTODO REQUERIDO por AppController"""
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
    @Slot(result=str)
    def verificar_sistema_eliminacion(self):
        """Verifica que todos los componentes para eliminación funcionen"""
        try:
            # Verificar autenticación
            if not self._verificar_autenticacion():
                return "❌ Sistema no autenticado"
            
            # Verificar repository
            if not self.producto_repo:
                return "❌ ProductoRepository no disponible"
            
            # Verificar método de eliminación
            if not hasattr(self.producto_repo, 'eliminar_producto'):
                return "❌ Método eliminar_producto no existe en repository"
            
            # Verificar conexión a BD
            try:
                # Intentar una consulta simple
                productos_count = len(self.producto_repo.get_productos_con_marca() or [])
                mensaje = f"✅ Sistema eliminación OK - {productos_count} productos disponibles - Usuario: {self._usuario_actual_id}"
                self.operacionExitosa.emit(mensaje)
                return mensaje
            except Exception as e:
                return f"❌ Error BD: {str(e)}"
            
        except Exception as e:
            return f"❌ Error verificación: {str(e)}"

    def _verificar_autenticacion(self) -> bool:
        """Verifica si el usuario está autenticado - CON MÁS LOGGING"""
        if self._usuario_actual_id <= 0:
            print(f"🚫 AUTENTICACIÓN FALLÓ: Usuario actual ID = {self._usuario_actual_id}")
            self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
            return False
        
        print(f"✅ AUTENTICACIÓN OK: Usuario ID = {self._usuario_actual_id}")
        return True
    
    def safe_execute_local(func, *args, **kwargs):
        """Ejecuta función de forma segura con manejo de excepciones"""
        try:
            return func(*args, **kwargs)
        except Exception as e:
            print(f"❌ Error en safe_execute_local: {e}")
            return None
        
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

    @Property(list, notify=marcasChanged)
    def marcasDisponibles(self):
        """Property para marcas disponibles - REQUERIDA por QML"""
        return self._marcas

    
    # ===============================
    # SLOTS PARA QML - CONSULTAS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot()
    def refresh_productos(self):
        """
        ✅ CORREGIDO: Refresca la lista de productos con stock calculado desde lotes
        """
        self._set_loading(True)
        try:
            # ✅ SOLUCIÓN BALANCEADA: Solo usar cache en carga inicial
            usar_cache = not hasattr(self, '_force_refresh_no_cache') or not self._force_refresh_no_cache
            
            if not usar_cache:
                # Invalidar cache solo cuando se fuerza (después de ventas)
                if hasattr(self.producto_repo, '_invalidate_cache_after_modification'):
                    self.producto_repo._invalidate_cache_after_modification()
                self._force_refresh_no_cache = False  # Reset flag
            
            # Obtener productos
            if usar_cache:
                productos_raw = safe_execute(self.producto_repo.get_productos_con_marca) or []
            else:
                # Sin cache para refrescos forzados
                productos_raw = self.producto_repo.get_productos_con_marca() or []
            
            # Normalizar productos con información FIFO
            self._productos = []
            for producto in productos_raw:
                try:
                    producto_normalizado = self._normalizar_producto(producto)
                    self._productos.append(producto_normalizado)
                except Exception as e:
                    print(f"Error normalizando producto: {e}")
                    continue
            
            # ✅ USAR DEBOUNCE: Programar emisión del signal en lugar de emitir directamente
            self._schedule_productos_changed()
            print(f"Productos refrescados: {len(self._productos)} con stock desde lotes")
            
        except Exception as e:
            print(f"Error refrescando productos: {e}")
            self.operacionError.emit(f"Error actualizando productos: {str(e)}")
        finally:
            self._set_loading(False)

    # ================== DESPUÉS DE refresh_productos() ==================

    @Slot(str, result=int)
    def crear_marca_desde_qml(self, nombre_marca: str) -> int:
        """
        Crea una nueva marca desde QML - CORREGIDO - Retorna ID
        
        Returns:
            int: ID de la marca creada, 0 si ya existe, -1 si error
        """
        try:
            print(f"🏷️ Creando marca desde QML: '{nombre_marca}'")
            
            # Validar nombre
            if not nombre_marca or len(nombre_marca.strip()) < 2:
                print("❌ Nombre de marca inválido")
                self.operacionError.emit("El nombre debe tener al menos 2 caracteres")
                return -1
            
            nombre_limpio = nombre_marca.strip()
            
            # Verificar si ya existe (búsqueda case-insensitive)
            for marca in self._marcas:
                if marca['Nombre'].lower() == nombre_limpio.lower():
                    print(f"⚠️ Marca '{nombre_limpio}' ya existe con ID: {marca['id']}")
                    self.operacionError.emit(f"La marca '{nombre_limpio}' ya existe")
                    return 0
            
            # ✅ CORRECCIÓN: Usar producto_repo para crear la marca
            if not self.producto_repo:
                print("❌ ProductoRepository no disponible")
                self.operacionError.emit("Error: Sistema no disponible")
                return -1
            
            # Crear marca en BD - Ahora retorna ID
            marca_id = self.producto_repo.crear_marca(nombre_limpio)
            
            if marca_id > 0:
                print(f"✅ Marca '{nombre_limpio}' creada exitosamente con ID: {marca_id}")
                
                # Refrescar lista de marcas
                self._marcas = self._cargar_marcas() or []
                self.marcasChanged.emit()
                
                # Emitir señal de éxito
                self.operacionExitosa.emit(f"Marca '{nombre_limpio}' creada")
                
                return marca_id
            elif marca_id == 0:
                # Ya existe
                print(f"⚠️ Marca '{nombre_limpio}' ya existe")
                self.operacionError.emit(f"La marca '{nombre_limpio}' ya existe")
                return 0
            else:
                print(f"❌ Error creando marca '{nombre_limpio}'")
                self.operacionError.emit("Error al crear la marca en la base de datos")
                return -1
                
        except Exception as e:
            print(f"❌ Error en crear_marca_desde_qml: {e}")
            import traceback
            traceback.print_exc()
            self.operacionError.emit(f"Error inesperado: {str(e)}")
            return -1

    @Slot()
    def refresh_marcas(self):
        """Refresca la lista de marcas disponibles - FORZADO SIN CACHE"""
        try:
            print("🔄 Refrescando marcas (forzado sin cache)...")
            
            # Invalidar cache antes de cargar
            if hasattr(self.producto_repo, '_invalidate_cache_after_modification'):
                self.producto_repo._invalidate_cache_after_modification()
            
            # Cargar marcas frescas desde BD
            self._marcas = self._cargar_marcas() or []
            
            # Emitir señal de cambio
            self.marcasChanged.emit()
            
            print(f"✅ Marcas refrescadas: {len(self._marcas)}")
            
            # Debug: Mostrar primeras marcas
            if self._marcas:
                for i, marca in enumerate(self._marcas[:3]):
                    print(f"   {i+1}. {marca.get('nombre', 'Sin nombre')} (ID: {marca.get('id', 0)})")
            
        except Exception as e:
            print(f"❌ Error refrescando marcas: {e}")
            import traceback
            traceback.print_exc()
        
    @Slot(str)
    def buscar_productos(self, termino: str):
        """
        ✅ CORREGIDO: Busca productos con stock calculado desde lotes y información FIFO
        """
        if not termino or len(termino.strip()) < 2:
            self._search_results = []
            self.searchResultsChanged.emit()
            return
        
        try:
            # Usar ProductoRepository con stock calculado desde lotes
            resultados_raw = safe_execute(
                self.producto_repo.buscar_productos, 
                termino.strip(), 
                True  # incluir_sin_stock = True para mostrar todos los resultados
            ) or []
            
            # Normalizar y enriquecer resultados con información FIFO
            self._search_results = []
            for resultado in resultados_raw:
                try:
                    # Normalizar producto básico
                    resultado_normalizado = self._normalizar_producto(resultado)
                    
                    # ✅ ENRIQUECER con información FIFO adicional
                    stock_total = resultado_normalizado.get('Stock_Total', 0)
                    lotes_activos = resultado.get('Lotes_Activos', 0)
                    proxima_vencimiento = resultado.get('Proxima_Vencimiento')
                    estado_stock = resultado.get('Estado_Stock', 'DESCONOCIDO')
                    
                    # Información adicional para UI
                    resultado_normalizado.update({
                        'disponible': stock_total > 0,
                        'estado_stock': estado_stock,
                        'nivel_stock': 'BAJO' if stock_total <= 5 else 'DISPONIBLE',
                        'lotes_activos': lotes_activos,
                        'tiene_lotes': lotes_activos > 0,
                        'proxima_vencimiento': proxima_vencimiento,
                        'dias_vencimiento': 0,  # Simplificado
                        'color_stock': '#e74c3c' if stock_total <= 0 else '#27ae60',
                        'icono_estado': '✅' if stock_total > 0 else '🚫',
                        'puede_vender': stock_total > 0,
                        'stock_calculado_desde_lotes': True,
                        'fifo_enabled': True
                    })
                    
                    self._search_results.append(resultado_normalizado)
                    
                except Exception as e:
                    print(f"Error normalizando resultado: {e}")
                    continue
            
            self.searchResultsChanged.emit()
            print(f"Búsqueda '{termino}': {len(self._search_results)} productos encontrados (FIFO habilitado)")
            
        except Exception as e:
            error_msg = f"Error en búsqueda: {str(e)}"
            print(f"Error: {error_msg}")
            self.operacionError.emit(error_msg)
            self._search_results = []
            self.searchResultsChanged.emit()
    
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
    # SLOTS PARA QML - CRUD PRODUCTOS - CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
        
    @Slot(str, result=bool)
    def crear_producto(self, producto_json: str):
        """
        Crea un nuevo producto desde QML CON PRIMER LOTE (opcional si stock > 0)
        Args:
            producto_json: JSON string con datos del producto + primer lote
        """
        # VERIFICAR AUTENTICACIÓN PRIMERO
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
            
            # Validar stock inicial (AHORA PERMITE 0)
            stock_inicial = int(datos.get('stock_unitario', 0))
            if stock_inicial < 0:
                raise ValueError("El stock no puede ser negativo")
            
            # Validar fecha de vencimiento
            fecha_vencimiento = datos.get('fecha_vencimiento', '')
            if fecha_vencimiento is not None and not self._validate_date_format(fecha_vencimiento):
                raise ValueError("Formato de fecha de vencimiento inválido")
            
            # Verificar que el código no exista
            codigo_producto = datos.get('codigo', '').strip() or self._generar_codigo_automatico()
            
            producto_existente = safe_execute(self.producto_repo.get_by_codigo, codigo_producto)
            if producto_existente:
                raise ValueError(f"El código {codigo_producto} ya existe")
            
            # ✅ CORRECCIÓN MEJORADA: Manejo explícito de marca
            id_marca = datos.get('id_marca', 0)
            marca_nombre = datos.get('marca', '')
            
            print(f"🏷️ Procesando marca - ID recibido: {id_marca}, Nombre: {marca_nombre}")

            # CASO 1: Ya tenemos un ID de marca válido (cuando se creó nueva marca)
            if id_marca and id_marca > 0:
                print(f"✅ Usando ID de marca existente: {id_marca}")
                # Verificar que la marca existe en la base de datos
                marca_valida = False
                try:
                    marca_valida = any(m['id'] == id_marca for m in self._marcas)
                except Exception:
                    marca_valida = False
                if not marca_valida:
                    print(f"⚠️ Marca ID {id_marca} no existe, usando marca por defecto")
                    id_marca = 1
            
            # CASO 2: No tenemos ID pero tenemos nombre (marca existente)
            elif marca_nombre and marca_nombre.strip():
                print(f"🔍 Buscando marca por nombre: '{marca_nombre}'")
                id_marca = self._obtener_id_marca(marca_nombre.strip())
                print(f"✅ Marca encontrada: ID {id_marca}")
            
            # CASO 3: Sin marca especificada
            else:
                print("⚠️ No se especificó marca, usando marca por defecto")
                id_marca = 1

            print(f"🎯 Usando marca final - ID: {id_marca}")

            # Preparar datos del producto
            datos_producto = {
                'Codigo': codigo_producto,
                'Nombre': datos['nombre'],
                'Detalles': datos.get('detalles', ''),
                'Precio_compra': float(datos['precio_compra']),
                'Precio_venta': float(datos['precio_venta']),
                'Unidad_Medida': datos.get('unidad_medida', 'Tabletas'),
                'ID_Marca': id_marca,
                'Fecha_Venc': self._procesar_fecha_vencimiento(fecha_vencimiento)
            }
            
            # ✅ LÓGICA CONDICIONAL: Solo crear lote si hay stock > 0
            if stock_inicial > 0:
                # Preparar datos del primer lote
                datos_lote = {
                    'cantidad_unitario': stock_inicial,
                    'fecha_vencimiento': self._procesar_fecha_vencimiento(fecha_vencimiento)
                }
                
                # Crear producto con lote inicial
                producto_id = safe_execute(
                    self.producto_repo.crear_producto_con_lote_inicial,
                    datos_producto,
                    datos_lote
                )
                
                if not producto_id:
                    raise Exception("Error creando producto en base de datos")
                
                print(f"✅ Producto y lote creados - ID: {producto_id}, Código: {codigo_producto}, Stock: {stock_inicial}")
                mensaje = f"Producto creado: {codigo_producto} con stock inicial de {stock_inicial}"
            else:
                # ✅ Crear solo el producto sin lote
                producto_id = safe_execute(
                    self.producto_repo.crear_producto,
                    datos_producto
                )
                
                if not producto_id:
                    raise Exception("Error creando producto en base de datos")
                
                print(f"✅ Producto creado sin stock - ID: {producto_id}, Código: {codigo_producto}")
                mensaje = f"Producto creado: {codigo_producto} (sin stock inicial)"
            
            # Refrescar datos
            self.refresh_productos()
            self._cargar_lotes_activos()
            
            self.operacionExitosa.emit(mensaje)
            self.productoCreado.emit(codigo_producto)
            
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
    
    @Slot(str, str, result=bool)
    def actualizar_producto(self, codigo: str, producto_json: str):
        """Actualiza un producto existente - CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        if not codigo or not producto_json:
            self.operacionError.emit("Código y datos de producto requeridos")
            return False
        
        self._set_loading(True)
        try:
            print(f"🔧 Actualizando producto - Código: {codigo}, Usuario: {self._usuario_actual_id}")
            
            # Obtener producto actual
            producto_actual = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
            if not producto_actual:
                raise ProductoNotFoundError(codigo=codigo)
            
            # Parsear nuevos datos
            datos = json.loads(producto_json)
            datos_mapeados = {}

            # Mapear campos con nombres correctos para BD
            if 'nombre' in datos:
                datos_mapeados['Nombre'] = datos['nombre']
            if 'detalles' in datos:
                datos_mapeados['Detalles'] = datos['detalles']
            if 'precio_compra' in datos:
                datos_mapeados['Precio_compra'] = datos['precio_compra']
            if 'precio_venta' in datos:
                datos_mapeados['Precio_venta'] = datos['precio_venta']
            if 'unidad_medida' in datos:
                datos_mapeados['Unidad_Medida'] = datos['unidad_medida']
            
            # ✅ AGREGAR MAPEO DE MARCA - CORREGIDO
            if 'id_marca' in datos and datos['id_marca'] > 0:
                datos_mapeados['ID_Marca'] = datos['id_marca']
                print(f"🏷️ Actualizando marca a ID: {datos['id_marca']}")
            elif 'marca' in datos:
                # Fallback si viene el nombre
                id_marca = self._obtener_id_marca(datos['marca'])
                datos_mapeados['ID_Marca'] = id_marca
                print(f"🏷️ Actualizando marca por nombre: {datos['marca']} -> ID: {id_marca}")
            
            # Actualizar producto
            exito = safe_execute(
                self.producto_repo.actualizar_producto, 
                producto_actual['id'], 
                datos_mapeados
            )
            
            if exito:
                # Refrescar datos
                self.refresh_productos()
                
                self.operacionExitosa.emit(f"Producto actualizado: {codigo}")
                print(f"🔧 Producto actualizado - {codigo}, Usuario: {self._usuario_actual_id}")
                return True
            else:
                raise Exception("Error actualizando producto en base de datos")
                
        except json.JSONDecodeError:
            self.operacionError.emit("Error: Formato de datos inválido")
        except ProductoNotFoundError:
            self.operacionError.emit(f"Producto no encontrado: {codigo}")
        except Exception as e:
            self.operacionError.emit(f"Error actualizando producto: {str(e)}")
        finally:
            self._set_loading(False)
        
        return False
    
    @Slot(str, result=bool)
    def eliminar_producto(self, codigo: str):
        """Elimina un producto (solo si no tiene stock) - CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            print(f"❌ ELIMINACIÓN BLOQUEADA: Usuario no autenticado (ID: {self._usuario_actual_id})")
            return False
        
        if not codigo:
            print("❌ ELIMINACIÓN BLOQUEADA: Código de producto requerido")
            self.operacionError.emit("Código de producto requerido")
            return False
        
        print(f"🗑️ INICIANDO ELIMINACIÓN - Código: {codigo}, Usuario: {self._usuario_actual_id}")
        
        self._set_loading(True)
        try:
            # Obtener producto ANTES de intentar eliminar
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
            if not producto:
                print(f"❌ PRODUCTO NO ENCONTRADO: {codigo}")
                raise ProductoNotFoundError(codigo=codigo)
            
            print(f"📊 Producto encontrado: {producto['Nombre']} (ID: {producto['id']}) - Stock: {producto.get('Stock_Total', 0)}")
            
            # Verificar stock antes de eliminar
            """""
            stock_total = producto.get('Stock_Total', 0)
            if stock_total > 0:
                mensaje_error = f"No se puede eliminar: el producto '{producto['Nombre']}' tiene {stock_total} unidades en stock"
                print(f"❌ ELIMINACIÓN BLOQUEADA POR STOCK: {mensaje_error}")
                self.operacionError.emit(mensaje_error)
                return False
            
            print(f"✅ VALIDACIÓN PASADA - Producto sin stock, procediendo a eliminar...")
            """""
            # Eliminar producto usando el repository
            exito = safe_execute(self.producto_repo.eliminar_producto, producto['id'])
            
            if exito:
                print(f"✅ ELIMINACIÓN EXITOSA EN BD - Producto: {codigo}")
                
                # Refrescar datos inmediatamente
                print("🔄 Refrescando datos después de eliminación...")
                self.refresh_productos()
                self._cargar_lotes_activos()
                
                # Emitir señales de éxito
                mensaje_exito = f"Producto eliminado: {codigo}"
                self.operacionExitosa.emit(mensaje_exito)
                self.productoEliminado.emit(codigo)
                
                print(f"✅ ELIMINACIÓN COMPLETA - {codigo}, Usuario: {self._usuario_actual_id}")
                return True
            else:
                print(f"❌ ERROR EN BD - No se pudo eliminar producto {codigo}")
                raise Exception("Error eliminando producto en base de datos")
                
        except ProductoNotFoundError:
            mensaje_error = f"Producto no encontrado: {codigo}"
            print(f"❌ PRODUCTO NO ENCONTRADO: {mensaje_error}")
            self.operacionError.emit(mensaje_error)
        except Exception as e:
            mensaje_error = f"Error eliminando producto: {str(e)}"
            print(f"❌ ERROR GENERAL EN ELIMINACIÓN: {mensaje_error}")
            self.operacionError.emit(mensaje_error)
        finally:
            self._set_loading(False)
        
        return False

    @Slot(str, result=str)
    def debug_eliminar_producto(self, codigo: str):
        """Método de debug para verificar que QML puede llamar a Python"""
        mensaje_debug = f"DEBUG: Método Python llamado correctamente para código {codigo}. Usuario: {self._usuario_actual_id}"
        print(f"🔍 {mensaje_debug}")
        self.operacionExitosa.emit(f"Debug: Conexión QML-Python OK para {codigo}")
        return mensaje_debug
    
    @Slot(str, float, result=bool)
    def actualizar_precio_venta(self, codigo: str, nuevo_precio: float):
        """Actualiza el precio de venta de un producto - CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # VERIFICAR AUTENTICACIÓN
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
            exito = safe_execute(self.producto_repo.actualizar_producto, producto['id'], datos_actualizacion)
            
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
    
    # ===============================
    # SLOTS PARA QML - CRUD LOTES - CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(str, int, str, float, result=bool)
    def agregar_stock_producto(self, codigo: str, cantidad_unitario: int, 
                            fecha_vencimiento: str, precio_compra: float = 0):
        """
        Agrega stock a un producto creando un nuevo lote - CON VERIFICACIÓN DE AUTENTICACIÓN - SIN CAJAS
        """
        # VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        if not codigo or cantidad_unitario <= 0:
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
            fecha_procesada = self._procesar_fecha_vencimiento(fecha_vencimiento)
            
            # Crear nuevo lote y aumentar stock (SIN CAJAS)
            lote_id = safe_execute(
                self.producto_repo.aumentar_stock_compra,
                producto['id'],
                cantidad_unitario,
                fecha_procesada,
                precio_compra if precio_compra > 0 else None
            )
            
            if lote_id:
                # Refrescar datos
                self.refresh_productos()
                self._cargar_lotes_activos()
                
                # Obtener nuevo stock total
                nuevo_stock = self.obtener_stock_total_producto(codigo)
                
                self.operacionExitosa.emit(f"Stock agregado: {codigo} (+{cantidad_unitario} unidades)")
                self.stockActualizado.emit(codigo, nuevo_stock)
                print(f"📈 Stock agregado - {codigo}: +{cantidad_unitario} unidades, Lote: {lote_id}, Usuario: {self._usuario_actual_id}")
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
    
    @Slot(int, result=bool)
    def eliminar_lote(self, lote_id: int):
        """Elimina un lote específico - CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        if lote_id <= 0:
            self.operacionError.emit("ID de lote inválido")
            return False
        
        self._set_loading(True)
        try:
            print(f"🗑️ Eliminando lote - ID: {lote_id}, Usuario: {self._usuario_actual_id}")
            
            # Eliminar lote
            exito = safe_execute(self.producto_repo.eliminar_lote, lote_id)
            
            if exito:
                # Refrescar datos
                self.refresh_productos()
                self._cargar_lotes_activos()
                
                self.operacionExitosa.emit(f"Lote eliminado: ID {lote_id}")
                print(f"🗑️ Lote eliminado - ID: {lote_id}, Usuario: {self._usuario_actual_id}")
                return True
            else:
                raise Exception("Error eliminando lote")
                
        except Exception as e:
            self.operacionError.emit(f"Error eliminando lote: {str(e)}")
        finally:
            self._set_loading(False)
        
        return False
    
    @Slot(int, str, result=bool)
    def actualizar_lote(self, lote_id: int, lote_json: str):
        """Actualiza un lote específico - CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        if lote_id <= 0 or not lote_json:
            self.operacionError.emit("ID de lote y datos requeridos")
            return False
        
        self._set_loading(True)
        try:
            print(f"🔧 Actualizando lote - ID: {lote_id}, Usuario: {self._usuario_actual_id}")
            
            # Parsear datos
            datos = json.loads(lote_json)
            
            # Procesar fecha si existe
            if 'fecha_vencimiento' in datos:
                datos['Fecha_Vencimiento'] = self._procesar_fecha_vencimiento(datos['fecha_vencimiento'])
                del datos['fecha_vencimiento']
            
            # Procesar cantidad si existe
            if 'cantidad_unitario' in datos:
                datos['Cantidad_Unitario'] = int(datos['cantidad_unitario'])
                del datos['cantidad_unitario']
            
            # Actualizar lote
            exito = safe_execute(self.producto_repo.actualizar_lote, lote_id, datos)
            
            if exito:
                # Refrescar datos
                self.refresh_productos()
                self._cargar_lotes_activos()
                
                self.operacionExitosa.emit(f"Lote actualizado: ID {lote_id}")
                print(f"🔧 Lote actualizado - ID: {lote_id}, Usuario: {self._usuario_actual_id}")
                return True
            else:
                raise Exception("Error actualizando lote")
                
        except json.JSONDecodeError:
            self.operacionError.emit("Error: Formato de datos inválido")
        except Exception as e:
            self.operacionError.emit(f"Error actualizando lote: {str(e)}")
        finally:
            self._set_loading(False)
        
        return False
    
    # ===============================
    # SLOTS PARA QML - VENTAS - CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(int, str, result=bool)
    def procesar_venta_rapida(self, usuario_id: int, items_json: str):
        """Procesa venta rápida desde QML - CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # VERIFICAR AUTENTICACIÓN PRIMERO
        if not self._verificar_autenticacion():
            return False
        
        # VERIFICAR QUE EL USUARIO COINCIDA
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
        """Venta simple de un producto - CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        # VERIFICAR QUE EL USUARIO COINCIDA
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
    # SLOTS PARA QML - COMPRAS - CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(int, int, str, result=bool)
    def procesar_compra(self, proveedor_id: int, usuario_id: int, items_json: str):
        """
        Procesa compra desde QML - CON VERIFICACIÓN DE AUTENTICACIÓN - SIN CAJAS
        """
        # VERIFICAR AUTENTICACIÓN PRIMERO
        if not self._verificar_autenticacion():
            return False
        
        # VERIFICAR QUE EL USUARIO COINCIDA
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
        """Crea proveedor rápidamente - CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # VERIFICAR AUTENTICACIÓN
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
    # SLOTS PARA CONSULTAS ESPECÍFICAS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(result='QVariant')
    def get_marcas_disponibles(self):
        """Obtiene lista de marcas disponibles - CORREGIDO"""
        try:
            # Si ya tenemos marcas cargadas, devolverlas
            if self._marcas and len(self._marcas) > 0:
                print(f"🏷️ Marcas disponibles desde cache: {len(self._marcas)}")
                return self._marcas
            
            # Si no, cargarlas
            print("🔄 Cargando marcas desde BD...")
            self._marcas = self._cargar_marcas() or []
            self.marcasChanged.emit()
            
            print(f"🏷️ Marcas cargadas: {len(self._marcas)}")
            return self._marcas
            
        except Exception as e:
            print(f"❌ Error obteniendo marcas: {e}")
            self.operacionError.emit(f"Error obteniendo marcas: {str(e)}")
            return []

    @Slot(str, result='QVariant')
    def get_producto_detalle_completo(self, codigo: str):
        """
        Obtiene detalles completos de un producto incluyendo TODOS sus lotes - SIN VERIFICACIÓN (solo lectura) - SIN CAJAS
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
            
            # Calcular estadísticas (SIN CAJAS)
            stock_total = 0
            lotes_vencidos = 0
            lotes_por_vencer = 0
            
            from datetime import datetime
            hoy = datetime.now()
            
            for lote in lotes:
                stock_lote = lote.get('Cantidad_Unitario', 0)  # Solo unitario
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
                'lotes_count': len([l for l in lotes if l.get('Cantidad_Unitario', 0) > 0]),
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
    # MÉTODOS PRIVADOS - CORREGIDOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga datos iniciales al crear el model"""
        self._set_loading(True)
        try:
            # Forzar refresh de productos antes de cargar
            if hasattr(self, 'producto_repo') and self.producto_repo:
                self.refresh_productos()
            
            # Cargar y normalizar productos
            productos_raw = safe_execute(self.producto_repo.get_productos_con_marca) or []
            self._productos = []
            for producto in productos_raw:
                try:
                    producto_normalizado = self._normalizar_producto(producto)
                    self._productos.append(producto_normalizado)
                except Exception as e:
                    print(f"Error normalizando producto: {e}")
                    continue
            
            # Cargar datos complementarios
            self._marcas = self._cargar_marcas() or []
            self._proveedores = safe_execute(self.compra_repo.get_proveedores_activos) or []
            self._cargar_lotes_activos()
            self._actualizar_alertas()
            
            print(f"Datos iniciales cargados - Productos: {len(self._productos)}")
            
            # Emitir signals de cambio
            self.productosChanged.emit()
            self.marcasChanged.emit()
            self.proveedoresChanged.emit()
            
        except Exception as e:
            print(f"Error cargando datos iniciales: {e}")
            self.operacionError.emit(f"Error cargando datos: {str(e)}")
            # Inicializar listas vacías para evitar errores
            self._productos = []
            self._marcas = []
            self._proveedores = []
            self._lotes_activos = []
            self._alertas = []
        finally:
            self._set_loading(False)
    
    def _cargar_marcas(self):
        """Carga lista de marcas - CORREGIDO - Normalización consistente"""
        try:
            query = "SELECT id, Nombre, Detalles FROM Marca ORDER BY Nombre"
            marcas_raw = self.producto_repo._execute_query(query, use_cache=False) or []
            
            # ✅ Normalizar marcas con AMBAS nomenclaturas (mayúscula y minúscula)
            marcas_normalizadas = []
            for marca in marcas_raw:
                # Obtener valores con fallbacks
                marca_id = marca.get('id', 0)
                marca_nombre = marca.get('Nombre', '')
                marca_detalles = marca.get('Detalles', '')
                
                # Validar que tenga ID y nombre
                if marca_id > 0 and marca_nombre:
                    marca_normalizada = {
                        # ID
                        'id': marca_id,
                        
                        # Nombre - AMBAS nomenclaturas
                        'Nombre': marca_nombre,  # Para backend
                        'nombre': marca_nombre,  # Para QML
                        
                        # Detalles - AMBAS nomenclaturas
                        'Detalles': marca_detalles,  # Para backend
                        'detalles': marca_detalles   # Para QML
                    }
                    marcas_normalizadas.append(marca_normalizada)
            
            print(f"🏷️ Marcas cargadas desde BD: {len(marcas_normalizadas)}")
            
            # Debug: Mostrar primeras 3 marcas
            if marcas_normalizadas:
                for i, marca in enumerate(marcas_normalizadas[:3]):
                    print(f"   {i+1}. ID: {marca['id']}, Nombre: {marca['nombre']}")
            
            return marcas_normalizadas
            
        except Exception as e:
            print(f"❌ Error cargando marcas: {e}")
            import traceback
            traceback.print_exc()
            return []
        
    def _cargar_lotes_activos(self):
        """Carga lotes activos - SIN CAJAS"""
        try:
            query = """
            SELECT l.*, p.Codigo, p.Nombre as Producto_Nombre,
                l.Cantidad_Unitario as Stock_Lote
            FROM Lote l
            INNER JOIN Productos p ON l.Id_Producto = p.id
            WHERE l.Cantidad_Unitario > 0
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
    
    def _emit_productos_changed(self):
        """
        ✅ NUEVO: Emite el signal productosChanged con debounce
        Esto evita múltiples emisiones rápidas que causan loops infinitos
        """
        if self._pending_productos_emit:
            print("📢 Emitiendo signal productosChanged (debounced)")
            self.productosChanged.emit()
            self.operacionExitosa.emit("Productos actualizados (FIFO habilitado)")
            self._pending_productos_emit = False
    
    def _schedule_productos_changed(self):
        """
        ✅ NUEVO: Programa la emisión del signal productosChanged
        Si ya hay una emisión pendiente, la retrasa 500ms más
        """
        self._pending_productos_emit = True
        self._debounce_timer.stop()  # Detener timer anterior si existe
        self._debounce_timer.start(500)  # Emitir en 500ms
        
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()

    def _validar_datos_producto(self, datos: dict) -> bool:
        """Valida datos de producto antes de guardar"""
        # Validaciones básicas
        if not datos.get('codigo') and not datos.get('nombre'):
            raise ValueError("Debe especificar al menos un nombre para el producto")
        
        if not datos.get('nombre') or len(datos['nombre'].strip()) < 3:
            raise ValueError("Nombre debe tener al menos 3 caracteres")
        
        if datos.get('precio_compra', 0) <= 0:
            raise ValueError("Precio de compra debe ser mayor a 0")
        
        if datos.get('precio_venta', 0) <= 0:
            raise ValueError("Precio de venta debe ser mayor a 0")
        
        if datos.get('precio_venta', 0) <= datos.get('precio_compra', 0):
            raise ValueError("Precio de venta debe ser mayor al precio de compra")
        
        return True
    
    def _validate_date_format(self, fecha_str: str) -> bool:
        """Valida formato de fecha YYYY-MM-DD"""
        if not fecha_str or not isinstance(fecha_str, str):
            return True  # Fechas vacías son válidas (sin vencimiento)
        
        fecha_clean = fecha_str.strip()
        if not fecha_clean or fecha_clean.lower() in ["sin vencimiento", ""]:
            return True
        
        # Validar formato YYYY-MM-DD
        try:
            datetime.strptime(fecha_clean, '%Y-%m-%d')
            return True
        except ValueError:
            return False
    
    def _normalizar_producto(self, producto_raw: dict) -> dict:
        """
        Normaliza un producto de BD para uso consistente en QML - SIN CAJAS - CORREGIDO
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
            
            # STOCK CALCULADO DESDE LOTES (CORREGIDO)
            stock_total = safe_int(
                producto_raw.get('Stock_Total') or 
                producto_raw.get('Stock_Calculado', 0)
            )
            
            # Producto normalizado con doble nomenclatura para compatibilidad - SIN CAJAS - CORREGIDO
            producto_normalizado = {
                # ID
                'id': safe_int(producto_raw.get('id', 0)),
                
                # Código - múltiples variantes
                'codigo': safe_str(producto_raw.get('Codigo') or producto_raw.get('codigo', '')),
                'Codigo': safe_str(producto_raw.get('Codigo') or producto_raw.get('codigo', '')),
                
                # Nombre - múltiples variantes
                'nombre': safe_str(producto_raw.get('Nombre') or producto_raw.get('nombre', '')),
                'Nombre': safe_str(producto_raw.get('Nombre') or producto_raw.get('nombre', '')),
                
                # Detalles/Descripción
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
                
                # Stock - CALCULADO DESDE LOTES (CORREGIDO)
                'stockUnitario': stock_total,
                'Stock_Unitario': stock_total,
                'Stock_Total': stock_total,
                
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
                'stockUnitario': 0,
                'idMarca': 'ERROR'
            }
    
    def obtener_stock_total_producto(self, codigo: str) -> int:
        """Obtiene el stock total de un producto por código - CALCULADO DESDE LOTES"""
        try:
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo)
            if producto:
                # Stock total calculado desde lotes
                return producto.get('Stock_Total', 0)
            return 0
        except Exception:
            return 0
    
    def _generar_codigo_automatico(self) -> str:
        """Genera código automático para producto"""
        import time
        return f"PROD{int(time.time() * 1000) % 1000000}"
    
    def _obtener_id_marca(self, nombre_marca: str) -> int:
        """Obtiene ID de marca por nombre, crea si no existe - CORREGIDO"""
        if not nombre_marca or not isinstance(nombre_marca, str):
            print(f"⚠️ Nombre de marca inválido: {nombre_marca}")
            return 1  # Marca por defecto
        
        nombre_limpio = nombre_marca.strip()
        if len(nombre_limpio) < 2:
            return 1
        
        print(f"🔍 Buscando marca por nombre: '{nombre_limpio}'")
        
        try:
            # Buscar marca existente
            for marca in self._marcas:
                marca_nombre = marca.get('Nombre') or marca.get('nombre', '')
                if marca_nombre and marca_nombre.lower() == nombre_limpio.lower():
                    print(f"✅ Marca encontrada: {marca_nombre} (ID: {marca['id']})")
                    return marca['id']
            
            # Si no existe, crear nueva marca
            print(f"🏷️ Creando nueva marca: '{nombre_limpio}'")
            query = "INSERT INTO Marca (Nombre, Detalles) OUTPUT INSERTED.id VALUES (?, ?)"
            resultado = self.producto_repo._execute_query(
                query, 
                (nombre_limpio, f"Marca creada automáticamente"), 
                fetch_one=True
            )
            
            if resultado and 'id' in resultado:
                nueva_marca_id = resultado['id']
                # Actualizar lista de marcas
                self._marcas = self._cargar_marcas() or []
                print(f"✅ Nueva marca creada: '{nombre_limpio}' (ID: {nueva_marca_id})")
                return nueva_marca_id
            
            return 1  # Fallback a marca por defecto
            
        except Exception as e:
            print(f"❌ Error obteniendo/creando marca '{nombre_limpio}': {e}")
            return 1
    
    def _procesar_fecha_vencimiento(self, fecha_str: str) -> str:
        """Procesa fecha de vencimiento para BD"""
        if not fecha_str or fecha_str.strip() == "" or fecha_str.lower() == "sin vencimiento":
            return None
        
        fecha_clean = fecha_str.strip()
        
        # Validar formato YYYY-MM-DD
        try:
            datetime.strptime(fecha_clean, '%Y-%m-%d')
            return fecha_clean
        except ValueError:
            # Si no es válida, retornar None (sin vencimiento)
            return None

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
            self._usuario_actual_id = 0  # RESETEAR USUARIO
            
            # Anular repositories
            self.producto_repo = None
            self.venta_repo = None
            self.compra_repo = None
            
            print("✅ InventarioModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión InventarioModel: {e}")

    def _verificar_marca_existe(self, marca_id: int) -> bool:
        """Verifica si una marca existe en la base de datos"""
        try:
            query = "SELECT id FROM Marca WHERE id = ?"
            resultado = self.producto_repo._execute_query(query, (marca_id,), fetch_one=True)
            return resultado is not None and 'id' in resultado
        except Exception as e:
            print(f"❌ Error verificando marca ID {marca_id}: {e}")
            return False
        
    @Slot(result='QVariant')
    def obtener_stock_actual(self):
        """
        🚀 FIFO 2.0: Obtiene stock actual de productos usando vista vw_Stock_Actual
        ✅ COLUMNAS: id, Codigo, Nombre, Marca, Stock_Real, Estado_Stock, 
                    Proximo_Vencimiento, Stock_Minimo, Stock_Maximo, Activo
        """
        try:
            stock = safe_execute(self.producto_repo.obtener_stock_actual) or []
            print(f"📦 Stock actual obtenido: {len(stock)} productos")
            return stock
        except Exception as e:
            print(f"❌ Error obteniendo stock actual: {e}")
            self.operacionError.emit(f"Error obteniendo stock: {str(e)}")
            return []

    @Slot(result='QVariant')
    def obtener_alertas_inventario(self):
        """
        🚀 FIFO 2.0: Obtiene alertas de inventario usando vista vw_Alertas_Inventario
        ✅ COLUMNAS: Tipo_Alerta, id, Codigo, Nombre, Stock_Minimo, Stock_Real, Detalle
        ✅ TIPOS: 'STOCK BAJO', 'PRODUCTO PRÓXIMO A VENCER', 'PRODUCTO VENCIDO'
        """
        try:
            alertas = safe_execute(self.producto_repo.obtener_alertas_inventario) or []
            
            # Actualizar cache interno de alertas
            self._alertas = alertas
            self.alertasChanged.emit()
            
            print(f"🔔 Alertas inventario obtenidas: {len(alertas)} alertas")
            
            # Debug: mostrar distribución por tipo
            tipos = {}
            for alerta in alertas:
                tipo = alerta.get('Tipo_Alerta', 'DESCONOCIDO')
                tipos[tipo] = tipos.get(tipo, 0) + 1
            
            for tipo, count in tipos.items():
                print(f"   - {tipo}: {count} alertas")
            
            return alertas
            
        except Exception as e:
            print(f"❌ Error obteniendo alertas: {e}")
            self.operacionError.emit(f"Error obteniendo alertas: {str(e)}")
            return []

    @Slot(int, result='QVariant')
    def obtener_lotes_activos_vista(self, producto_id: int = 0):
        """
        🚀 FIFO 2.0: Obtiene lotes activos usando vista vw_Lotes_Activos
        ✅ COLUMNAS: id, Id_Producto, Codigo, Producto, Marca, Cantidad_Inicial,
                    Stock_Actual, Precio_Compra, Fecha_Compra, Fecha_Vencimiento,
                    Dias_para_Vencer, Estado_Vencimiento, Estado_Lote, Id_Compra, Proveedor
        
        Args:
            producto_id: ID del producto (0 = todos los lotes)
        """
        try:
            lotes = safe_execute(
                self.producto_repo.obtener_lotes_activos_vista, 
                producto_id if producto_id > 0 else None
            ) or []
            
            if producto_id > 0:
                print(f"📦 Lotes del producto {producto_id}: {len(lotes)} lotes")
            else:
                print(f"📦 Lotes activos totales: {len(lotes)} lotes")
            
            # Debug: mostrar estados de vencimiento
            estados = {}
            for lote in lotes:
                estado = lote.get('Estado_Vencimiento', 'DESCONOCIDO')
                estados[estado] = estados.get(estado, 0) + 1
            
            for estado, count in estados.items():
                print(f"   - {estado}: {count} lotes")
            
            return lotes
            
        except Exception as e:
            print(f"❌ Error obteniendo lotes activos: {e}")
            self.operacionError.emit(f"Error obteniendo lotes: {str(e)}")
            return []

    @Slot(result='QVariant')
    def obtener_costo_inventario(self):
        """
        🚀 FIFO 2.0: Obtiene valorización del inventario usando vista vw_Costo_Inventario
        ✅ COLUMNAS: Id_Producto, Codigo, Producto, Unidad_Medida, Stock_Total,
                    Costo_Promedio, Valor_Inventario_Costo, Valor_Inventario_Venta,
                    Margen_Potencial, Porcentaje_Margen
        """
        try:
            valoracion = safe_execute(self.producto_repo.obtener_costo_inventario) or []
            print(f"💰 Valoración de inventario: {len(valoracion)} productos")
            
            if valoracion:
                total_costo = sum(item.get('Valor_Inventario_Costo', 0) or 0 for item in valoracion)
                total_venta = sum(item.get('Valor_Inventario_Venta', 0) or 0 for item in valoracion)
                print(f"   - Valor costo: ${total_costo:,.2f}")
                print(f"   - Valor venta: ${total_venta:,.2f}")
                print(f"   - Margen potencial: ${total_venta - total_costo:,.2f}")
            
            return valoracion
            
        except Exception as e:
            print(f"❌ Error obteniendo valoración: {e}")
            self.operacionError.emit(f"Error obteniendo valoración: {str(e)}")
            return []

    @Slot(int, result='QVariant')
    def obtener_rotacion_inventario(self, dias: int = 30):
        """
        🚀 FIFO 2.0: Obtiene rotación de inventario usando vista vw_Rotacion_Inventario
        ✅ COLUMNAS: Id_Producto, Codigo, Producto, Unidad_Medida, Stock_Actual,
                    Ventas_Periodo, Compras_Periodo, Dias_Stock, Indice_Rotacion,
                    Clasificacion (A, B, C)
        """
        try:
            rotacion = safe_execute(
                self.producto_repo.obtener_rotacion_inventario, 
                dias
            ) or []
            
            print(f"📈 Rotación de inventario ({dias} días): {len(rotacion)} productos")
            
            if rotacion:
                # Contar por clasificación
                clasificaciones = {}
                for item in rotacion:
                    clasif = item.get('Clasificacion', 'C')
                    clasificaciones[clasif] = clasificaciones.get(clasif, 0) + 1
                
                for clasif, count in sorted(clasificaciones.items()):
                    print(f"   - Clase {clasif}: {count} productos")
            
            return rotacion
            
        except Exception as e:
            print(f"❌ Error obteniendo rotación: {e}")
            self.operacionError.emit(f"Error obteniendo rotación: {str(e)}")
            return []

    @Slot(result='QVariant')
    def obtener_dashboard_metricas(self):
        """
        🚀 FIFO 2.0: Obtiene métricas consolidadas para dashboard
        ✅ RETORNA:
            {
                'stock_critico': int,
                'lotes_proximos_vencer': int,
                'valor_inventario': float,
                'alertas_activas': int,
                'top_rotacion': [...]
            }
        """
        try:
            metricas = safe_execute(self.producto_repo.obtener_dashboard_metricas) or {}
            
            print(f"📊 Métricas dashboard obtenidas:")
            print(f"   - Stock crítico: {metricas.get('stock_critico', 0)}")
            print(f"   - Próximos a vencer: {metricas.get('lotes_proximos_vencer', 0)}")
            print(f"   - Valor inventario: ${metricas.get('valor_inventario', 0):,.2f}")
            print(f"   - Alertas activas: {metricas.get('alertas_activas', 0)}")
            
            return metricas
            
        except Exception as e:
            print(f"❌ Error obteniendo métricas dashboard: {e}")
            self.operacionError.emit(f"Error obteniendo métricas: {str(e)}")
            return {}

    # ===============================
    # 🚀 SLOTS FIFO 2.0 - COMPRAS Y VENTAS
    # ===============================

    @Slot(int, int, str, result='QVariant')
    def registrar_compra_con_lotes(self, proveedor_id: int, usuario_id: int, detalles_json: str):
        """
        🚀 FIFO 2.0: Registra compra usando SP sp_Registrar_Compra_Con_Lotes
        
        Args:
            proveedor_id: ID del proveedor
            usuario_id: ID del usuario que realiza la compra
            detalles_json: JSON con detalles de compra:
                [
                    {
                        "Id_Producto": 1,
                        "Cantidad": 100,
                        "Precio": 25.50,
                        "Fecha_Vencimiento": "2025-12-31",  # opcional
                        "Precio_Venta": 35.00  # opcional, solo para primera compra
                    },
                    ...
                ]
        
        Returns:
            {
                "id_compra": int,
                "total": float,
                "mensaje": str,
                "sistema": "FIFO 2.0"
            }
        """
        # VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return {"error": "No autenticado"}
        
        # VERIFICAR QUE EL USUARIO COINCIDA
        if usuario_id != self._usuario_actual_id:
            self.operacionError.emit("ID de usuario no coincide con el autenticado")
            return {"error": "Usuario no coincide"}
        
        if proveedor_id <= 0 or usuario_id <= 0 or not detalles_json:
            self.operacionError.emit("Datos de compra inválidos")
            return {"error": "Datos inválidos"}
        
        self._set_loading(True)
        try:
            print(f"🛒 Registrando compra FIFO 2.0 - Proveedor: {proveedor_id}, Usuario: {usuario_id}")
            
            # Parsear JSON
            import json
            detalles = json.loads(detalles_json)
            
            if not detalles:
                raise CompraError("No hay items para comprar")
            
            # Llamar al repository con SP
            resultado = safe_execute(
                self.compra_repo.registrar_compra_con_lotes,
                proveedor_id,
                usuario_id,
                detalles
            )
            
            if resultado and resultado.get('id_compra'):
                # Actualizar datos
                self.refresh_productos()
                self._cargar_lotes_activos()
                self._actualizar_alertas()
                
                mensaje = f"Compra {resultado['id_compra']} registrada - Total: ${resultado['total']:.2f}"
                self.operacionExitosa.emit(mensaje)
                print(f"✅ {mensaje}")
                
                return resultado
            else:
                raise CompraError("Error en procedimiento almacenado")
        
        except json.JSONDecodeError:
            self.operacionError.emit("Error: Formato JSON inválido")
            return {"error": "JSON inválido"}
        except Exception as e:
            self.operacionError.emit(f"Error en compra: {str(e)}")
            return {"error": str(e)}
        finally:
            self._set_loading(False)

    @Slot(int, str, result='QVariant')
    def registrar_venta_fifo(self, usuario_id: int, detalles_json: str):
        """
        🚀 FIFO 2.0: Registra venta usando SP sp_Vender_Producto_FIFO
        
        Args:
            usuario_id: ID del usuario que realiza la venta
            detalles_json: JSON con detalles de venta:
                [
                    {
                        "Id_Producto": 1,
                        "Cantidad": 10,
                        "Precio_Venta": 35.00
                    },
                    ...
                ]
        
        Returns:
            {
                "id_venta": int,
                "total": float,
                "mensaje": str,
                "sistema": "FIFO 2.0"
            }
        """
        # VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return {"error": "No autenticado"}
        
        # VERIFICAR QUE EL USUARIO COINCIDA
        if usuario_id != self._usuario_actual_id:
            self.operacionError.emit("ID de usuario no coincide con el autenticado")
            return {"error": "Usuario no coincide"}
        
        if usuario_id <= 0 or not detalles_json:
            self.operacionError.emit("Datos de venta inválidos")
            return {"error": "Datos inválidos"}
        
        self._set_loading(True)
        try:
            print(f"💰 Registrando venta FIFO 2.0 - Usuario: {usuario_id}")
            
            # Parsear JSON
            import json
            detalles = json.loads(detalles_json)
            
            if not detalles:
                raise VentaError("No hay items para vender")
            
            # Llamar al repository con SP
            resultado = safe_execute(
                self.venta_repo.registrar_venta_fifo,
                usuario_id,
                detalles
            )
            
            if resultado and resultado.get('id_venta'):
                # Actualizar datos
                self.refresh_productos()
                self._cargar_lotes_activos()
                self._actualizar_alertas()
                
                mensaje = f"Venta {resultado['id_venta']} procesada - Total: ${resultado['total']:.2f}"
                self.operacionExitosa.emit(mensaje)
                print(f"✅ {mensaje}")
                
                return resultado
            else:
                raise VentaError("Error en procedimiento almacenado")
        
        except json.JSONDecodeError:
            self.operacionError.emit("Error: Formato JSON inválido")
            return {"error": "JSON inválido"}
        except Exception as e:
            self.operacionError.emit(f"Error en venta: {str(e)}")
            return {"error": str(e)}
        finally:
            self._set_loading(False)

    @Slot(int, result='QVariant')
    def obtener_margen_venta(self, venta_id: int):
        """
        🚀 FIFO 2.0: Obtiene márgenes detallados de una venta usando SP sp_Obtener_Margen_Venta
        
        Args:
            venta_id: ID de la venta
        
        Returns:
            Lista con detalles de márgenes por producto:
            [
                {
                    "Producto": str,
                    "Cantidad": int,
                    "Precio_Venta": float,
                    "Total_Venta": float,
                    "Costo_FIFO": float,
                    "Costo_Total": float,
                    "Margen_Unitario": float,
                    "Margen_Total": float,
                    "Porcentaje_Margen": float
                },
                ...
            ]
        """
        try:
            if venta_id <= 0:
                self.operacionError.emit("ID de venta inválido")
                return []
            
            print(f"💰 Obteniendo márgenes de venta {venta_id}")
            
            margenes = safe_execute(
                self.venta_repo.obtener_margen_venta,
                venta_id
            ) or []
            
            if margenes:
                total_margen = sum(m.get('Margen_Total', 0) or 0 for m in margenes)
                total_venta = sum(m.get('Total_Venta', 0) or 0 for m in margenes)
                
                print(f"   - Total venta: ${total_venta:.2f}")
                print(f"   - Margen total: ${total_margen:.2f}")
            
            return margenes
            
        except Exception as e:
            print(f"❌ Error obteniendo márgenes: {e}")
            self.operacionError.emit(f"Error obteniendo márgenes: {str(e)}")
            return []

    @Slot(str, str, result='QVariant')
    def obtener_reporte_margenes_periodo(self, fecha_desde: str, fecha_hasta: str):
        """
        🚀 FIFO 2.0: Obtiene reporte consolidado de márgenes en un periodo
        
        Args:
            fecha_desde: Fecha inicial (YYYY-MM-DD)
            fecha_hasta: Fecha final (YYYY-MM-DD)
        
        Returns:
            {
                "periodo": str,
                "total_ventas": int,
                "total_vendido": float,
                "total_costo": float,
                "margen_total": float,
                "porcentaje_margen": float,
                "detalles_por_venta": [...]
            }
        """
        try:
            if not fecha_desde or not fecha_hasta:
                self.operacionError.emit("Fechas requeridas")
                return {}
            
            print(f"📊 Generando reporte de márgenes: {fecha_desde} a {fecha_hasta}")
            
            reporte = safe_execute(
                self.venta_repo.obtener_reporte_margenes_periodo,
                fecha_desde,
                fecha_hasta
            ) or {}
            
            if reporte:
                print(f"   - Ventas: {reporte.get('total_ventas', 0)}")
                print(f"   - Total vendido: ${reporte.get('total_vendido', 0):.2f}")
                print(f"   - Margen: ${reporte.get('margen_total', 0):.2f}")
            
            return reporte
            
        except Exception as e:
            print(f"❌ Error generando reporte: {e}")
            self.operacionError.emit(f"Error generando reporte: {str(e)}")
            return {}

    # ===============================
    # 🔧 SLOT PARA EDITAR LOTE
    # ===============================

    @Slot(int, float, int, str, result=bool)
    def actualizar_lote_completo(self, lote_id: int, precio_compra: float, 
                                stock_actual: int, fecha_vencimiento: str):
        """
        🔧 Actualiza un lote específico con validaciones
        
        Args:
            lote_id: ID del lote a actualizar
            precio_compra: Nuevo precio de compra (debe ser > 0)
            stock_actual: Nuevo stock actual (debe ser >= 0 y <= cantidad_inicial)
            fecha_vencimiento: Nueva fecha de vencimiento (opcional, formato YYYY-MM-DD)
        """
        # VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        if lote_id <= 0:
            self.operacionError.emit("ID de lote inválido")
            return False
        
        # Validaciones
        if precio_compra <= 0:
            self.operacionError.emit("Precio de compra debe ser mayor a 0")
            return False
        
        if stock_actual < 0:
            self.operacionError.emit("Stock no puede ser negativo")
            return False
        
        self._set_loading(True)
        try:
            print(f"🔧 Actualizando lote {lote_id} - Precio: ${precio_compra}, Stock: {stock_actual}")
            
            # Obtener lote actual para validar stock máximo
            lote_actual = safe_execute(
                self.producto_repo._execute_query,
                "SELECT Cantidad_Inicial FROM Lote WHERE id = ?",
                (lote_id,),
                fetch_one=True
            )
            
            if not lote_actual:
                raise Exception("Lote no encontrado")
            
            cantidad_inicial = lote_actual.get('Cantidad_Inicial', 0)
            
            if stock_actual > cantidad_inicial:
                self.operacionError.emit(
                    f"Stock no puede exceder cantidad inicial ({cantidad_inicial})"
                )
                return False
            
            # Procesar fecha de vencimiento
            fecha_procesada = self._procesar_fecha_vencimiento(fecha_vencimiento)
            
            # Preparar datos de actualización
            datos = {
                'Precio_Compra': precio_compra,
                'Cantidad_Unitario': stock_actual
            }
            
            if fecha_procesada:
                datos['Fecha_Vencimiento'] = fecha_procesada
            
            # Actualizar lote
            exito = safe_execute(self.producto_repo.actualizar_lote, lote_id, datos)
            
            if exito:
                # Refrescar datos
                self.refresh_productos()
                self._cargar_lotes_activos()
                
                self.operacionExitosa.emit(f"Lote {lote_id} actualizado correctamente")
                print(f"✅ Lote {lote_id} actualizado")
                return True
            else:
                raise Exception("Error actualizando lote en base de datos")
        
        except Exception as e:
            self.operacionError.emit(f"Error actualizando lote: {str(e)}")
            return False
        finally:
            self._set_loading(False)

# Registrar el tipo para QML
def register_inventario_model():
    qmlRegisterType(InventarioModel, "ClinicaModels", 1, 0, "InventarioModel")
    print("🔗 InventarioModel CORREGIDO registrado para QML - CRUD COMPLETO - SIN CAJAS")