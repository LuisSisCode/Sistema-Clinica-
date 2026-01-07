"""
CompraModel - VERSIÓN 2.0 SIMPLIFICADA CORREGIDA
✅ Métodos faltantes agregados:
   - force_refresh_compras
   - force_refresh_proveedores
   - agregar_producto_a_compra
✅ Sin márgenes, precio total
✅ Actualización de precio_venta
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
    """Model QObject para gestión de compras - V2.0 CORREGIDA"""
    
    # ===============================
    # SIGNALS PARA QML
    # ===============================
    comprasRecientesChanged = Signal()
    compraActualChanged = Signal()
    proveedoresChanged = Signal()
    historialComprasChanged = Signal()
    estadisticasChanged = Signal()
    topProductosCompradosChanged = Signal()
    compraCreada = Signal(int, float)
    compraActualizada = Signal(int, float)
    proveedorCreado = Signal(int, str)
    operacionExitosa = Signal(str)
    operacionError = Signal(str)
    loadingChanged = Signal()
    procesandoCompraChanged = Signal()
    itemsCompraCambiado = Signal()
    modoEdicionChanged = Signal()
    datosOriginalesChanged = Signal()
    proveedorCompraCompletada = Signal(int, float)
    proveedorDatosActualizados = Signal()
    filtrosChanged = Signal()

    # Signal asociada (agregar arriba con los otros signals)
    compraDetalleChanged = Signal()
    
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
        self._usuario_actual_id = 0
        self._proveedor_seleccionado = 0
        
        # Timer para actualización automática
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._auto_update_compras)
        self.update_timer.start(120000)  # 2 minutos

        # Variable interna (agregar en __init__)
        self._compra_actual = {}
        
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
        """Establece el usuario autenticado"""
        if usuario_id != self._usuario_actual_id:
            self._usuario_actual_id = usuario_id
            print(f"👤 Usuario autenticado en CompraModel: {usuario_id}")
            self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de compras")
            self._cargar_compras_recientes()
            self._cargar_proveedores()
    
    @Property(int, notify=proveedoresChanged)
    def usuario_actual_id(self):
        return self._usuario_actual_id
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica que haya un usuario autenticado"""
        if self._usuario_actual_id <= 0:
            print("⚠️ No hay usuario autenticado en CompraModel")
            self.operacionError.emit("Debe iniciar sesión para realizar compras")
            return False
        return True
    
    # ===============================
    # PROPERTIES PARA QML
    # ===============================
    @Property(list, notify=comprasRecientesChanged)
    def compras_recientes(self):
        return self._compras_recientes
    
    @Property('QVariantMap', notify=compraActualChanged)
    def compra_actual(self):
        return self._compra_actual
    
    @Property(list, notify=proveedoresChanged)
    def proveedores(self):
        return self._proveedores
    
    @Property(list, notify=historialComprasChanged)
    def historial_compras(self):
        return self._historial_compras
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self):
        return self._estadisticas
    
    @Property(list, notify=topProductosCompradosChanged)
    def top_productos_comprados(self):
        return self._top_productos_comprados
    
    @Property(list, notify=itemsCompraCambiado)
    def items_compra(self):
        return self._items_compra
    
    @Property(bool, notify=loadingChanged)
    def loading(self):
        return self._loading
    
    @Property(bool, notify=procesandoCompraChanged)
    def procesando_compra(self):
        return self._procesando_compra
    
    @Property(int, notify=comprasRecientesChanged)
    def total_compras_mes(self):
        return len(self._compras_recientes)
    
    @Property(float, notify=estadisticasChanged)
    def gastos_mes(self):
        return self._estadisticas.get('Gastos_Total', 0.0)
    
    @Property(float, notify=itemsCompraCambiado)
    def total_compra_actual(self):
        return sum(item.get('subtotal', 0.0) for item in self._items_compra)
    
    @Property(int, notify=itemsCompraCambiado)
    def items_en_compra(self):
        return len(self._items_compra)
    
    @Property(int, notify=proveedoresChanged)
    def total_proveedores(self):
        return len(self._proveedores)
    
    @Property(bool, notify=modoEdicionChanged)
    def modo_edicion(self):
        return self._modo_edicion
    
    @Property(int, notify=modoEdicionChanged)
    def compra_id_edicion(self):
        return self._compra_id_edicion
    
    @Property('QVariantMap', notify=datosOriginalesChanged)
    def datos_originales(self):
        return self._datos_originales
    
    @Property('QVariantMap', notify=compraDetalleChanged)
    def compra_actual(self):
        """Compra actualmente seleccionada con sus detalles"""
        return self._compra_actual
    
    # ===============================
    # MÉTODOS DE CARGA DE DATOS
    # ===============================
    def _cargar_compras_recientes(self):
        """Carga compras del mes actual"""
        try:
            compras = self.compra_repo.get_active()
            self._compras_recientes = compras
            
            # DEBUG: Verificar productos
            for compra in compras:
                prod_count = compra.get('total_productos', 0)
                prod_texto = compra.get('productos_texto', '')
                print(f"  Compra {compra.get('id')}: {prod_count} productos - '{prod_texto[:50]}'")
            
            self.comprasRecientesChanged.emit()
            print(f"✅ {len(compras)} compras cargadas con productos")
        except Exception as e:
            print(f"❌ Error cargando compras: {e}")
    
    def _cargar_proveedores(self):
        """Carga lista de proveedores"""
        try:
            from ..repositories.proveedor_repository import ProveedorRepository
            proveedor_repo = ProveedorRepository()
            proveedores = safe_execute(proveedor_repo.get_active) or []
            self._proveedores = proveedores
            self.proveedoresChanged.emit()
            print(f"🏢 Proveedores cargados: {len(proveedores)}")
        except Exception as e:
            print(f"❌ Error cargando proveedores: {e}")
            self._proveedores = []
            self.proveedoresChanged.emit()
    
    def _cargar_estadisticas(self):
        """Carga estadísticas de compras"""
        try:
            stats = safe_execute(self.compra_repo.get_estadisticas) or {}
            self._estadisticas = stats
            self.estadisticasChanged.emit()
            print(f"📊 Estadísticas cargadas: {stats}")
        except Exception as e:
            print(f"❌ Error cargando estadísticas: {e}")
            self._estadisticas = {}
            self.estadisticasChanged.emit()
    
    def _auto_update_compras(self):
        """Actualización automática periódica"""
        if not self._procesando_compra:
            self._cargar_compras_recientes()
            self._cargar_estadisticas()
    
    # ===============================
    # ✅ MÉTODOS FALTANTES AGREGADOS
    # ===============================
    @Slot()
    def force_refresh_compras(self):
        """Forzar refresco de compras (llamado desde QML)"""
        print("🔄 Force refresh compras")
        self._cargar_compras_recientes()
        self._cargar_estadisticas()
        self.operacionExitosa.emit("Compras actualizadas")
    
    @Slot()
    def force_refresh_proveedores(self):
        """Forzar refresco de proveedores (llamado desde QML)"""
        print("🔄 Force refresh proveedores")
        self._cargar_proveedores()
        self.operacionExitosa.emit("Proveedores actualizados")
    
    # ===============================
    # BÚSQUEDA DE PRODUCTOS
    # ===============================
    @Slot(str, result='QVariantList')
    def buscar_producto(self, termino: str):
        """Busca productos por código o nombre"""
        if not termino or len(termino) < 2:
            return []
        
        try:
            termino = termino.lower().strip()
            productos = safe_execute(
                lambda: self.producto_repo.search(termino)
            ) or []
            
            print(f"🔍 Búsqueda '{termino}': {len(productos)} productos encontrados")
            return productos
            
        except Exception as e:
            print(f"❌ Error en búsqueda: {e}")
            return []
    
    @Slot(str, result='QVariantMap')
    def obtener_datos_precio_producto(self, codigo: str):
        """Obtiene datos de precio del producto por código"""
        try:
            producto = safe_execute(
                lambda: self.producto_repo.get_by_codigo(codigo)
            )
            
            if not producto:
                print(f"❌ Producto no encontrado: {codigo}")
                self.operacionError.emit(f"Producto no encontrado: {codigo}")
                return {}
            
            # Verificar si es primera compra (precio_venta = 0 o NULL)
            precio_venta_actual = float(producto.get('Precio_venta', 0) or 0)
            es_primera_compra = precio_venta_actual == 0
            
            resultado = {
                "codigo": codigo,
                "nombre": producto.get('Nombre', ''),
                "precio_venta": precio_venta_actual,
                "es_primera": es_primera_compra,
                "unidad_medida": producto.get('Unidad_Medida', 'Unidades')
            }
            
            print(f"📦 Datos producto {codigo}: {resultado}")
            return resultado
            
        except Exception as e:
            print(f"❌ Error obteniendo datos: {e}")
            self.operacionError.emit(f"Error: {str(e)}")
            return {}
        
    @Slot(int, result='QVariantMap')
    def get_compra_completa(self, compra_id: int):
        """Obtiene detalle completo de una compra para QML"""
        try:
            compra = self.compra_repo.get_compra_completa(compra_id)
            if compra:
                return compra
            return {}
        except Exception as e:
            print(f"❌ Error obteniendo compra completa: {e}")
            self.operacionError.emit(f"Error: {str(e)}")
            return {}
    
    # ===============================
    # ✅ MÉTODO CRÍTICO: agregar_producto_a_compra
    # ===============================
    @Slot(str, 'QVariantMap', result=bool)
    def agregar_producto_a_compra(self, codigo: str, datos_lote: Dict):
        """
        Agrega un producto a la compra actual (MÉTODO PRINCIPAL PARA QML)
        
        Args:
            codigo: Código del producto
            datos_lote: {
                "Cantidad_Unitario": int,
                "Precio_Compra": float (TOTAL, no unitario),
                "Vencimiento": str o None,
                "Precio_Venta": float (opcional, para primera compra)
            }
        """
        try:
            print(f"➕ Agregando producto: {codigo}")
            print(f"   Datos: {datos_lote}")
            
            # Validaciones
            cantidad = int(datos_lote.get('Cantidad_Unitario', 0))
            precio_total = float(datos_lote.get('Precio_Compra', 0))
            vencimiento = datos_lote.get('Vencimiento')
            precio_venta = datos_lote.get('Precio_Venta')
            
            if cantidad <= 0:
                self.operacionError.emit("La cantidad debe ser mayor a 0")
                return False
            
            if precio_total <= 0:
                self.operacionError.emit("El precio total debe ser mayor a 0")
                return False
            
            # Calcular precio unitario
            precio_unitario = precio_total / cantidad
            
            # Obtener info del producto
            producto = safe_execute(lambda: self.producto_repo.get_by_codigo(codigo))
            if not producto:
                self.operacionError.emit(f"Producto no encontrado: {codigo}")
                return False
            
            # Crear item para la compra
            item = {
                "codigo": codigo,
                "nombre": producto.get('Nombre', ''),
                "cantidad": cantidad,
                "precio_unitario": precio_unitario,
                "precio_total": precio_total,
                "vencimiento": vencimiento if vencimiento else "Sin vencimiento",
                "subtotal": precio_total
            }
            
            # Si hay precio de venta, agregarlo
            if precio_venta and float(precio_venta) > 0:
                item["precio_venta"] = float(precio_venta)
            
            # Agregar a la lista
            self._items_compra.append(item)
            self.itemsCompraCambiado.emit()
            
            print(f"✅ Producto agregado: {codigo} - {cantidad} unidades")
            self.operacionExitosa.emit(f"Producto agregado: {producto.get('Nombre', '')}")
            return True
            
        except Exception as e:
            error_msg = f"Error al agregar producto: {str(e)}"
            print(f"❌ {error_msg}")
            self.operacionError.emit(error_msg)
            return False
    
    # ===============================
    # MÉTODO LEGACY (mantener compatibilidad)
    # ===============================
    @Slot(str, int, float, str, result=bool)
    def agregar_item_compra(self, codigo: str, cantidad: int, precio_total: float,
                             vencimiento: str = ""):
        """Método legacy para compatibilidad"""
        datos_lote = {
            "Cantidad_Unitario": cantidad,
            "Precio_Compra": precio_total,
            "Vencimiento": vencimiento if vencimiento else None
        }
        return self.agregar_producto_a_compra(codigo, datos_lote)
    
    # ===============================
    # GESTIÓN DE ITEMS
    # ===============================
    @Slot(int, result=bool)
    def eliminar_item_compra(self, index: int):
        """Elimina un item de la compra actual"""
        try:
            if 0 <= index < len(self._items_compra):
                item_eliminado = self._items_compra.pop(index)
                self.itemsCompraCambiado.emit()
                print(f"🗑️ Item eliminado: {item_eliminado.get('nombre', '')}")
                self.operacionExitosa.emit("Producto eliminado de la compra")
                return True
            return False
        except Exception as e:
            print(f"❌ Error eliminando item: {e}")
            return False
    
    @Slot(int, result=bool)
    def remover_item_compra(self, index: int):
        """Alias para eliminar_item_compra (compatibilidad con QML)"""
        return self.eliminar_item_compra(index)
    
    @Slot(int, 'QVariantMap', result=bool)
    def actualizar_item_compra(self, index: int, datos_lote: Dict):
        """Actualiza un item de la compra"""
        try:
            if 0 <= index < len(self._items_compra):
                item = self._items_compra[index]
                
                # Actualizar datos
                cantidad = int(datos_lote.get('Cantidad_Unitario', item.get('cantidad', 0)))
                precio_total = float(datos_lote.get('Precio_Compra', item.get('precio_total', 0)))
                vencimiento = datos_lote.get('Vencimiento', item.get('vencimiento'))
                
                precio_unitario = precio_total / cantidad if cantidad > 0 else 0
                
                item['cantidad'] = cantidad
                item['precio_unitario'] = precio_unitario
                item['precio_total'] = precio_total
                item['vencimiento'] = vencimiento if vencimiento else "Sin vencimiento"
                item['subtotal'] = precio_total
                
                self.itemsCompraCambiado.emit()
                self.operacionExitosa.emit("Producto actualizado")
                return True
            return False
        except Exception as e:
            print(f"❌ Error actualizando item: {e}")
            return False
    
    # ===============================
    # COMPLETAR COMPRA
    # ===============================
    @Slot(int, result=bool)
    def completar_compra(self, proveedor_id: int):
        """Completa y guarda la compra"""
        if not self._verificar_autenticacion():
            return False
        
        if not self._items_compra:
            self.operacionError.emit("No hay productos en la compra")
            return False
        
        if proveedor_id <= 0:
            self.operacionError.emit("Debe seleccionar un proveedor")
            return False
        
        self._set_procesando(True)
        
        try:
            # Preparar items para el repository
            items_repo = []
            for item in self._items_compra:
                item_repo = {
                    "producto_codigo": item['codigo'],
                    "cantidad": item['cantidad'],
                    "precio_total": item['precio_total'],
                    "vencimiento": item.get('vencimiento') if item.get('vencimiento') != "Sin vencimiento" else None
                }
                
                # Si hay precio de venta, agregarlo
                if 'precio_venta' in item and item['precio_venta'] > 0:
                    item_repo['precio_venta'] = item['precio_venta']
                
                items_repo.append(item_repo)
            
            # Crear compra
            compra_id = safe_execute(
                lambda: self.compra_repo.crear_compra(
                    proveedor_id=proveedor_id,
                    usuario_id=self._usuario_actual_id,
                    items=items_repo
                )
            )
            
            if compra_id:
                total = self.total_compra_actual
                self.limpiar_items()
                self._cargar_compras_recientes()
                self._cargar_estadisticas()
                
                self.compraCreada.emit(compra_id, total)
                self.operacionExitosa.emit(f"Compra registrada exitosamente (ID: {compra_id})")
                print(f"✅ Compra completada: ID {compra_id}, Total: Bs {total:.2f}")
                return True
            else:
                self.operacionError.emit("Error al crear la compra")
                return False
                
        except Exception as e:
            error_msg = f"Error completando compra: {str(e)}"
            print(f"❌ {error_msg}")
            self.operacionError.emit(error_msg)
            return False
        finally:
            self._set_procesando(False)
    
    @Slot()
    def limpiar_items(self):
        """Limpia todos los items de la compra actual"""
        self._items_compra = []
        self.itemsCompraCambiado.emit()
        print("🧹 Items de compra limpiados")
    
    def _set_procesando(self, estado: bool):
        """Establece el estado de procesamiento"""
        if self._procesando_compra != estado:
            self._procesando_compra = estado
            self.procesandoCompraChanged.emit()
    
    # ===============================
    # CONSULTAS
    # ===============================
    @Slot(int, result='QVariantMap')
    def get_compra_detalle(self, compra_id: int):
        """Obtiene detalle completo de una compra"""
        try:
            compra = safe_execute(
                lambda: self.compra_repo.get_compra_completa(compra_id)
            )
            if compra:
                print(f"📋 Compra {compra_id} obtenida")
                return compra
            else:
                self.operacionError.emit(f"Compra {compra_id} no encontrada")
                return {}
        except Exception as e:
            print(f"❌ Error obteniendo compra: {e}")
            self.operacionError.emit(f"Error: {str(e)}")
            return {}
    
    # ===============================
    # MÉTODOS PÚBLICOS DE REFRESH
    # ===============================
    @Slot()
    def refresh_proveedores(self):
        """Refresca lista de proveedores"""
        self._cargar_proveedores()
    
    @Slot()
    def refresh_compras(self):
        """Refresca lista de compras"""
        self._cargar_compras_recientes()
        self._cargar_estadisticas()

    @Slot(int)
    def cargar_detalle_compra(self, compra_id: int):
        """Carga el detalle de una compra y emite signal"""
        try:
            print(f"📋 Cargando detalle de compra ID: {compra_id}")
            compra = self.compra_repo.get_compra_completa(compra_id)
            
            if compra:
                self._compra_actual = compra
                self.compraDetalleChanged.emit()
                print(f"✅ Compra {compra_id} cargada: {len(compra.get('detalles', []))} productos")
            else:
                print(f"⚠️ Compra {compra_id} no encontrada")
                self._compra_actual = {}
                self.compraDetalleChanged.emit()
                
        except Exception as e:
            print(f"❌ Error cargando detalle: {e}")
            self.operacionError.emit(f"Error: {str(e)}")

def register_compra_model():
    """Registra el modelo para uso en QML"""
    qmlRegisterType(CompraModel, "CompraModule", 1, 0, "CompraModel")
    print("✅ CompraModel v2.0 registrado en QML")