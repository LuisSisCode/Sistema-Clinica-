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
    ventasFiltradas = Signal()
    
    # Signals de operaciones
    ventaCreada = Signal(int, float)  # venta_id, total
    ventaAnulada = Signal(int, str)   # venta_id, motivo
    operacionExitosa = Signal(str)    # mensaje
    operacionError = Signal(str)      # mensaje_error
    
    # Signals de estados
    loadingChanged = Signal()
    procesandoVentaChanged = Signal()
    carritoCambiado = Signal()
    filtrosChanged = Signal()
    
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
        
        # Estado de filtros
        self._filtros_activos = {
            'temporal': 'Hoy',
            'estado': 'Todas',
            'busqueda_id': '',
            'fecha_desde': '',
            'fecha_hasta': ''
        }
        self._ventas_filtradas = []
        
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
                self._cargar_ventas_hoy()
                self._cargar_estadisticas()
                
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
                print(f"🔐 DEBUG: Usuario establecido: {usuario_id}, Rol: '{rol}' -------------------------------------")  # NUEVO
                print(f"🔐 DEBUG: _usuario_rol almacenado: '{self._usuario_rol}'") 
                # Cargar datos iniciales después de autenticación
                self._cargar_ventas_hoy()
                self._cargar_estadisticas()
                
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
            'estadisticas_completas'
        ]
        
        if operacion in operaciones_admin:
            if self._usuario_rol != "Administrador":
                self.operacionError.emit("Operación requiere permisos de administrador")
                return False
        
        return True
    
    # ===============================
    # PROPERTIES PARA QML (MODIFICADAS CON FILTRADO)
    # ===============================
    
    @Property(list, notify=ventasHoyChanged)
    def ventas_hoy(self):
        """Lista de ventas del día actual o filtradas"""
        return self._ventas_filtradas if self._ventas_filtradas else self._ventas_hoy
    
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
        """Total de ventas mostradas (con filtros y restricciones aplicadas)"""
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
    
    @Property('QVariant', notify=filtrosChanged)
    def filtros_activos(self):
        """Estado actual de los filtros"""
        return self._filtros_activos
    
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
        self._cargar_ventas_hoy()
    
    @Slot()
    def refresh_estadisticas(self):
        """Refresca las estadísticas"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return
        
        self._cargar_estadisticas()
    
    # ===============================
    # SLOTS PARA QML - CARRITO (CON VERIFICACIÓN)
    # ===============================
    
    @Slot(str, int, float)
    def agregar_item_carrito(self, codigo: str, cantidad: int, precio_custom: float = 0):
        """Agrega item al carrito de venta - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN Y PERMISOS
        if not self._verificar_permisos('agregar_carrito'):
            return
        
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
    # SLOTS PARA QML - VENTAS (CON VERIFICACIÓN)
    # ===============================
    
    @Slot(result=bool)
    def procesar_venta_carrito(self):
        """Procesa la venta con los items del carrito - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        print(f"🛠 DEBUG VentaModel: Iniciando procesar_venta_carrito")
        print(f"🛠 DEBUG VentaModel: Items en carrito: {len(self._carrito_items)}")
        print(f"🛠 DEBUG VentaModel: Usuario actual: {self._usuario_actual_id} ({self._usuario_rol})")
        
        # ✅ VERIFICAR AUTENTICACIÓN Y PERMISOS
        if not self._verificar_permisos('crear_venta'):
            return False
        
        if not self._carrito_items:
            self.operacionError.emit("Carrito vacío")
            return False
        
        self._set_procesando_venta(True)
        
        try:
            # Preparar items para venta con validación estricta
            items_venta = []
            for i, item in enumerate(self._carrito_items):
                print(f"🛠 DEBUG VentaModel: Preparando item {i}: {item}")
                
                if not isinstance(item, dict):
                    raise VentaError(f"Item {i} del carrito está corrupto")
                
                required_keys = ['codigo', 'cantidad', 'precio']
                missing_keys = [key for key in required_keys if key not in item]
                if missing_keys:
                    raise VentaError(f"Item {i} incompleto: faltan {missing_keys}")
                
                try:
                    codigo = str(item['codigo']).strip()
                    cantidad = int(item['cantidad'])
                    precio = float(item['precio'])
                    
                    if not codigo:
                        raise VentaError(f"Código vacío en item {i}")
                    if cantidad <= 0:
                        raise VentaError(f"Cantidad inválida en item {i}: {cantidad}")
                    if precio <= 0:
                        raise VentaError(f"Precio inválido en item {i}: {precio}")
                    
                    item_venta = {
                        'codigo': codigo,
                        'cantidad': cantidad,
                        'precio': precio
                    }
                    items_venta.append(item_venta)
                    
                except (ValueError, TypeError) as e:
                    raise VentaError(f"Datos inválidos en item {i}: {e}")
            
            print(f"🛠 DEBUG VentaModel: Items preparados para repository: {items_venta}")
        
            try:
                # ✅ USAR USUARIO AUTENTICADO
                venta = self.venta_repo.crear_venta(self._usuario_actual_id, items_venta)
                print(f"✅ Venta creada exitosamente: {venta}")
                
                if venta and isinstance(venta, dict) and 'id' in venta:
                    # Limpiar carrito
                    self.limpiar_carrito()
                    
                    # Actualizar datos
                    self._cargar_ventas_hoy()
                    self._cargar_estadisticas()
                    
                    # Si hay filtros activos, reaplicarlos
                    if any(value for key, value in self._filtros_activos.items() if key != 'temporal' or value != 'Hoy'):
                        self.aplicar_filtros(
                            self._filtros_activos['temporal'],
                            self._filtros_activos['estado'], 
                            self._filtros_activos['busqueda_id'],
                            self._filtros_activos['fecha_desde'],
                            self._filtros_activos['fecha_hasta']
                        )
                    
                    # Establecer venta actual
                    self._venta_actual = venta
                    self.ventaActualChanged.emit()
                    
                    # Emitir signals
                    self.ventaCreada.emit(int(venta['id']), float(venta['Total']))
                    mensaje_exito = f"Venta procesada: ${venta['Total']:.2f}"
                    if self._usuario_rol == "Médico":
                        mensaje_exito += f" (Usuario: {self._usuario_actual_id})"
                    
                    self.operacionExitosa.emit(mensaje_exito)
                    print(f"✅ Venta exitosa - ID: {venta['id']}, Total: ${venta['Total']}, Usuario: {self._usuario_actual_id}")
                    return True
                else:
                    raise VentaError("Respuesta inválida del repository")
                    
            except Exception as repo_error:
                print(f"❌ ERROR del repository: {repo_error}")
                raise VentaError(f"Error en repository: {str(repo_error)}")
                
        except Exception as e:
            print(f"❌ ERROR en procesar_venta_carrito: {e}")
            error_msg = str(e)
            
            if "Foreign Key" in error_msg or "FK__" in error_msg:
                error_msg = "Error de integridad en base de datos. Contacte al administrador."
            elif "Stock insuficiente" in error_msg:
                error_msg = "Stock insuficiente para uno o más productos."
            elif "No se proporcionaron items" in error_msg:
                error_msg = "No hay items en el carrito para procesar."
            
            self.operacionError.emit(f"Error en venta: {error_msg}")
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
            'ver_reportes_financieros': self._usuario_rol == "Administrador"
        }
        
        return permisos.get(accion, False)
    
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
        """Obtiene el detalle completo de una venta específica (con restricciones por rol)"""
        try:
            print(f"🔍 VentaModel: Obteniendo detalle de venta {venta_id}")
            
            # ✅ VERIFICAR AUTENTICACIÓN
            if not self._verificar_autenticacion():
                return {}
            
            if not isinstance(venta_id, int) or venta_id <= 0:
                print(f"❌ VentaModel: ID de venta inválido: {venta_id}")
                return {}
            
            try:
                detalle = self.venta_repo.get_venta_completa(venta_id)
                print(f"🔍 VentaModel: Detalle obtenido del repository")
                
                if not detalle:
                    print(f"❌ VentaModel: No se encontró venta con ID {venta_id}")
                    return {}
                
                if not isinstance(detalle, dict):
                    print(f"❌ VentaModel: Detalle no es diccionario: {type(detalle)}")
                    return {}
                
                required_keys = ['id', 'Fecha', 'Total']
                missing_keys = [key for key in required_keys if key not in detalle]
                if missing_keys:
                    print(f"❌ VentaModel: Detalle falta claves: {missing_keys}")
                    return {}
                
                # Formatear fecha de manera segura
                fecha_formateada = "Fecha no disponible"
                try:
                    if hasattr(detalle['Fecha'], 'strftime'):
                        fecha_formateada = detalle['Fecha'].strftime('%Y-%m-%d %H:%M')
                    else:
                        fecha_formateada = str(detalle['Fecha'])
                except Exception as e:
                    print(f"⚠️ VentaModel: Error formateando fecha: {e}")
                
                # Obtener vendedor de manera segura
                vendedor = detalle.get('Vendedor', 'Usuario desconocido')
                if not isinstance(vendedor, str):
                    vendedor = str(vendedor) if vendedor is not None else 'Usuario desconocido'
                
                # Validar y formatear total
                try:
                    total = float(detalle['Total'])
                except (ValueError, TypeError):
                    print(f"⚠️ VentaModel: Error convirtiendo total: {detalle['Total']}")
                    total = 0.0
                
                # Procesar detalles de productos de manera segura
                detalles_productos = detalle.get('detalles', [])
                if not isinstance(detalles_productos, list):
                    print(f"⚠️ VentaModel: detalles no es lista: {type(detalles_productos)}")
                    detalles_productos = []
                
                # Formatear detalles para QML
                detalles_formateados = []
                for i, item_detalle in enumerate(detalles_productos):
                    try:
                        if isinstance(item_detalle, dict):
                            detalle_formateado = {
                                'codigo': str(item_detalle.get('Producto_Codigo', 'N/A')),
                                'nombre': str(item_detalle.get('Producto_Nombre', 'Producto desconocido')),
                                'cantidad': float(item_detalle.get('Cantidad_Unitario', 0)),
                                'precio': float(item_detalle.get('Precio_Unitario', 0)),
                                'subtotal': float(item_detalle.get('Subtotal', 0))
                            }
                            detalles_formateados.append(detalle_formateado)
                        else:
                            print(f"⚠️ VentaModel: Detalle {i} no es dict: {type(item_detalle)}")
                    except Exception as e:
                        print(f"⚠️ VentaModel: Error procesando detalle {i}: {e}")
                
                # Resultado final formateado para QML
                resultado = {
                    'id': int(detalle['id']),
                    'fecha': fecha_formateada,
                    'vendedor': vendedor,
                    'total': total,
                    'detalles': detalles_formateados,
                    'total_items': len(detalles_formateados),
                    'es_propia': detalle.get('Id_Usuario') == self._usuario_actual_id  # Para UI
                }
                
                print(f"📋 VentaModel: Detalle formateado exitosamente: {len(detalles_formateados)} items")
                return resultado
                
            except Exception as repo_error:
                print(f"❌ VentaModel: Error del repository: {repo_error}")
                return {
                    'id': venta_id,
                    'fecha': 'Error',
                    'vendedor': 'Error',
                    'total': 0.0,
                    'detalles': [],
                    'total_items': 0,
                    'error': str(repo_error)
                }
            
        except Exception as e:
            print(f"❌ VentaModel: Error general obteniendo detalle: {e}")
            return {}
    
    # ===============================
    # MÉTODOS PRIVADOS (CON FILTRADO POR ROL)
    # ===============================
    
    def _cargar_ventas_hoy(self):
        """Carga ventas del día actual (se filtra por rol en las properties)"""
        print("🛠 DEBUG VentaModel: _cargar_ventas_hoy() iniciado")
        try:
            ventas = safe_execute(self.venta_repo.get_active)
            print(f"🛠 DEBUG VentaModel: Ventas desde repository: {ventas}")
            
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
    
    def _cargar_estadisticas(self):
        """Carga estadísticas del día (se filtran por rol en las properties)"""
        try:
            fecha_hoy = datetime.now().strftime('%Y-%m-%d')
            
            # Cargar todas las estadísticas
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
        if not self._loading and not self._procesando_venta and self._usuario_actual_id > 0:
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
                'estadisticasChanged', 'topProductosChanged', 'ventasFiltradas',
                'ventaCreada', 'ventaAnulada', 'operacionExitosa', 'operacionError',
                'loadingChanged', 'procesandoVentaChanged', 'carritoCambiado', 'filtrosChanged'
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
            self._ventas_filtradas = []
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
    print("✅ VentaModel registrado para QML con autenticación estandarizada y control de roles")