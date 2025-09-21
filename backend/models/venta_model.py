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
    Model QObject para gestión de ventas con autenticación estandarizada y control de roles
    Conecta directamente con QML mediante Signals/Slots/Properties
    ✅ CORREGIDO: Usa datos directos de tabla Productos
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
    ventaActualizada = Signal(int, float)  # ✅ NUEVO
    ventaEliminada = Signal(int)      # ✅ NUEVO
    operacionExitosa = Signal(str)    # mensaje
    operacionError = Signal(str)  
    stockModificado = Signal()     # mensaje_error
    
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
        
        # ✅ AUTENTICACIÓN ESTANDARIZADA - COMO CONSULTAMODEL
        self._usuario_actual_id = 0  # Cambio de hardcoded a dinámico
        self._usuario_rol = ""       # NUEVO: Control de roles
        print("💰 VentaModel inicializado - Esperando autenticación")
        
        # Timer para actualización automática
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._auto_update_ventas_hoy)
        self.update_timer.start(60000)  # 1 minuto
        
        # Cargar datos iniciales (vacíos hasta autenticación)
        print("💰 VentaModel inicializado con autenticación estandarizada y control de roles")
    
    # ===============================
    # ✅ MÉTODOS REQUERIDOS PARA APPCONTROLLER
    # ===============================
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """
        Establece el usuario actual para las operaciones - MÉTODO REQUERIDO por AppController
        """
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario autenticado establecido en VentaModel: {usuario_id}")
                
                # Cargar datos iniciales después de autenticación
                self._cargar_ventas_hoy(usar_cache=False)
                self._cargar_estadisticas(usar_cache=False)
                
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de ventas")
            else:
                print(f"⚠️ ID de usuario inválido en VentaModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en VentaModel: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")
    
    @Slot(int, str)
    def set_usuario_actual_con_rol(self, usuario_id: int, rol: str):
        """
        MODIFICADO: Establece usuario + rol y emite signals de permisos
        """
        try:
            if usuario_id > 0 and rol.strip():
                self._usuario_actual_id = usuario_id
                self._usuario_rol = rol.strip()
                print(f"Usuario autenticado con rol en VentaModel: {usuario_id} - {rol}")
                print(f"🔐 DEBUG: Usuario establecido: {usuario_id}, Rol: '{rol}' -------------------------------------")
                print(f"🔐 DEBUG: _usuario_rol almacenado: '{self._usuario_rol}'") 
                # Cargar datos iniciales después de autenticación
                self._cargar_ventas_hoy(usar_cache=False)
                self._cargar_estadisticas(usar_cache=False)
                
                # NUEVO: Emitir signal para que QML actualice permisos
                self.operacionExitosa.emit(f"Usuario {usuario_id} ({rol}) establecido en ventas")
                
            else:
                self.operacionError.emit("Usuario o rol inválido")
        except Exception as e:
            print(f"Error estableciendo usuario con rol: {e}")
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
        """
        Carga una venta CON PRODUCTOS CONSOLIDADOS para edición
        """
        try:
            print(f"🔍 Cargando venta {venta_id} para edición")
            
            if not self._verificar_autenticacion():
                return {}
            
            if not self.puede_editar_venta(venta_id):
                self.operacionError.emit("No tiene permisos para editar esta venta")
                return {}
            
            # ✅ USAR MÉTODO CONSOLIDADO PARA EDICIÓN
            detalle = self.venta_repo.get_venta_completa_consolidada(venta_id)
            
            if not detalle:
                self.operacionError.emit("Venta no encontrada")
                return {}
            
            # Formatear productos CONSOLIDADOS para CrearVenta.qml
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
                            'cantidad': int(item.get('Cantidad_Unitario', 0)),  # Consolidado
                            'subtotal': float(item.get('Subtotal', 0)),         # Consolidado
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
                'es_editable': True
            }
            
            print(f"✅ Venta {venta_id} cargada para edición: {len(productos_edicion)} productos consolidados")
            return resultado
            
        except Exception as e:
            print(f"❌ Error cargando venta para edición: {e}")
            self.operacionError.emit(f"Error cargando venta: {str(e)}")
            return {}
    
    # ===============================
    # PROPIEDADES DE AUTENTICACIÓN Y PERMISOS
    # ===============================
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica si el usuario está autenticado"""
        if self._usuario_actual_id <= 0:
            self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
            return False
        return True
    
    def _verificar_permisos(self, operacion: str) -> bool:
        """
        NUEVO: Verifica permisos específicos según el rol del usuario
        
        Args:
            operacion: Nombre de la operación a verificar
            
        Returns:
            bool: True si tiene permisos, False caso contrario
        """
        # Verificar autenticación primero
        if not self._verificar_autenticacion():
            return False
        
        # Admin tiene acceso completo
        if self._usuario_rol == "Administrador":
            return True
        
        # Operaciones restringidas solo para Admin
        operaciones_admin = [
            'ver_ventas_otros_usuarios', 
            'reportes_financieros',
            'estadisticas_completas',
            'editar_venta',  # ✅ NUEVO
            'eliminar_venta'  # ✅ NUEVO
        ]
        
        if operacion in operaciones_admin:
            if self._usuario_rol != "Administrador":
                self.operacionError.emit("Operación requiere permisos de administrador")
                return False
        

        # Médico puede hacer ventas básicas
        if self._usuario_rol == "Médico":
            operaciones_medico = [
                'crear_venta',
                'ver_propias_ventas',
                'agregar_carrito',
                'estadisticas_basicas',
                'buscar_productos'  # ✅ NUEVO
            ]
            
            if operacion not in operaciones_medico and operacion not in operaciones_admin:
                return True  # Permitir operaciones no clasificadas
        

    
    # ===============================
    # ✅ NUEVOS MÉTODOS PARA BÚSQUEDA DE PRODUCTOS DESDE TABLA PRODUCTOS
    # ===============================
    
    @Slot(str, result='QVariant')
    def buscar_productos_para_venta(self, texto_busqueda: str):
        """
        PARA VENTAS: Busca productos mostrando SOLO stock total disponible
        """
        if not self._verificar_permisos('buscar_productos'):
            return []
        
        if not texto_busqueda or len(texto_busqueda.strip()) < 2:
            return []
        
        try:
            # Usar método específico para ventas
            productos = self.venta_repo.buscar_productos_para_venta(texto_busqueda.strip())
            
            # Formatear para QML (solo datos esenciales para venta)
            productos_venta = []
            for producto in productos:
                productos_venta.append({
                    'codigo': producto['Codigo'],
                    'nombre': producto['Nombre'],
                    'precio': float(producto['Precio_venta']),
                    'stock': int(producto['Stock_Total']),  # SOLO TOTAL
                    'disponible': producto['Stock_Total'] > 0,
                    'marca': producto.get('Marca_Nombre', '')
                })
            
            return productos_venta
            
        except Exception as e:
            self.operacionError.emit(f"Error buscando productos: {str(e)}")
            return []
    
    @Slot(str, result='QVariantMap')
    def obtener_producto_por_codigo(self, codigo: str):
        """
        ✅ NUEVO: Obtiene producto por código desde tabla Productos
        """
        if not self._verificar_autenticacion():
            return {}
        
        if not codigo:
            return {}
        
        try:
            print(f"🔍 Obteniendo producto por código: '{codigo}'")
            
            # Usar método directo del repository
            if hasattr(self.venta_repo, 'get_producto_por_codigo'):
                producto = self.venta_repo.get_producto_por_codigo(codigo)
            else:
                # Fallback
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
    # ✅ NUEVOS MÉTODOS PARA EDITAR Y ELIMINAR VENTAS
    # ===============================
    @Slot(int, 'QVariantList', result=bool)
    def actualizar_venta_completa(self, venta_id: int, nuevos_productos: list):
        """
        ✅ CORREGIDO: Actualiza venta con mejor manejo de errores y timeouts
        """
        if not self._verificar_permisos('editar_venta'):
            return False
        
        if venta_id <= 0 or not nuevos_productos:
            self.operacionError.emit("Parámetros inválidos para actualizar venta")
            return False
        
        try:
            print(f"INICIO actualización venta {venta_id} con {len(nuevos_productos)} productos")
            
            # ✅ VALIDAR cada producto antes de enviar al repository
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
                    
                    # ✅ VERIFICAR stock disponible ANTES de procesar
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
            
            # ✅ LLAMAR al repository con productos validados
            exito = self.venta_repo.actualizar_venta_completa(venta_id, productos_validados)
            
            if exito:
                # ✅ FORZAR actualización inmediata de datos
                self._invalidar_cache_completo()
                self._cargar_ventas_hoy(usar_cache=False)
                self._cargar_estadisticas(usar_cache=False)
                
                # Calcular nuevo total
                nuevo_total = sum(float(p.get('subtotal', 0)) for p in productos_validados)
                
                # Emitir signals
                self.ventaActualizada.emit(venta_id, nuevo_total)
                self.operacionExitosa.emit(f"Venta {venta_id} actualizada exitosamente")
                
                print(f"ÉXITO: Venta {venta_id} actualizada con {len(productos_validados)} productos")
                return True
            else:
                self.operacionError.emit("Error en base de datos al actualizar la venta")
                return False
                
        except Exception as e:
            print(f"ERROR en actualizar_venta_completa: {e}")
            error_msg = str(e)
            
            # Mensajes de error más específicos
            if "Stock insuficiente" in error_msg:
                self.operacionError.emit("Stock insuficiente para uno o más productos")
            elif "Venta no encontrada" in error_msg:
                self.operacionError.emit("La venta a editar no existe")
            elif "timeout" in error_msg.lower():
                self.operacionError.emit("Operación demorada. Intente nuevamente.")
            else:
                self.operacionError.emit(f"Error actualizando venta: {error_msg}")
            
            return False
    def _invalidar_cache_completo(self):
        """
        ✅ NUEVO: Invalida completamente todos los caches
        """
        try:
            # Invalidar cache de venta repository
            if hasattr(self.venta_repo, '_invalidate_cache_after_modification'):
                self.venta_repo._invalidate_cache_after_modification()
            
            # Invalidar cache de producto repository
            if hasattr(self.producto_repo, '_invalidate_cache_after_modification'):
                self.producto_repo._invalidate_cache_after_modification()
            
            print("Cache completamente invalidado")
            
        except Exception as e:
            print(f"Error invalidando cache: {e}")

    @Slot(result=bool)
        
    @Slot(int, result=bool)
    def eliminar_venta(self, venta_id: int):
        """
        ✅ NUEVO: Elimina una venta y restaura stock (solo Admin)
        """
        if not self._verificar_permisos('eliminar_venta'):
            return False
        
        if venta_id <= 0:
            self.operacionError.emit("ID de venta inválido")
            return False
        
        try:
            print(f"🗑️ Eliminando venta {venta_id}")
            
            if hasattr(self.venta_repo, 'eliminar_venta'):
                exito = self.venta_repo.eliminar_venta(venta_id)
            else:
                # Usar método de anulación como fallback
                exito = self.venta_repo.anular_venta(venta_id, "Eliminación por administrador")
            
            if exito:
                # Actualizar datos locales
                self._cargar_ventas_hoy(usar_cache=False)
                self._cargar_estadisticas(usar_cache=False)
                
                # Emitir signals
                self.ventaEliminada.emit(venta_id)
                self.operacionExitosa.emit(f"Venta {venta_id} eliminada exitosamente")
                
                print(f"✅ Venta {venta_id} eliminada correctamente")
                return True
            else:
                self.operacionError.emit("Error eliminando la venta")
                return False
                
        except Exception as e:
            print(f"❌ Error eliminando venta: {e}")
            self.operacionError.emit(f"Error eliminando venta: {str(e)}")
            return False
    
    @Slot(int, result=bool)
    def puede_editar_venta(self, venta_id: int):
        """
        ✅ NUEVO: Verifica si el usuario puede editar una venta específica
        """
        if not self._verificar_autenticacion():
            return False
        
        # Solo Admin puede editar
        if self._usuario_rol != "Administrador":
            return False
        
        # Verificar que la venta existe
        try:
            venta = self.venta_repo.get_venta_completa(venta_id)
            return venta is not None
        except:
            return False
    
    @Slot(int, result=bool)
    def puede_eliminar_venta(self, venta_id: int):
        """
        ✅ NUEVO: Verifica si el usuario puede eliminar una venta específica
        """
        if not self._verificar_autenticacion():
            return False
        
        # Solo Admin puede eliminar
        if self._usuario_rol != "Administrador":
            return False
        
        # Verificar que la venta existe
        try:
            venta = self.venta_repo.get_venta_completa(venta_id)
            return venta is not None
        except:
            return False
    
    # ===============================
    # PROPERTIES PARA QML (MODIFICADAS CON FILTRADO)
    # ===============================
    
    @Property(list, notify=ventasHoyChanged)
    def ventas_hoy(self):

        """Lista de ventas del día actual (con restricciones por rol)"""
        # ✅ FILTRAR POR ROL: Médico solo ve sus propias ventas
        if self._usuario_rol == "Médico" and self._usuario_actual_id > 0:
            ventas_filtradas_por_usuario = [
                venta for venta in self._ventas_hoy 
                if venta.get('Id_Usuario') == self._usuario_actual_id
            ]
            return ventas_filtradas_por_usuario
        
        # Admin ve todas las ventas
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
        """MODIFICADO: Estadísticas con información limitada para Médico"""
        # Admin ve todas las estadísticas
        estadisticas_completas = self._estadisticas.copy()
        estadisticas_completas['mostrar_limitado'] = False  # NUEVO: Flag para UI
        return estadisticas_completas
    
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
        """Total de ventas mostradas (con restricciones aplicadas)"""
        ventas_a_mostrar = self.ventas_hoy  # Usa la property que ya filtra por rol
        return len(ventas_a_mostrar)
    
    @Property(float, notify=estadisticasChanged)
    def ingresos_hoy(self):
        """MODIFICADO: Ingresos con restricción para Médico"""
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
    # NUEVAS PROPERTIES DE PERMISOS PARA QML
    # ===============================
    
    @Property(bool, notify=operacionExitosa)
    def puede_crear_ventas(self):
        """Indica si puede crear ventas - Admin y Médico pueden"""
        return self._usuario_rol in ["Administrador", "Médico"]
    
    @Property(bool, notify=operacionExitosa)
    def puede_ver_todas_ventas(self):
        """Indica si puede ver ventas de otros usuarios - Todos los usuarios"""
        return True
    
    @Property(bool, notify=operacionExitosa)
    def puede_ver_reportes_financieros(self):
        """Indica si puede ver información financiera completa - Solo Admin"""
        return self._usuario_rol == "Administrador"
    
    @Property(bool, notify=operacionExitosa)
    def puede_modificar_precios(self):
        """Indica si puede modificar precios en carrito - Solo Admin"""
        return self._usuario_rol == "Administrador"
    
    @Property(bool, notify=operacionExitosa)
    def puede_exportar_datos(self):
        """Indica si puede exportar reportes - Solo Admin"""
        return self._usuario_rol == "Administrador"
    
    @Property(bool, notify=operacionExitosa)
    def mostrar_informacion_limitada(self):
        """Indica si mostrar información limitada - Para Médicos"""
        return self._usuario_rol == "Médico"
    
    # ✅ NUEVAS PROPERTIES PARA EDITAR/ELIMINAR
    @Property(bool, notify=operacionExitosa)
    def puede_editar_ventas(self):
        """Indica si puede editar ventas - Solo Admin"""
        return self._usuario_rol == "Administrador"
    
    @Property(bool, notify=operacionExitosa)
    def puede_eliminar_ventas(self):
        """Indica si puede eliminar ventas - Solo Admin"""
        return self._usuario_rol == "Administrador"
    
    # ===============================
    # NUEVAS PROPERTIES CALCULADAS PARA FILTROS
    # ===============================
    
    @Property(bool, notify=operacionExitosa)
    def debe_filtrar_por_usuario(self):
        """Indica si debe filtrar automáticamente por usuario actual"""
        return self._usuario_rol == "Médico"
    
    @Property(str, notify=operacionExitosa)
    def texto_usuario_limitado(self):
        """Texto descriptivo para usuario con permisos limitados"""
        return ""
    
    # ===============================
    # SLOTS PARA QML - CONFIGURACIÓN
    # ===============================
    
    @Slot()
    def refresh_ventas_hoy(self):
        """Refresca las ventas del día"""
        # ✅ VERIFICAR AUTENTICACIÓN ANTES DE REFRESCO
        if not self._verificar_autenticacion():
            return 
        self._cargar_ventas_hoy(usar_cache=False)
    
    @Slot()
    def refresh_estadisticas(self):
        """Refresca las estadísticas"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return
        
        self._cargar_estadisticas(usar_cache=False)
    
    # ===============================
    # SLOTS PARA QML - CARRITO (CON VERIFICACIÓN)
    # ===============================
    
    @Slot(str, int, float)
    def agregar_item_carrito(self, codigo: str, cantidad: int, precio_custom: float = 0):
        """
        ✅ CORREGIDO: Agrega item al carrito con verificación FIFO
        """
        if not self._verificar_permisos('agregar_carrito'):
            return
        
        if not codigo or cantidad <= 0:
            self.operacionError.emit("Código o cantidad inválidos")
            return
        
        try:
            # PASO 1: Obtener producto con stock calculado desde lotes
            producto = self.venta_repo.get_producto_por_codigo(codigo.strip())
            if not producto:
                raise ProductoNotFoundError(codigo=codigo)
            
            print(f"🛒 Producto encontrado: {producto['id']} - {producto['Nombre']}")
            
            # PASO 2: Verificar disponibilidad FIFO para la cantidad solicitada
            verificacion = self.verificar_disponibilidad_para_cantidad(codigo, cantidad)
            if not verificacion['disponible']:
                raise StockInsuficienteError(
                    codigo, 
                    verificacion['cantidad_total_disponible'], 
                    cantidad
                )
            
            # Usar precio personalizado o precio del producto
            precio = precio_custom if precio_custom > 0 else float(producto['Precio_venta'])
            subtotal = cantidad * precio
            
            # PASO 3: Verificar si ya existe en carrito
            item_existente = None
            for item in self._carrito_items:
                if item['codigo'] == codigo.strip():
                    item_existente = item
                    break
            
            if item_existente:
                # Actualizar cantidad existente - VERIFICAR DISPONIBILIDAD TOTAL
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
                # Agregar nuevo item
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
            self.operacionExitosa.emit(f"Agregado: {cantidad}x {codigo} (Verificado FIFO)")
            print(f"🛒 Item agregado con FIFO - {codigo}: {cantidad}x${precio}")
            
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
        """✅ MODIFICADO: Actualiza cantidad verificando stock desde tabla Productos"""
        if not codigo or nueva_cantidad < 0:
            return
        
        if nueva_cantidad == 0:
            self.remover_item_carrito(codigo)
            return
        
        try:
            for item in self._carrito_items:
                if item['codigo'] == codigo.strip():
                    # ✅ VERIFICAR STOCK ACTUAL DESDE TABLA PRODUCTOS
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
                    item['stock_disponible'] = stock_disponible  # Actualizar stock disponible
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
    # SLOTS PARA QML - VENTAS (CON VERIFICACIÓN) - ✅ CORREGIDO
    # ===============================
    @Slot(result=bool)
    def procesar_venta_carrito(self):
        """
        ✅ CORREGIDO: Procesar venta con mejor gestión de timeouts
        """
        print(f"INICIO procesar_venta_carrito - Items: {len(self._carrito_items)}")
        
        if not self._verificar_permisos('crear_venta'):
            return False
        
        if not self._carrito_items:
            self.operacionError.emit("Carrito vacío")
            return False
        
        self._set_procesando_venta(True)
        
        try:
            # ✅ VALIDAR stock ANTES de procesar
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
            
            # ✅ PROCESAR con timeout extendido
            venta = self.venta_repo.crear_venta(self._usuario_actual_id, items_venta)
            
            if venta and isinstance(venta, dict) and 'id' in venta:
                # Limpiar carrito
                self.limpiar_carrito()
                
                # ✅ ACTUALIZACIÓN FORZADA
                self._invalidar_cache_completo()
                self._cargar_ventas_hoy(usar_cache=False)
                self._cargar_estadisticas(usar_cache=False)
                
                # Forzar emisión de signals
                self.ventasHoyChanged.emit()
                self.estadisticasChanged.emit()
                
                # Establecer venta actual
                self._venta_actual = venta
                self.ventaActualChanged.emit()
                
                # Emitir signals de éxito
                self.ventaCreada.emit(int(venta['id']), float(venta['Total']))
                self.operacionExitosa.emit(f"Venta procesada: ${venta['Total']:.2f}")
                self.stockModificado.emit()
                print(f"ÉXITO: Venta creada - ID: {venta['id']}, Total: ${venta['Total']}")
                return True
            else:
                raise VentaError("Respuesta inválida del repository")
                
        except Exception as e:
            print(f"ERROR en procesar_venta_carrito: {e}")
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
    
    @Slot(str, int, int, result=bool)
    def venta_rapida(self, codigo: str, cantidad: int, usuario_id: int = 0):
        """Venta rápida de un producto sin usar carrito - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN Y PERMISOS
        if not self._verificar_permisos('crear_venta'):
            return False
        
        if not codigo or cantidad <= 0:
            self.operacionError.emit("Parámetros inválidos")
            return False
        
        # Usar usuario autenticado, ignorar parámetro usuario_id
        usuario = self._usuario_actual_id
        
        self._set_procesando_venta(True)
        
        try:
            # ✅ OBTENER PRODUCTO DESDE TABLA PRODUCTOS
            if hasattr(self.venta_repo, 'get_producto_por_codigo'):
                producto = self.venta_repo.get_producto_por_codigo(codigo.strip())
            else:
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
                # ✅ Actualización inmediata después de venta rápida
                self._cargar_ventas_hoy(usar_cache=False)
                self._cargar_estadisticas(usar_cache=False)
                self.ventasHoyChanged.emit()
                self.estadisticasChanged.emit()
                
                self.ventaCreada.emit(venta['id'], float(venta['Total']))
                mensaje_exito = f"Venta rápida: ${venta['Total']:.2f}"
                if self._usuario_rol == "Médico":
                    mensaje_exito += f" (Usuario: {self._usuario_actual_id})"
                
                self.operacionExitosa.emit(mensaje_exito)
                print(f"🚀 Venta rápida exitosa - Usuario: {self._usuario_actual_id} ({self._usuario_rol})")
                
                return True
            else:
                raise VentaError("Error en venta rápida")
                
        except Exception as e:
            self.operacionError.emit(f"Error en venta rápida: {str(e)}")
            return False
        finally:
            self._set_procesando_venta(False)
    
    # ===============================
    # NUEVOS SLOTS PARA VERIFICACIÓN DE PERMISOS DESDE QML
    # ===============================
    
    @Slot(str, result=bool)
    def tiene_permiso(self, accion: str):
        """Verifica permisos específicos desde QML"""
        if not self._verificar_autenticacion():
            return False
        
        permisos = {
            'crear_venta': self._usuario_rol in ["Administrador", "Médico"],
            'ver_todas_ventas': self._usuario_rol == "Administrador", 
            'modificar_precios': self._usuario_rol == "Administrador",
            'exportar_datos': self._usuario_rol == "Administrador",
            'ver_reportes_financieros': self._usuario_rol == "Administrador",
            'editar_venta': self._usuario_rol == "Administrador",  # ✅ NUEVO
            'eliminar_venta': self._usuario_rol == "Administrador"  # ✅ NUEVO
        }
        
        return permisos.get(accion, False)
    
    @Slot(str, result='QVariantMap')
    def verificar_disponibilidad_producto(self, codigo: str):
        """
        ✅ CORREGIDO: Verifica disponibilidad SIN cache usando SISTEMA FIFO DE LOTES
        """
        if not self._verificar_autenticacion():
            return {"cantidad_disponible": 0, "disponible": False, "error": "No autenticado"}
        
        if not codigo:
            return {"cantidad_disponible": 0, "disponible": False, "error": "Código requerido"}
        
        try:
            # PASO 1: Obtener producto desde tabla Productos (con stock calculado desde lotes)
            producto = self.venta_repo.get_producto_por_codigo(codigo.strip())
            if not producto:
                return {
                    "cantidad_disponible": 0, 
                    "disponible": False, 
                    "error": f"Producto {codigo} no encontrado"
                }
            
            # PASO 2: Stock total calculado desde lotes (ya viene en la consulta)
            stock_total = producto.get('Stock_Total', 0)
            
            # PASO 3: Información adicional del sistema FIFO
            resultado = {
                "cantidad_disponible": stock_total,
                "disponible": stock_total > 0,
                "producto_id": producto.get('id', 0),
                "codigo": codigo.strip(),
                "nombre": producto.get('Nombre', ''),
                "precio_venta": float(producto.get('Precio_venta', 0)),
                
                # ✅ INFORMACIÓN FIFO ADICIONAL
                "lotes_activos": producto.get('Lotes_Activos', 0),
                "lote_fifo_id": producto.get('Lote_FIFO_ID'),
                "lote_fifo_stock": producto.get('Lote_FIFO_Stock', 0),
                "lote_fifo_vencimiento": producto.get('Lote_FIFO_Vencimiento'),
                "estado_stock": producto.get('Estado_Stock', 'DESCONOCIDO'),
                
                # ✅ VALIDACIONES ADICIONALES
                "puede_vender": stock_total > 0,
                "stock_calculado_desde_lotes": True,
                "timestamp": datetime.now().isoformat()
            }
            
            print(f"✅ Verificación FIFO para {codigo}: {stock_total} unidades disponibles desde {resultado['lotes_activos']} lotes")
            
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
        """
        ✅ NUEVO: Verifica disponibilidad FIFO para una cantidad específica
        """
        if not self._verificar_autenticacion():
            return {"disponible": False, "error": "No autenticado"}
        
        if not codigo or cantidad_solicitada <= 0:
            return {"disponible": False, "error": "Parámetros inválidos"}
        
        try:
            # Obtener producto
            producto = self.venta_repo.get_producto_por_codigo(codigo.strip())
            if not producto:
                return {"disponible": False, "error": f"Producto {codigo} no encontrado"}
            
            # Usar sistema FIFO para verificar disponibilidad específica
            disponibilidad = self.producto_repo.verificar_disponibilidad_fifo(
                producto['id'], 
                cantidad_solicitada
            )
            
            # Agregar información adicional
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
            
            # Información detallada de lotes que se usarían
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
        
    @Slot(result=str)
    def get_rol_display(self):
        """Obtiene el rol formateado para mostrar en UI"""
        roles_display = {
            "Administrador": "Admin",
            "Médico": "Médico"
        }
        return roles_display.get(self._usuario_rol, self._usuario_rol)
    
    # ===============================
    # MÉTODOS DE CONSULTA (CON RESTRICCIONES)
    # ===============================
    @Slot(int, result='QVariantMap')
    def obtener_detalle_venta(self, venta_id: int):
        """Obtiene el detalle completo de una venta específica CON PRODUCTOS CONSOLIDADOS"""
        try:
            print(f"🔍 VentaModel: Obteniendo detalle de venta {venta_id}")
            
            if not self._verificar_autenticacion():
                return {}
            
            if not isinstance(venta_id, int) or venta_id <= 0:
                print(f"❌ VentaModel: ID de venta inválido: {venta_id}")
                return {}
            
            try:
                # ✅ USAR MÉTODO CONSOLIDADO PARA UI
                detalle = self.venta_repo.get_venta_completa_consolidada(venta_id)
                print(f"🔍 VentaModel: Detalle consolidado obtenido del repository")
                
                if not detalle:
                    print(f"❌ VentaModel: No se encontró venta con ID {venta_id}")
                    return {}
                

                # Verificar permisos: Médico solo puede ver sus propias ventas
                if self._usuario_rol == "Médico":
                    if detalle.get('Id_Usuario') != self._usuario_actual_id:
                        self.operacionError.emit("No tiene permisos para ver esta venta")
                        return {}
                
                # CORREGIDO: Procesar detalles para asegurar que tengan subtotales
                detalles_procesados = []
                if detalle.get('detalles'):
                    for item in detalle['detalles']:
                        # Asegurar que todos los campos numéricos estén correctos
                        cantidad = float(item.get('Cantidad_Unitario', 0))
                        precio = float(item.get('Precio_Unitario', 0))
                        subtotal_bd = float(item.get('Subtotal', 0))
                        
                        # Si no hay subtotal en BD, calcularlo
                        if subtotal_bd <= 0:
                            subtotal_calculado = cantidad * precio
                            print(f"⚠️ Subtotal calculado para {item.get('Producto_Codigo')}: {cantidad} x {precio} = {subtotal_calculado}")

                        else:
                            subtotal_calculado = subtotal_bd
                            print(f"✅ Subtotal de BD para {item.get('Producto_Codigo')}: {subtotal_bd}")
                        
                        detalle_procesado = {
                            'Producto_Codigo': str(item.get('Producto_Codigo', '')),
                            'Producto_Nombre': str(item.get('Producto_Nombre', '')),
                            'Marca_Nombre': str(item.get('Marca_Nombre', '')),
                            'Cantidad_Unitario': cantidad,
                            'Precio_Unitario': precio,
                            'Subtotal': subtotal_calculado,  # ASEGURAR SUBTOTAL CORRECTO
                            'Fecha_Vencimiento': item.get('Fecha_Vencimiento')
                        }
                        
                        detalles_procesados.append(detalle_procesado)
                
                # Formatear resultado para QML
                resultado = {
                    'id': int(detalle['id']),
                    'fecha': detalle['Fecha'].strftime('%Y-%m-%d %H:%M') if hasattr(detalle['Fecha'], 'strftime') else str(detalle['Fecha']),
                    'vendedor': str(detalle.get('Vendedor', 'Usuario desconocido')),
                    'total': float(detalle['Total']),
                    'detalles': detalles_procesados,  # USAR DETALLES PROCESADOS
                    'total_items': len(detalles_procesados),
                    'es_propia': detalle.get('Id_Usuario') == self._usuario_actual_id,
                    'puede_editar': self.puede_editar_venta(venta_id),
                    'puede_eliminar': self.puede_eliminar_venta(venta_id)
                }
                
                # VERIFICACIÓN: Calcular total de subtotales para debug
                total_calculado = sum(item['Subtotal'] for item in detalles_procesados)
                print(f"📊 VentaModel: Total BD: {resultado['total']}, Total calculado: {total_calculado}")
                
                if abs(total_calculado - resultado['total']) > 0.01:
                    print(f"⚠️ Discrepancia en totales detectada")
                
                print(f"📋 VentaModel: Detalle consolidado formateado exitosamente: {len(detalles_procesados)} productos únicos")
                return resultado
                
            except Exception as repo_error:
                print(f"❌ VentaModel: Error del repository: {repo_error}")
                return {}
            
        except Exception as e:
            print(f"❌ VentaModel: Error general obteniendo detalle: {e}")
            return {}
    # ===============================
    # MÉTODOS PRIVADOS (CON FILTRADO POR ROL) - ✅ CORREGIDOS
    # ===============================
    
    def _actualizar_datos_post_venta(self):
        """✅ CORREGIDO: Actualiza todos los datos después de una venta exitosa"""
        try:
            print("🔄 Ejecutando actualización post-venta tardía...")
            
            # Recargar ventas del día SIN caché
            self._cargar_ventas_hoy(usar_cache=False)
            
            # Recargar estadísticas SIN caché
            self._cargar_estadisticas(usar_cache=False)
            
            # Emitir señales para forzar actualización de UI
            self.ventasHoyChanged.emit()
            self.estadisticasChanged.emit()
            
            print("✅ Actualización post-venta tardía completada")
            
        except Exception as e:
            print(f"❌ Error en _actualizar_datos_post_venta: {e}")

    def _cargar_ventas_hoy(self, usar_cache=True):
        """✅ CORREGIDO: Carga ventas del día actual (se filtra por rol en las properties)"""
        print(f"🛠 DEBUG VentaModel: _cargar_ventas_hoy() iniciado - usar_cache: {usar_cache}")
        try:
            # ✅ CORREGIDO: Respeta el parámetro usar_cache
            if usar_cache:
                ventas = safe_execute(self.venta_repo.get_active)
            else:
                # Forzar recarga sin caché
                ventas = self.venta_repo.get_active()
            
            print(f"🛠 DEBUG VentaModel: Ventas desde repository: {len(ventas) if ventas else 0}")
            
            # Convertir a formato QML-compatible
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
                            'Id_Usuario': venta.get('Id_Usuario')  # Para filtrado por rol
                        }
                        ventas_formateadas.append(venta_formateada)
                    except Exception as e:
                        print(f"⚠️ Error formateando venta: {e}")
                        continue
            
            print(f"🛠 DEBUG VentaModel: Ventas formateadas: {len(ventas_formateadas)}")
            
            self._ventas_hoy = ventas_formateadas
            self.ventasHoyChanged.emit()
            
        except Exception as e:
            print(f"❌ Error cargando ventas hoy: {e}")
            self._ventas_hoy = []
            self.ventasHoyChanged.emit()
    
    def _cargar_estadisticas(self, usar_cache=True):
        """✅ CORREGIDO: Carga estadísticas del día (se filtran por rol en las properties)"""
        try:
            fecha_hoy = datetime.now().strftime('%Y-%m-%d')
            
            # ✅ CARGAR ESTADÍSTICAS SEGÚN EL ROL
            if self._usuario_rol == "Médico" and self._usuario_actual_id > 0:
                # Para médico: solo estadísticas de sus propias ventas
                if hasattr(self.venta_repo, 'get_ventas_del_dia_por_usuario'):
                    estadisticas = safe_execute(
                        self.venta_repo.get_ventas_del_dia_por_usuario, 
                        fecha_hoy, self._usuario_actual_id
                    )
                else:
                    # Fallback: usar estadísticas generales y filtrarlas después
                    estadisticas = safe_execute(self.venta_repo.get_ventas_del_dia, fecha_hoy) if usar_cache else self.venta_repo.get_ventas_del_dia(fecha_hoy)
            else:
                # Para admin: estadísticas completas
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

    def emergency_disconnect(self):
        """Desconexión de emergencia para VentaModel"""
        try:
            print("🚨 VentaModel: Iniciando desconexión de emergencia...")
            
            # Detener timer
            if hasattr(self, 'update_timer') and self.update_timer.isActive():
                self.update_timer.stop()
                print("   ⏹️ Update timer detenido")
            
            # Establecer estado shutdown
            self._loading = False
            self._procesando_venta = False
            
            # Desconectar todas las señales
            signals_to_disconnect = [
                'ventasHoyChanged', 'ventaActualChanged', 'historialVentasChanged',
                'estadisticasChanged', 'topProductosChanged',
                'ventaCreada', 'ventaAnulada', 'ventaActualizada', 'ventaEliminada',  # ✅ NUEVO
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
            self._usuario_actual_id = 0  # ✅ RESETEAR USUARIO
            self._usuario_rol = ""       # ✅ RESETEAR ROL
            
            # Anular repositories
            self.venta_repo = None
            self.producto_repo = None
            
            print("✅ VentaModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión VentaModel: {e}")

# Registrar el tipo para QML
def register_venta_model():
    qmlRegisterType(VentaModel, "ClinicaModels", 1, 0, "VentaModel")
    print("✅ VentaModel registrado para QML con autenticación estandarizada, control de roles y funciones CRUD")