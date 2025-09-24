"""
CompraModel - ACTUALIZADO con autenticación estandarizada
Migrado del patrón sin autenticación al patrón de ConsultaModel
"""

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer, Qt
from PySide6.QtQml import qmlRegisterType
from typing import List, Dict, Any, Optional
import json
from datetime import datetime, timedelta
from decimal import Decimal
from PySide6.QtCore import QTimer 
from ..repositories.compra_repository import CompraRepository
from ..repositories.producto_repository import ProductoRepository
from ..core.excepciones import (
    CompraError, ProductoNotFoundError, ValidationError,
    ExceptionHandler, safe_execute, validate_required
)

class CompraModel(QObject):
    """
    Model QObject para gestión de compras con auto-creación de lotes - ACTUALIZADO con autenticación
    Conecta directamente con QML mediante Signals/Slots/Properties
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
    proveedorCreado = Signal(int, str)  # proveedor_id, nombre
    operacionExitosa = Signal(str)     # mensaje
    operacionError = Signal(str)       # mensaje_error
    
    # Signals de estados
    loadingChanged = Signal()
    procesandoCompraChanged = Signal()
    itemsCompraCambiado = Signal()
    # Signal para notificar cambios en proveedores
    proveedorCompraCompletada = Signal(int, float)  # proveedor_id, monto_compra
    proveedorDatosActualizados = Signal()  # Para forzar refresh en ProveedorModel
    # Signal para los filtros
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
        
        # ✅ AUTENTICACIÓN ESTANDARIZADA - COMO CONSULTAMODEL
        self._usuario_actual_id = 0  # Cambio de hardcoded a dinámico
        print("📦 CompraModel inicializado - Esperando autenticación")
        
        # Configuración
        self._proveedor_seleccionado = 0
        
        # Timer para actualización automática
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._auto_update_compras)
        self.update_timer.start(120000)  # 2 minutos
        
        # Cargar datos iniciales
        self._cargar_compras_recientes()
        
        print(f"🔍 DEBUG: Compras cargadas en __init__: {len(self._compras_recientes)}")
        self._cargar_proveedores()
        self._cargar_estadisticas()
        print("📦 CompraModel inicializado con autenticación estandarizada")
    
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
                print(f"👤 Usuario autenticado establecido en CompraModel: {usuario_id}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de compras")
            else:
                print(f"⚠️ ID de usuario inválido en CompraModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en CompraModel: {e}")
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
        total = len(self._compras_recientes)
        print(f"🔍 DEBUG Property: total_compras_mes = {total}")
        return total
    
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
    
    # ===============================
    # SLOTS PARA QML - CONFIGURACIÓN (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(int)
    def set_proveedor_seleccionado(self, proveedor_id: int):
        """Establece el proveedor para la compra actual - SIN VERIFICACIÓN (solo lectura)"""
        if proveedor_id > 0:
            self._proveedor_seleccionado = proveedor_id
            print(f"🏢 Proveedor seleccionado: {proveedor_id}")
    
    @Slot()
    def refresh_compras(self):
        """Refresca las compras recientes - SIN VERIFICACIÓN (solo lectura)"""
        self._cargar_compras_recientes()
    
    @Slot()
    def refresh_estadisticas(self):
        """Refresca las estadísticas - SIN VERIFICACIÓN (solo lectura)"""
        self._cargar_estadisticas()
    
    # ===============================
    # SLOTS PARA QML - GESTIÓN PROVEEDORES - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(str, str, result=int)
    def crear_proveedor(self, nombre: str, direccion: str):
        """Crea un nuevo proveedor - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN PRIMERO
        if not self._verificar_autenticacion():
            return 0
        
        if not nombre or not nombre.strip():
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
                
                self.proveedorCreado.emit(proveedor_id, nombre.strip())
                self.operacionExitosa.emit(f"Proveedor creado: {nombre}")
                
                print(f"🏢 Proveedor creado - ID: {proveedor_id}, Nombre: {nombre}, Usuario: {self._usuario_actual_id}")
                return proveedor_id
            else:
                raise CompraError("Error creando proveedor")
                
        except Exception as e:
            self.operacionError.emit(f"Error creando proveedor: {str(e)}")
            return 0
    
    # ===============================
    # SLOTS PARA CONSULTAS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(str, result=list)
    def buscar_proveedores(self, termino: str):
        """Busca proveedores por nombre o dirección - SIN VERIFICACIÓN (solo lectura)"""
        if not termino or len(termino.strip()) < 2:
            return []
        
        try:
            resultados = safe_execute(
                self.compra_repo.buscar_proveedores, 
                termino.strip()
            )
            return resultados if resultados else []
        except Exception as e:
            self.operacionError.emit(f"Error buscando proveedores: {str(e)}")
            return []
    
    @Slot(int, result='QVariant')
    def get_proveedor_detalle(self, proveedor_id: int):
        """Obtiene detalles de un proveedor - SIN VERIFICACIÓN (solo lectura)"""
        if proveedor_id <= 0:
            return {}
        
        try:
            # Buscar en la lista de proveedores cargados
            for proveedor in self._proveedores:
                if proveedor.get('id') == proveedor_id:
                    return proveedor
            return {}
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo proveedor: {str(e)}")
            return {}
    
    # ===============================
    # SLOTS PARA QML - ITEMS DE COMPRA (SIN VERIFICACIÓN - PREPARACIÓN)
    # ===============================
    def _validar_fecha_formato(self, fecha_str: str) -> bool:
        """Valida formato YYYY-MM-DD"""
        if not fecha_str:
            return True  # Vacío es válido
        
        try:
            datetime.strptime(fecha_str, '%Y-%m-%d')
            return True
        except ValueError:
            return False
        
    @Slot(str, int, float, str)
    def agregar_item_compra(self, codigo: str, cantidad_unitario: int, 
                        precio_unitario: float, fecha_vencimiento: str):
        """
        Agrega item a la compra actual - SIMPLIFICADO SOLO UNIDADES
        """
        if not codigo or cantidad_unitario <= 0:
            self.operacionError.emit("Código y cantidad válida requeridos")
            return

        if precio_unitario <= 0:
            self.operacionError.emit("Precio unitario debe ser mayor a 0")
            return

        # Validar formato de fecha
        fecha_procesada = fecha_vencimiento.strip() if fecha_vencimiento else ""
        if fecha_procesada and not self._validar_fecha_formato(fecha_procesada):
            self.operacionError.emit("Fecha debe ser formato YYYY-MM-DD o vacía")
            return

        try:
            # Verificar que el producto existe
            producto = safe_execute(self.producto_repo.get_by_codigo, codigo.strip())
            if not producto:
                raise ProductoNotFoundError(codigo=codigo)

            # Verificar si ya existe en items de compra
            item_existente = None
            for item in self._items_compra:
                if item['codigo'] == codigo.strip():
                    item_existente = item
                    break

            mensaje = ""  # ✅ Inicializar la variable aquí
            
            if item_existente:
                # Actualizar item existente - SIMPLIFICADO
                item_existente['cantidad_unitario'] += cantidad_unitario
                item_existente['cantidad_total'] = item_existente['cantidad_unitario']
                item_existente['subtotal'] = item_existente['cantidad_total'] * precio_unitario
                item_existente['fecha_vencimiento'] = fecha_vencimiento
                
                mensaje = f"Actualizado: {cantidad_unitario} unidades más agregadas a {codigo}"
            else:
                nuevo_item = {
                    'codigo': codigo.strip(),
                    'producto_id': producto['id'],
                    'nombre': producto['Nombre'],
                    'marca': producto.get('Marca_Nombre', ''),
                    'cantidad_unitario': cantidad_unitario,
                    'cantidad_total': cantidad_unitario,
                    'precio_unitario': precio_unitario,
                    'fecha_vencimiento': fecha_procesada if fecha_procesada else None,
                    'subtotal': cantidad_unitario * precio_unitario
                }
                self._items_compra.append(nuevo_item)
                
                mensaje = f"Agregado: {cantidad_unitario}x {codigo}"  # ✅ Ahora está en el scope correcto

            self.itemsCompraCambiado.emit()
            self.operacionExitosa.emit(mensaje)
            print(f"📦 Item compra agregado/actualizado - {codigo}: {cantidad_unitario} unidades @ ${precio_unitario}")

        except Exception as e:
            self.operacionError.emit(f"Error agregando item: {str(e)}")
    
    @Slot(str)
    def remover_item_compra(self, codigo: str):
        """Remueve item de la compra actual - SIN VERIFICACIÓN (solo preparación)"""
        if not codigo:
            return
        
        self._items_compra = [
            item for item in self._items_compra 
            if item['codigo'] != codigo.strip()
        ]
        self.itemsCompraCambiado.emit()
        self.operacionExitosa.emit(f"Removido: {codigo}")
    
    @Slot(str, int)
    def actualizar_cantidades_item(self, codigo: str, nueva_cantidad_unitario: int):
        if not codigo or nueva_cantidad_unitario < 0:
            return

        if nueva_cantidad_unitario == 0:
            self.remover_item_compra(codigo)
            return

        for item in self._items_compra:
            if item['codigo'] == codigo.strip():
                item['cantidad_unitario'] = nueva_cantidad_unitario
                item['cantidad_total'] = nueva_cantidad_unitario  # Simplificado
                item['subtotal'] = nueva_cantidad_unitario * item['precio_unitario']
                break

        self.itemsCompraCambiado.emit()
        print(f"📦 Cantidades actualizadas - {codigo}: {nueva_cantidad_unitario} unidades")
    
    @Slot(str, float)
    def actualizar_precio_item(self, codigo: str, nuevo_precio: float):
        """Actualiza precio de un item en compra - SIN VERIFICACIÓN (solo preparación)"""
        if not codigo or nuevo_precio <= 0:
            return
        
        for item in self._items_compra:
            if item['codigo'] == codigo.strip():
                item['precio_unitario'] = nuevo_precio
                item['subtotal'] = item['cantidad_total'] * nuevo_precio
                break
        
        self.itemsCompraCambiado.emit()
        print(f"💰 Precio actualizado - {codigo}: ${nuevo_precio}")
    
    @Slot()
    def limpiar_items_compra(self):
        """Limpia todos los items de la compra actual - SIN VERIFICACIÓN (solo preparación)"""
        self._items_compra.clear()
        self.itemsCompraCambiado.emit()
        self.operacionExitosa.emit("Items de compra limpiados")
    
    # ===============================
    # SLOTS PARA QML - PROCESAMIENTO COMPRAS - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(result=bool)
    def procesar_compra_actual(self) -> bool:
        """Procesa la compra con los items actuales - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN PRIMERO
        if not self._verificar_autenticacion():
            return False
        
        if not self._items_compra:
            self.operacionError.emit("No hay items para comprar")
            return False
        
        if self._proveedor_seleccionado <= 0:
            self.operacionError.emit("Proveedor no seleccionado")
            return False
        
        self._set_procesando_compra(True)
        
        try:
            print(f"💳 Procesando compra - Usuario: {self._usuario_actual_id}, Proveedor: {self._proveedor_seleccionado}")
            
            # Preparar items para compra
            items_compra = []
            for item in self._items_compra:
                items_compra.append({
                    'codigo': item['codigo'],
                    'cantidad_unitario': item['cantidad_unitario'],
                    'precio_unitario': item['precio_unitario'],
                    'fecha_vencimiento': item['fecha_vencimiento']
                })
            
            # Procesar compra
            compra = safe_execute(
                self.compra_repo.crear_compra,
                self._proveedor_seleccionado,
                self._usuario_actual_id,  # ✅ USAR USUARIO AUTENTICADO
                items_compra
            )
            if compra:
                # DEBUG: Verificar que se creó la compra y los lotes
                print(f"🔍 DEBUG: Compra creada - ID: {compra.get('id')}")
                print(f"🔍 DEBUG: Items en compra: {len(compra.get('detalles', []))}")
                
            # Verificar cada detalle
            for i, detalle in enumerate(compra.get('detalles', [])):
                print(f"  Detalle {i+1}: Producto {detalle.get('Producto_Codigo')} - Lote: {detalle.get('Id_Lote')} - Cantidad: {detalle.get('Cantidad_Unitario')}")
            if compra:
                monto_compra = float(compra['Total'])
                proveedor_id = self._proveedor_seleccionado
                
                print(f"✅ Compra exitosa - Proveedor: {proveedor_id}, Monto: {monto_compra}, Usuario: {self._usuario_actual_id}")
                
                # Invalidar cache crítico primero
                self._invalidate_all_provider_cache()
                
                # Limpiar items
                self.limpiar_items_compra()
                
                # Actualizar datos locales con delay para BD
                QTimer.singleShot(0, self._update_all_data_after_purchase)
                
                # NUEVO: Notificar a InventarioModel para que actualice productos
                try:
                    if hasattr(self, '_inventario_model_ref') and self._inventario_model_ref:
                        QTimer.singleShot(100, self._inventario_model_ref.refresh_productos)
                        print("📦 InventarioModel será refrescado después de compra")
                except Exception as e:
                    print(f"❌ Error notificando a InventarioModel: {str(e)}")
                # Notificar inmediatamente a proveedor model
                self._notify_proveedor_updated_immediate(proveedor_id, monto_compra)
                
                # Establecer compra actual
                self._compra_actual = compra
                self.compraActualChanged.emit()
                
                # Emitir signals existentes
                self.compraCreada.emit(compra['id'], monto_compra)
                self.operacionExitosa.emit(f"Compra procesada: ${compra['Total']:.2f}")
                
                return True
            else:
                raise CompraError("Error procesando compra")
                
        except Exception as e:
            self.operacionError.emit(f"Error en compra: {str(e)}")
            return False
        finally:
            self._set_procesando_compra(False)
    
    @Slot(int, str, result=bool)
    def compra_rapida_json(self, proveedor_id: int, items_json: str):
        """Procesa compra rápida desde JSON - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN PRIMERO
        if not self._verificar_autenticacion():
            return False
        
        if proveedor_id <= 0 or not items_json:
            self.operacionError.emit("Datos de compra inválidos")
            return False
        
        self._set_procesando_compra(True)
        
        try:
            print(f"🚀 Compra rápida JSON - Usuario: {self._usuario_actual_id}, Proveedor: {proveedor_id}")
            
            # Parsear items JSON
            items = json.loads(items_json)
            if not items:
                raise CompraError("No hay items en JSON")
            
            # Procesar compra
            compra = safe_execute(
                self.compra_repo.crear_compra,
                proveedor_id,
                self._usuario_actual_id,  # ✅ USAR USUARIO AUTENTICADO
                items
            )
            
            if compra:
                self._cargar_compras_recientes()
                self._cargar_estadisticas()
                
                self.compraCreada.emit(compra['id'], float(compra['Total']))
                self.operacionExitosa.emit(f"Compra rápida: ${compra['Total']:.2f}")
                
                return True
            else:
                raise CompraError("Error en compra rápida")
                
        except json.JSONDecodeError:
            self.operacionError.emit("Error: Formato JSON inválido")
        except Exception as e:
            self.operacionError.emit(f"Error en compra rápida: {str(e)}")
        finally:
            self._set_procesando_compra(False)
        
        return False
    
    @Slot(int, result=bool)
    def eliminar_compra(self, compra_id: int) -> bool:
        """Elimina compra completa con reversión de stock - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        if compra_id <= 0:
            self.operacionError.emit("ID de compra inválido")
            return False
        
        self._set_loading(True)
        try:
            print(f"🗑️ Eliminando compra ID: {compra_id} por usuario: {self._usuario_actual_id}")
            
            exito = safe_execute(self.compra_repo.eliminar_compra_completa, compra_id)
            
            if exito:
                # Actualizar datos
                self._cargar_compras_recientes()
                self._cargar_estadisticas()
                
                self.operacionExitosa.emit(f"Compra #{compra_id} eliminada correctamente")
                print(f"🗑️ Compra eliminada - ID: {compra_id}, Usuario: {self._usuario_actual_id}")
                return True
            else:
                raise CompraError("No se pudo eliminar la compra")
                
        except Exception as e:
            self.operacionError.emit(f"Error eliminando compra: {str(e)}")
            return False
        finally:
            self._set_loading(False)
    
    # ===============================
    # SLOTS PARA QML - CONSULTAS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(int, result='QVariant')
    def get_compra_detalle(self, compra_id: int):
        """Obtiene detalle completo de una compra CON INFORMACIÓN DE PRODUCTOS - SIN VERIFICACIÓN (solo lectura)"""
        if compra_id <= 0:
            return {}
        
        try:
            compra = safe_execute(self.compra_repo.get_compra_completa, compra_id)
            if not compra:
                return {}
            
            # Formatear para QML con información de productos
            compra_qml = {
                'id': compra['id'],
                'proveedor': compra.get('Proveedor_Nombre', 'Sin proveedor'),
                'fecha': compra.get('Fecha', ''),
                'total': float(compra.get('Total', 0)),
                'usuario': compra.get('Usuario', 'Sin usuario'),
                'proveedor_id': compra.get('Id_Proveedor', 0),
                'detalles': [],
                'resumen': {
                    'total_productos': compra.get('total_items', 0),
                    'total_unidades': compra.get('total_unidades', 0),
                    'total_compra': float(compra.get('Total', 0))
                }
            }
            
            # Procesar detalles de productos
            if compra.get('detalles'):
                for detalle in compra['detalles']:
                    detalle_qml = {
                        'codigo': detalle.get('Producto_Codigo', ''),
                        'nombre': detalle.get('Producto_Nombre', 'Producto no encontrado'),
                        'marca': detalle.get('Marca_Nombre', 'Sin marca'),
                        'cantidad_unitario': detalle.get('Cantidad_Unitario', 0),
                        'precio_unitario': float(detalle.get('Precio_Unitario', 0)),
                        'costo_total': float(detalle.get('Costo_Total', 0)),
                        'subtotal': float(detalle.get('Subtotal', 0)),
                        'fecha_vencimiento': detalle.get('Fecha_Vencimiento', 'Sin fecha')
                    }
                    compra_qml['detalles'].append(detalle_qml)
            
            return compra_qml
            
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo detalle compra: {str(e)}")
            return {}
    
    @Slot(int)
    def cargar_top_productos_comprados(self, dias: int = 30):
        """Carga top productos más comprados - SIN VERIFICACIÓN (solo lectura)"""
        try:
            productos = safe_execute(
                self.compra_repo.get_productos_mas_comprados,
                dias, 10
            )
            self._top_productos_comprados = productos or []
            self.topProductosCompradosChanged.emit()
            
        except Exception as e:
            self.operacionError.emit(f"Error cargando top productos: {str(e)}")
    
    @Slot(int, result='QVariant')
    def get_compras_por_proveedor(self, proveedor_id: int = 0):
        """Obtiene compras por proveedor - SIN VERIFICACIÓN (solo lectura)"""
        try:
            if proveedor_id > 0:
                compras = safe_execute(
                    self.compra_repo.get_compras_por_proveedor,
                    proveedor_id
                )
            else:
                compras = safe_execute(self.compra_repo.get_compras_por_proveedor)
            
            return compras if compras else []
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo compras por proveedor: {str(e)}")
            return []
        
    @Slot(int, result='QVariant')
    def cargar_compra_para_edicion(self, compra_id: int):
        """Carga una compra existente para edición"""
        if not self._verificar_autenticacion():
            return False
        
        try:
            compra = self.get_compra_detalle(compra_id)
            if compra and compra.get('detalles'):
                # Limpiar items actuales
                self._items_compra.clear()
                
                # Cargar items de la compra
                for detalle in compra['detalles']:
                    self._items_compra.append({
                        'codigo': detalle['codigo'],
                        'cantidad_unitario': detalle['cantidad_unitario'], 
                        'precio_unitario': detalle['precio_unitario'],
                        'fecha_vencimiento': detalle['fecha_vencimiento']
                    })
                
                # Establecer proveedor
                self._proveedor_seleccionado = compra.get('proveedor_id', 0)
                
                self.itemsCompraCambiado.emit()
                return True
        except Exception as e:
            self.operacionError.emit(f"Error cargando compra: {str(e)}")
        return False
    
    @Slot(result='QVariant')
    def get_reporte_gastos(self):
        """Obtiene reporte de gastos en compras - SIN VERIFICACIÓN (solo lectura)"""
        try:
            reporte = safe_execute(self.compra_repo.get_reporte_gastos_compras, 30)
            return reporte if reporte else {}
        except Exception as e:
            self.operacionError.emit(f"Error en reporte gastos: {str(e)}")
            return {}
    
    @Slot(int, result='QVariant') 
    def get_productos_resumen_compra(self, compra_id: int):
        """Obtiene resumen de productos de una compra para mostrar en lista principal - SIN VERIFICACIÓN (solo lectura)"""
        if compra_id <= 0:
            return {}
        
        try:
            # Usar repository para obtener productos de la compra
            productos = safe_execute(self.compra_repo.get_productos_compra_resumen, compra_id)
            
            if not productos:
                return {'productos_texto': 'Sin productos', 'total_productos': 0}
            
            # Crear texto resumen para mostrar en tabla
            if len(productos) <= 2:
                # Mostrar todos si son 2 o menos
                nombres = [p.get('Producto_Nombre', 'Sin nombre') for p in productos]
                productos_texto = ', '.join(nombres)
            else:
                # Mostrar primeros 2 + "... y X más"
                primeros_dos = [p.get('Producto_Nombre', 'Sin nombre') for p in productos[:2]]
                restantes = len(productos) - 2
                productos_texto = f"{', '.join(primeros_dos)}... y {restantes} más"
            
            return {
                'productos_texto': productos_texto,
                'total_productos': len(productos),
                'productos_detalle': productos
            }
            
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo productos compra: {str(e)}")
            return {'productos_texto': 'Error', 'total_productos': 0}
    
    @Slot(result='QVariant')
    def obtener_proveedores_para_filtro(self):
        """Obtiene lista de proveedores para el ComboBox - SIN VERIFICACIÓN (solo lectura)"""
        try:
            proveedores = safe_execute(self.compra_repo.get_proveedores_for_combo)
            
            # Formato para QML ComboBox
            proveedores_qml = [{"text": "Todos los proveedores", "value": "all"}]
            
            for proveedor in proveedores or []:
                proveedores_qml.append({
                    "text": proveedor.get('Nombre', 'Sin nombre'),
                    "value": str(proveedor.get('id', 0))
                })
            
            print(f"📋 Proveedores para filtro: {len(proveedores_qml)} opciones")
            return proveedores_qml
            
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo proveedores: {str(e)}")
            return [{"text": "Todos los proveedores", "value": "all"}]
    
    @Slot(result=list)
    def get_marcas_disponibles(self):
        """Obtiene marcas para el ComboBox - SIN VERIFICACIÓN (solo lectura)"""
        try:
            return safe_execute(self.producto_repo.get_marcas_activas) or []
        except Exception as e:
            return []
    
    # ===============================
    # SLOTS PARA UTILIDADES Y DEBUG (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot()
    def force_refresh_after_purchase(self):
        """Force refresh completo después de una compra - SIN VERIFICACIÓN (solo lectura)"""
        print("🔄 FORCE REFRESH DESPUÉS DE COMPRA...")
        
        try:
            # Invalidar cache completo
            if hasattr(self.compra_repo, '_cache_manager'):
                self.compra_repo._cache_manager.invalidate_pattern('compras*')
                self.compra_repo._cache_manager.invalidate_pattern('proveedores*')
                print("🗑️ Cache completo invalidado")
            
            # Recargar todos los datos
            self._cargar_compras_recientes()
            self._cargar_proveedores()
            self._cargar_estadisticas()
            
            # Notificar cambios generales
            self.proveedorDatosActualizados.emit()
            
            print("✅ Force refresh después de compra completado")
            
        except Exception as e:
            print(f"❌ Error en force refresh: {str(e)}")
    
    @Slot()
    def force_refresh_compras(self):
        """Fuerza refresh de compras desde QML - SIN VERIFICACIÓN (solo lectura)"""
        print("🔄 Force refresh compras desde QML")
        self._cargar_compras_recientes()
        self._cargar_estadisticas()

    @Slot()
    def refresh_proveedores(self):
        """Refresca la lista de proveedores - SIN VERIFICACIÓN (solo lectura)"""
        try:
            # Invalidar cache específico de proveedores
            if hasattr(self.compra_repo, '_cache_manager'):
                self.compra_repo._cache_manager.invalidate_pattern('proveedores*')
                print("🗑️ Cache de proveedores invalidado")
            
            # Forzar recarga desde BD
            self._cargar_proveedores()
            print(f"✅ Proveedores refrescados: {len(self._proveedores)}")
            
        except Exception as e:
            self.operacionError.emit(f"Error refrescando proveedores: {str(e)}")
            print(f"❌ Error en refresh_proveedores: {str(e)}")

    @Slot()
    def force_refresh_proveedores(self):
        """Fuerza refresh completo de proveedores desde QML - SIN VERIFICACIÓN (solo lectura)"""
        print("🔄 FORCE REFRESH PROVEEDORES - Iniciando...")
        
        try:
            # 1. Invalidar cache completo
            if hasattr(self.compra_repo, '_cache_manager'):
                self.compra_repo._cache_manager.invalidate_pattern('proveedores*')
                self.compra_repo._cache_manager.invalidate_pattern('compras*')
                print("🗑️ Cache completo invalidado")
            
            # 2. Recargar desde BD
            self._cargar_proveedores()
            
            # 3. Verificar resultado
            print(f"📊 Resultado: {len(self._proveedores)} proveedores cargados")
            if len(self._proveedores) > 0:
                print("✅ FORCE REFRESH EXITOSO")
                self.operacionExitosa.emit(f"Lista actualizada: {len(self._proveedores)} proveedores")
            else:
                print("⚠️ No se encontraron proveedores")
                
        except Exception as e:
            print(f"❌ ERROR EN FORCE REFRESH: {str(e)}")
            self.operacionError.emit(f"Error actualizando proveedores: {str(e)}")

    @Slot()
    def debug_proveedores_info(self):
        """Debug info de proveedores para QML - SIN VERIFICACIÓN (solo lectura)"""
        print(f"🔍 DEBUG PROVEEDORES:")
        print(f"  - Total en memoria: {len(self._proveedores)}")
        print(f"  - CompraRepo disponible: {self.compra_repo is not None}")
        
        if len(self._proveedores) > 0:
            print(f"  - Primer proveedor: {self._proveedores[0].get('Nombre', 'Sin nombre')}")
            print(f"  - Último proveedor: {self._proveedores[-1].get('Nombre', 'Sin nombre')}")
        else:
            print("  - Lista vacía")
            
        # Intentar consulta directa
        try:
            proveedores_direct = self.compra_repo.get_proveedores_activos()
            print(f"  - Consulta directa BD: {len(proveedores_direct) if proveedores_direct else 0} proveedores")
        except Exception as e:
            print(f"  - Error consulta directa: {str(e)}")
    
    # ===============================
    # MÉTODOS PRIVADOS (SIN CAMBIOS MAYORES)
    # ===============================
    
    def _cargar_compras_recientes(self):
        """Carga compras recientes CON TRANSFORMACIÓN DE DATOS"""
        try:
            compras_raw = safe_execute(self.compra_repo.get_active)
            
            # TRANSFORMAR DATOS PARA QML
            compras_transformadas = []
            
            for compra_raw in compras_raw or []:
                compra_qml = self._format_compra_for_qml(compra_raw)
                print(f"🔍 DEBUG COMPRA QML: {compra_qml}")
                compras_transformadas.append(compra_qml)
            
            # ASIGNAR Y EMITIR SIGNAL
            self._compras_recientes = compras_transformadas
            
            # Forzar emisión de signal múltiple
            self.comprasRecientesChanged.emit()
            print(f"📡 Signal emitido: comprasRecientesChanged - {len(compras_transformadas)} compras")
            
            # Forzar emisión adicional después de un momento
            QTimer.singleShot(100, lambda: self.comprasRecientesChanged.emit())
            print(f"✅ Compras recientes cargadas y transformadas: {len(compras_transformadas)}")
            
        except Exception as e:
            print(f"❌ Error cargando compras recientes: {e}")
            self._compras_recientes = []
            self.comprasRecientesChanged.emit()
    
    def _cargar_proveedores(self):
        """Carga lista de proveedores - MEJORADO"""
        try:
            # Forzar consulta sin cache
            proveedores = self.compra_repo.get_proveedores_activos()
            
            # Validar que la consulta retornó datos
            if proveedores:
                self._proveedores = proveedores
                print(f"📋 Proveedores cargados: {len(proveedores)}")
                
                # Log detallado de proveedores
                for proveedor in proveedores:
                    print(f"  - {proveedor.get('Nombre', 'Sin nombre')} (ID: {proveedor.get('id', 'N/A')})")
            else:
                print("⚠️ No se obtuvieron proveedores desde BD")
                self._proveedores = []
            
            # Siempre emitir signal
            self.proveedoresChanged.emit()
            
        except Exception as e:
            print(f"❌ Error cargando proveedores: {e}")
            self._proveedores = []
            self.proveedoresChanged.emit()
    
    def _cargar_estadisticas(self):
        """Carga estadísticas del mes"""
        try:
            año = datetime.now().year
            mes = datetime.now().month
            estadisticas = safe_execute(
                self.compra_repo.get_compras_del_mes,
                año, mes
            )
            
            if estadisticas and estadisticas.get('resumen'):
                self._estadisticas = estadisticas['resumen']
            else:
                self._estadisticas = {
                    'Total_Compras': 0,
                    'Gastos_Total': 0,
                    'Compra_Promedio': 0,
                    'Proveedores_Utilizados': 0,
                    'Productos_Comprados': 0
                }
            
            self.estadisticasChanged.emit()
            
        except Exception as e:
            print(f"❌ Error cargando estadísticas: {e}")
    
    def _auto_update_compras(self):
        """Actualización automática de compras"""
        if not self._loading and not self._procesando_compra:
            try:
                self._cargar_compras_recientes()
                self._cargar_estadisticas()
            except Exception as e:
                print(f"❌ Error en auto-update compras: {e}")
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()
    
    def _set_procesando_compra(self, procesando: bool):
        """Actualiza estado de procesamiento de compra"""
        if self._procesando_compra != procesando:
            self._procesando_compra = procesando
            self.procesandoCompraChanged.emit()
    
    def _format_compra_for_qml(self, compra_raw: Dict[str, Any]) -> Dict[str, Any]:
        """Transforma datos de Repository a formato QML CON PRODUCTOS"""
        # Procesar fecha
        fecha_completa = compra_raw.get('Fecha', datetime.now())
        if isinstance(fecha_completa, str):
            try:
                fecha_completa = datetime.fromisoformat(fecha_completa.replace('T', ' '))
            except:
                fecha_completa = datetime.now()
        elif not isinstance(fecha_completa, datetime):
            fecha_completa = datetime.now()
        
        # Obtener resumen de productos para esta compra
        try:
            productos_raw = safe_execute(self.compra_repo.get_productos_resumen_compra, compra_raw.get('id', 0))
            
            if productos_raw and len(productos_raw) > 0:
                # Crear texto resumen para mostrar en tabla
                if len(productos_raw) == 1:
                    # Un solo producto
                    producto = productos_raw[0]
                    productos_texto = f"{producto.get('Producto_Nombre', 'Sin nombre')}"
                    total_productos = 1
                elif len(productos_raw) <= 3:
                    # Mostrar todos si son 3 o menos
                    nombres = [p.get('Producto_Nombre', 'Sin nombre') for p in productos_raw]
                    productos_texto = ', '.join(nombres)
                    total_productos = len(productos_raw)
                else:
                    # Mostrar primeros 2 + "... y X más"
                    primeros_dos = [p.get('Producto_Nombre', 'Sin nombre') for p in productos_raw[:2]]
                    restantes = len(productos_raw) - 2
                    productos_texto = f"{', '.join(primeros_dos)}... y {restantes} más"
                    total_productos = len(productos_raw)
                    
                print(f"✅ Productos para compra {compra_raw.get('id')}: {productos_texto}")
            else:
                productos_texto = "Sin productos"
                total_productos = 0
                print(f"⚠️ No se encontraron productos para compra {compra_raw.get('id')}")
                
        except Exception as e:
            print(f"❌ Error obteniendo productos para compra {compra_raw.get('id')}: {str(e)}")
            productos_texto = "Error cargando"
            total_productos = 0
        
        # Formatear datos para QML
        return {
            'id': compra_raw.get('id', 0),
            'proveedor': compra_raw.get('Proveedor_Nombre', 'Sin proveedor'),
            'usuario': compra_raw.get('Usuario', 'Sin usuario'),
            'fecha': fecha_completa.strftime('%d/%m/%Y'),
            'hora': fecha_completa.strftime('%H:%M'),
            'total': float(compra_raw.get('Total', 0)),
            
            # PRODUCTOS
            'productos_texto': productos_texto,
            'total_productos': total_productos,
            
            # Campos originales para compatibilidad
            'Proveedor_Nombre': compra_raw.get('Proveedor_Nombre', ''),
            'Usuario': compra_raw.get('Usuario', ''),
            'Total': float(compra_raw.get('Total', 0)),
            'Fecha': compra_raw.get('Fecha', ''),
            'Id_Proveedor': compra_raw.get('Id_Proveedor', 0),
            'Id_Usuario': compra_raw.get('Id_Usuario', 0)
        }
    
    def _invalidate_all_provider_cache(self):
        """Invalida TODO el cache relacionado con proveedores"""
        try:
            print("🗑️ INVALIDANDO CACHE COMPLETO DE PROVEEDORES...")
            
            # Invalidar cache de CompraRepository
            if hasattr(self.compra_repo, '_cache_manager'):
                self.compra_repo._cache_manager.invalidate_pattern('proveedores*')
                self.compra_repo._cache_manager.invalidate_pattern('compras*')
                print("🗑️ Cache CompraRepository invalidado")
            
            # Si tenemos referencia a ProveedorModel, invalidar su cache también
            if hasattr(self, '_proveedor_model_ref') and self._proveedor_model_ref:
                if hasattr(self._proveedor_model_ref, 'proveedor_repo') and hasattr(self._proveedor_model_ref.proveedor_repo, '_cache_manager'):
                    self._proveedor_model_ref.proveedor_repo._cache_manager.invalidate_pattern('proveedores*')
                    print("🗑️ Cache ProveedorRepository invalidado")
                    
        except Exception as e:
            print(f"❌ Error invalidando cache: {str(e)}")
    
    def _update_all_data_after_purchase(self):
        """Actualiza todos los datos después de una compra con delay para BD"""
        try:
            print("🔄 Actualizando datos después de compra...")
            
            # Actualizar datos locales
            self._cargar_compras_recientes()
            self._cargar_estadisticas()
            self._cargar_proveedores()
            
            print("✅ Datos locales actualizados")
            
        except Exception as e:
            print(f"❌ Error actualizando datos: {str(e)}")

    @Slot() 
    def _notify_proveedor_updated_immediate(self, proveedor_id: int, monto_compra: float):
        """Notifica inmediatamente que un proveedor fue actualizado"""
        print(f"📢 NOTIFICACIÓN INMEDIATA: Proveedor {proveedor_id} - Nueva compra: Bs{monto_compra}")
        
        try:
            # Emitir signals específicos INMEDIATAMENTE
            self.proveedorCompraCompletada.emit(proveedor_id, monto_compra)
            self.proveedorDatosActualizados.emit()
            
            # Si tenemos referencia directa, forzar refresh
            if hasattr(self, '_proveedor_model_ref') and self._proveedor_model_ref:
                QTimer.singleShot(0, self._proveedor_model_ref.force_complete_refresh)
                print("🔗 ProveedorModel será refrescado")
            
        except Exception as e:
            print(f"❌ Error en notificación: {str(e)}")

    @Slot()       
    def set_proveedor_model_reference(self, proveedor_model):
        """Establece referencia bidireccional con ProveedorModel"""
        self._proveedor_model_ref = proveedor_model
        print("🔗 Referencia a ProveedorModel establecida en CompraModel")
        
        # Conectar signals si es posible
        if proveedor_model and hasattr(proveedor_model, '_on_proveedor_compra_completada'):
            try:
                self.proveedorCompraCompletada.connect(proveedor_model._on_proveedor_compra_completada)
                self.proveedorDatosActualizados.connect(proveedor_model._force_refresh_after_purchase)
                print("🔗 Signals conectados correctamente")
            except Exception as e:
                print(f"❌ Error conectando signals: {str(e)}")

    @Slot()
    def set_inventario_model_reference(self, inventario_model):
        """Establece referencia a InventarioModel para actualizar stock"""
        self._inventario_model_ref = inventario_model
        print("🔗 Referencia a InventarioModel establecida en CompraModel")
        
        # DEBUG: Verificar que la referencia es correcta
        if inventario_model:
            print(f"✅ Referencia válida: {type(inventario_model).__name__}")
        else:
            print("❌ Referencia es None")

    def crear_producto_completo(self, producto_data):
        """Crea producto + primer lote desde QML"""
        try:
            # Usar el producto_repo que ya tienes
            resultado = safe_execute(
                self.producto_repo.crear_producto_con_primer_lote,
                producto_data
            )
            
            if resultado:
                self.operacionExitosa.emit(f"Producto creado: {producto_data['nombre']}")
                return True
            else:
                raise Exception("Error creando producto")
                
        except Exception as e:
            self.operacionError.emit(f"Error: {str(e)}")
            return False
        
    def _validar_fecha_vencimiento(self, fecha_str):
        """Convierte DD/MM/YYYY a YYYY-MM-DD"""
        if '/' in fecha_str:
            parts = fecha_str.split('/')
            return f"{parts[2]}-{parts[1]}-{parts[0]}"
        return fecha_str

    def aplicar_filtro_proveedor(self, proveedor_filtro: str):
        """Aplica filtro por proveedor"""
        self._filtro_proveedor = proveedor_filtro
        print(f"🏢 Filtro proveedor aplicado: {proveedor_filtro}")
        self._aplicar_filtros_compras()

    def emergency_disconnect(self):
        """Desconexión de emergencia para CompraModel"""
        try:
            print("🚨 CompraModel: Iniciando desconexión de emergencia...")
            
            # Detener timer
            if hasattr(self, 'update_timer') and self.update_timer.isActive():
                self.update_timer.stop()
                print("   ⏹️ Update timer detenido")
            
            # Establecer estado shutdown
            self._loading = False
            self._procesando_compra = False
            
            # Desconectar todas las señales
            signals_to_disconnect = [
                'comprasRecientesChanged', 'compraActualChanged', 'proveedoresChanged',
                'historialComprasChanged', 'estadisticasChanged', 'topProductosCompradosChanged',
                'compraCreada', 'proveedorCreado', 'operacionExitosa', 'operacionError',
                'loadingChanged', 'procesandoCompraChanged', 'itemsCompraCambiado',
                'proveedorCompraCompletada', 'proveedorDatosActualizados', 'filtrosChanged'
            ]
            
            for signal_name in signals_to_disconnect:
                if hasattr(self, signal_name):
                    try:
                        getattr(self, signal_name).disconnect()
                    except:
                        pass
            
            # Limpiar datos
            self._compras_recientes = []
            self._compra_actual = {}
            self._proveedores = []
            self._historial_compras = []
            self._estadisticas = {}
            self._top_productos_comprados = []
            self._items_compra = []
            self._proveedor_seleccionado = 0
            self._usuario_actual_id = 0  # ✅ RESETEAR USUARIO
            
            # Anular repositories
            self.compra_repo = None
            self.producto_repo = None
            
            print("✅ CompraModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión CompraModel: {e}")

# Registrar el tipo para QML
def register_compra_model():
    qmlRegisterType(CompraModel, "ClinicaModels", 1, 0, "CompraModel")
    print("🔗 CompraModel registrado para QML con autenticación estandarizada")