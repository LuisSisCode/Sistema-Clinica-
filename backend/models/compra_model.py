from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
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
    Model QObject para gestión de compras con auto-creación de lotes
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
        
        # Configuración
        self._usuario_actual = 0
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
        
        print("📦 CompraModel inicializado")
    
    # ===============================
    # PROPERTIES PARA QML
    # ===============================
    
    @Property(list, notify=comprasRecientesChanged)
    def compras_recientes(self):
        """Lista de compras recientes"""
        print(f"🔍 DEBUG Property: compras_recientes leída - Total: {len(self._compras_recientes)}")
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
    
    @Property(int, notify=comprasRecientesChanged)
    def total_compras_mes(self):
        """Total de compras del mes"""
        total = len(self._compras_recientes)
        print(f"🔍 DEBUG Property: total_compras_mes = {total}")
        return total
    
    # ===============================
    # SLOTS PARA QML - CONFIGURACIÓN
    # ===============================
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """Establece el usuario actual para las compras"""
        if usuario_id > 0:
            self._usuario_actual = usuario_id
            print(f"👤 Usuario establecido para compras: {usuario_id}")
    
    @Slot(int)
    def set_proveedor_seleccionado(self, proveedor_id: int):
        """Establece el proveedor para la compra actual"""
        if proveedor_id > 0:
            self._proveedor_seleccionado = proveedor_id
            print(f"🏢 Proveedor seleccionado: {proveedor_id}")
    
    @Slot()
    def refresh_compras(self):
        """Refresca las compras recientes"""
        self._cargar_compras_recientes()
    
    @Slot()
    def refresh_proveedores(self):
        """Refresca la lista de proveedores"""
        self._cargar_proveedores()
    
    @Slot()
    def refresh_estadisticas(self):
        """Refresca las estadísticas"""
        self._cargar_estadisticas()
    
    # ===============================
    # SLOTS PARA QML - GESTIÓN PROVEEDORES
    # ===============================
    
    @Slot(str, str, result=int)
    def crear_proveedor(self, nombre: str, direccion: str):
        """Crea un nuevo proveedor"""
        if not nombre or not nombre.strip():
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
                
                self.proveedorCreado.emit(proveedor_id, nombre.strip())
                self.operacionExitosa.emit(f"Proveedor creado: {nombre}")
                
                print(f"🏢 Proveedor creado - ID: {proveedor_id}, Nombre: {nombre}")
                return proveedor_id
            else:
                raise CompraError("Error creando proveedor")
                
        except Exception as e:
            self.operacionError.emit(f"Error creando proveedor: {str(e)}")
            return 0
    
    @Slot(str, result=list)
    def buscar_proveedores(self, termino: str):
        """Busca proveedores por nombre o dirección"""
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
        """Obtiene detalles de un proveedor"""
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
    # SLOTS PARA QML - ITEMS DE COMPRA
    # ===============================
    
    @Slot(str, int, int, float, str)
    def agregar_item_compra(self, codigo: str, cantidad_caja: int, cantidad_unitario: int, 
                           precio_unitario: float, fecha_vencimiento: str):
        """Agrega item a la compra actual"""
        if not codigo or (cantidad_caja <= 0 and cantidad_unitario <= 0):
            self.operacionError.emit("Código o cantidades inválidos")
            return
        
        if precio_unitario <= 0:
            self.operacionError.emit("Precio unitario debe ser mayor a 0")
            return
        
        if not fecha_vencimiento:
            self.operacionError.emit("Fecha de vencimiento requerida")
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
            
            cantidad_total = cantidad_caja + cantidad_unitario
            subtotal = cantidad_total * precio_unitario
            
            if item_existente:
                # Actualizar item existente
                item_existente['cantidad_caja'] += cantidad_caja
                item_existente['cantidad_unitario'] += cantidad_unitario
                item_existente['cantidad_total'] = item_existente['cantidad_caja'] + item_existente['cantidad_unitario']
                item_existente['subtotal'] = item_existente['cantidad_total'] * precio_unitario
                item_existente['fecha_vencimiento'] = fecha_vencimiento  # Actualizar fecha
            else:
                # Agregar nuevo item
                nuevo_item = {
                    'codigo': codigo.strip(),
                    'producto_id': producto['id'],
                    'nombre': producto['Nombre'],
                    'marca': producto.get('Marca_Nombre', ''),
                    'cantidad_caja': cantidad_caja,
                    'cantidad_unitario': cantidad_unitario,
                    'cantidad_total': cantidad_total,
                    'precio_unitario': precio_unitario,
                    'fecha_vencimiento': fecha_vencimiento,
                    'subtotal': subtotal
                }
                self._items_compra.append(nuevo_item)
            
            self.itemsCompraCambiado.emit()
            self.operacionExitosa.emit(f"Agregado: {cantidad_total}x {codigo}")
            print(f"📦 Item compra agregado - {codigo}: {cantidad_total}x${precio_unitario}")
            
        except Exception as e:
            self.operacionError.emit(f"Error agregando item: {str(e)}")
    
    @Slot(str)
    def remover_item_compra(self, codigo: str):
        """Remueve item de la compra actual"""
        if not codigo:
            return
        
        self._items_compra = [
            item for item in self._items_compra 
            if item['codigo'] != codigo.strip()
        ]
        self.itemsCompraCambiado.emit()
        self.operacionExitosa.emit(f"Removido: {codigo}")
    
    @Slot(str, int, int)
    def actualizar_cantidades_item(self, codigo: str, nueva_cantidad_caja: int, nueva_cantidad_unitario: int):
        """Actualiza cantidades de un item en compra"""
        if not codigo or (nueva_cantidad_caja < 0 or nueva_cantidad_unitario < 0):
            return
        
        if nueva_cantidad_caja == 0 and nueva_cantidad_unitario == 0:
            self.remover_item_compra(codigo)
            return
        
        for item in self._items_compra:
            if item['codigo'] == codigo.strip():
                item['cantidad_caja'] = nueva_cantidad_caja
                item['cantidad_unitario'] = nueva_cantidad_unitario
                item['cantidad_total'] = nueva_cantidad_caja + nueva_cantidad_unitario
                item['subtotal'] = item['cantidad_total'] * item['precio_unitario']
                break
        
        self.itemsCompraCambiado.emit()
        print(f"📦 Cantidades actualizadas - {codigo}: {nueva_cantidad_caja}+{nueva_cantidad_unitario}")
    
    @Slot(str, float)
    def actualizar_precio_item(self, codigo: str, nuevo_precio: float):
        """Actualiza precio de un item en compra"""
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
        """Limpia todos los items de la compra actual"""
        self._items_compra.clear()
        self.itemsCompraCambiado.emit()
        self.operacionExitosa.emit("Items de compra limpiados")
    
    # ===============================
    # SLOTS PARA QML - PROCESAMIENTO COMPRAS
    # ===============================
    
    @Slot(result=bool)
    def procesar_compra_actual(self):
        """Procesa la compra con los items actuales"""
        if not self._items_compra:
            self.operacionError.emit("No hay items para comprar")
            return False
        
        if self._proveedor_seleccionado <= 0:
            self.operacionError.emit("Proveedor no seleccionado")
            return False
        
        if self._usuario_actual <= 0:
            self.operacionError.emit("Usuario no establecido")
            return False
        
        self._set_procesando_compra(True)
        
        try:
            # Preparar items para compra
            items_compra = []
            for item in self._items_compra:
                items_compra.append({
                    'codigo': item['codigo'],
                    'cantidad_caja': item['cantidad_caja'],
                    'cantidad_unitario': item['cantidad_unitario'],
                    'precio_unitario': item['precio_unitario'],
                    'fecha_vencimiento': item['fecha_vencimiento']
                })
            
            # Procesar compra
            compra = safe_execute(
                self.compra_repo.crear_compra,
                self._proveedor_seleccionado,
                self._usuario_actual,
                items_compra
            )
            
            if compra:
                # Limpiar items
                self.limpiar_items_compra()
                
                # Actualizar datos
                self._cargar_compras_recientes()
                self._cargar_estadisticas()
                
                # Establecer compra actual
                self._compra_actual = compra
                self.compraActualChanged.emit()
                
                # Emitir signals
                self.compraCreada.emit(compra['id'], float(compra['Total']))
                self.operacionExitosa.emit(f"Compra procesada: ${compra['Total']:.2f}")
                
                print(f"✅ Compra exitosa - ID: {compra['id']}, Total: ${compra['Total']}")
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
        """Procesa compra rápida desde JSON"""
        if proveedor_id <= 0 or not items_json:
            self.operacionError.emit("Datos de compra inválidos")
            return False
        
        if self._usuario_actual <= 0:
            self.operacionError.emit("Usuario no establecido")
            return False
        
        self._set_procesando_compra(True)
        
        try:
            # Parsear items JSON
            items = json.loads(items_json)
            if not items:
                raise CompraError("No hay items en JSON")
            
            # Procesar compra
            compra = safe_execute(
                self.compra_repo.crear_compra,
                proveedor_id,
                self._usuario_actual,
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
    
    # ===============================
    # SLOTS PARA QML - CONSULTAS
    # ===============================
    
    @Slot(int, result='QVariant')
    def get_compra_detalle(self, compra_id: int):
        """Obtiene detalle completo de una compra"""
        if compra_id <= 0:
            return {}
        
        try:
            compra = safe_execute(self.compra_repo.get_compra_completa, compra_id)
            return compra if compra else {}
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo compra: {str(e)}")
            return {}
    
    @Slot(str, str)
    def cargar_historial(self, fecha_desde: str, fecha_hasta: str):
        """Carga historial de compras por período"""
        self._set_loading(True)
        
        try:
            if fecha_desde and fecha_hasta:
                compras = safe_execute(
                    self.compra_repo.get_compras_con_detalles,
                    fecha_desde, fecha_hasta
                )
            else:
                # Último mes por defecto
                fecha_desde = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
                compras = safe_execute(
                    self.compra_repo.get_compras_con_detalles,
                    fecha_desde, None
                )
            
            self._historial_compras = compras or []
            self.historialComprasChanged.emit()
            
            print(f"📊 Historial compras cargado: {len(self._historial_compras)} compras")
            
        except Exception as e:
            self.operacionError.emit(f"Error cargando historial: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot(int)
    def cargar_top_productos_comprados(self, dias: int = 30):
        """Carga top productos más comprados"""
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
        """Obtiene compras por proveedor"""
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
    
    @Slot(result='QVariant')
    def get_reporte_gastos(self):
        """Obtiene reporte de gastos en compras"""
        try:
            reporte = safe_execute(self.compra_repo.get_reporte_gastos_compras, 30)
            return reporte if reporte else {}
        except Exception as e:
            self.operacionError.emit(f"Error en reporte gastos: {str(e)}")
            return {}
    
    @Slot()
    def force_refresh_compras(self):
        """Fuerza refresh de compras desde QML"""
        print("🔄 Force refresh compras desde QML")
        self._cargar_compras_recientes()
        self._cargar_estadisticas()
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_compras_recientes(self):
        """Carga compras recientes CON TRANSFORMACIÓN DE DATOS"""
        try:
            compras_raw = safe_execute(self.compra_repo.get_active)
            
            if compras_raw and len(compras_raw) > 0:
                print("🔍 DEBUG COMPRA MODEL - Datos desde Repository:")
                primer_registro = compras_raw[0]
                for key, value in primer_registro.items():
                    print(f"   RAW: {key}: {value} (tipo: {type(value)})")
            
            # TRANSFORMAR DATOS PARA QML
            compras_transformadas = []
            
            for compra_raw in compras_raw or []:
                compra_qml = self._format_compra_for_qml(compra_raw)
                compras_transformadas.append(compra_qml)
            
            # ASIGNAR Y EMITIR SIGNAL
            self._compras_recientes = compras_transformadas
            
            # ✅ FORZAR EMISIÓN DE SIGNAL MÚLTIPLE
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
        """Carga lista de proveedores"""
        try:
            proveedores = safe_execute(self.compra_repo.get_proveedores_activos)
            self._proveedores = proveedores or []
            self.proveedoresChanged.emit()
            
        except Exception as e:
            print(f"❌ Error cargando proveedores: {e}")
    
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
    # Funcione para formatear compra a QML
    def _format_compra_for_qml(self, compra_raw: Dict[str, Any]) -> Dict[str, Any]:
        """Transforma datos de Repository a formato QML"""
        # Procesar fecha
        fecha_completa = compra_raw.get('Fecha', datetime.now())
        if isinstance(fecha_completa, str):
            try:
                fecha_completa = datetime.fromisoformat(fecha_completa.replace('T', ' '))
            except:
                fecha_completa = datetime.now()
        elif not isinstance(fecha_completa, datetime):
            fecha_completa = datetime.now()
        
        # Formatear datos para QML
        return {
            'id': compra_raw.get('id', 0),
            'proveedor': compra_raw.get('Proveedor_Nombre', 'Sin proveedor'),
            'usuario': compra_raw.get('Usuario', 'Sin usuario'),
            'fecha': fecha_completa.strftime('%d/%m/%Y'),
            'hora': fecha_completa.strftime('%H:%M'),
            'total': float(compra_raw.get('Total', 0)),
            
            # Campos originales para compatibilidad
            'Proveedor_Nombre': compra_raw.get('Proveedor_Nombre', ''),
            'Usuario': compra_raw.get('Usuario', ''),
            'Total': float(compra_raw.get('Total', 0)),
            'Fecha': compra_raw.get('Fecha', ''),
            'Id_Proveedor': compra_raw.get('Id_Proveedor', 0),
            'Id_Usuario': compra_raw.get('Id_Usuario', 0)
        }

# Registrar el tipo para QML
def register_compra_model():
    qmlRegisterType(CompraModel, "ClinicaModels", 1, 0, "CompraModel")