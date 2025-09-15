from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer, Qt
from PySide6.QtQml import qmlRegisterType
from typing import List, Dict, Any, Optional
import json
from datetime import datetime

from ..repositories.proveedor_repository import ProveedorRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, safe_execute, validate_required
)

class ProveedorModel(QObject):
    """
    Model QObject para gestión de proveedores - SOLO 3 CAMPOS
    Conecta directamente con QML mediante Signals/Slots/Properties
    """
    
    # ===============================
    # SIGNALS PARA QML
    # ===============================
    
    # Signals de datos
    proveedoresChanged = Signal()
    proveedorActualChanged = Signal()
    historialComprasChanged = Signal()
    estadisticasChanged = Signal()
    resumenChanged = Signal()
    
    # Signals de operaciones
    proveedorCreado = Signal(int, str)  # proveedor_id, nombre
    proveedorActualizado = Signal(int, str)  # proveedor_id, nombre
    proveedorEliminado = Signal(int, str)  # proveedor_id, nombre
    operacionExitosa = Signal(str)     # mensaje
    operacionError = Signal(str)       # mensaje_error
    
    # Signals de estados
    loadingChanged = Signal()
    searchResultsChanged = Signal()
    
    def __init__(self):
        super().__init__()
        
        # Repository
        self.proveedor_repo = ProveedorRepository()
        
        # Datos internos
        self._proveedores = []
        self._proveedor_actual = {}
        self._historial_compras = []
        self._estadisticas = {}
        self._resumen = {}
        self._search_results = []
        self._loading = False
        
        # Configuración de paginación
        self._pagina_actual = 1
        self._por_pagina = 10
        self._total_paginas = 0
        self._total_proveedores = 0
        self._termino_busqueda = ""
        
        # Timer para búsqueda con delay
        self.search_timer = QTimer()
        self.search_timer.setSingleShot(True)
        self.search_timer.timeout.connect(self._ejecutar_busqueda)
        
        # Timer para actualizaciones automáticas
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._auto_update_proveedores)
        self.update_timer.start(300000)  # 5 minutos
        # Reference a CompraModel para sync
        self._compra_model_ref = None
        
        # Cargar datos iniciales
        self._cargar_proveedores()
        self._cargar_resumen()
        
        print("🏢 ProveedorModel inicializado - SIMPLIFICADO")
    
    # ===============================
    # PROPERTIES PARA QML
    # ===============================
    
    @Property(list, notify=proveedoresChanged)
    def proveedores(self):
        """Lista de proveedores activos"""
        return self._proveedores
    
    @Property('QVariant', notify=proveedorActualChanged)
    def proveedor_actual(self):
        """Proveedor actualmente seleccionado"""
        return self._proveedor_actual
    
    @Property(list, notify=historialComprasChanged)
    def historial_compras(self):
        """Historial de compras del proveedor actual"""
        return self._historial_compras
    
    @Property('QVariant', notify=estadisticasChanged)
    def estadisticas(self):
        """Estadísticas del proveedor actual"""
        return self._estadisticas
    
    @Property('QVariant', notify=resumenChanged)
    def resumen(self):
        """Resumen estadístico de todos los proveedores"""
        return self._resumen
    
    @Property(list, notify=searchResultsChanged)
    def search_results(self):
        """Resultados de búsqueda"""
        return self._search_results
    
    @Property(bool, notify=loadingChanged)
    def loading(self):
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=proveedoresChanged)
    def total_proveedores(self):
        """Total de proveedores"""
        return self._total_proveedores
    
    @Property(int, notify=proveedoresChanged)
    def pagina_actual(self):
        """Página actual"""
        return self._pagina_actual
    
    @Property(int, notify=proveedoresChanged)
    def total_paginas(self):
        """Total de páginas"""
        return self._total_paginas
    
    @Property(int, notify=proveedoresChanged)
    def por_pagina(self):
        """Elementos por página"""
        return self._por_pagina
    
    # ===============================
    # SLOTS PARA QML - PAGINACIÓN Y BÚSQUEDA
    # ===============================
    
    @Slot(int)
    def cambiar_pagina(self, nueva_pagina: int):
        """Cambia a una página específica"""
        if nueva_pagina < 1 or nueva_pagina > self._total_paginas:
            return
        
        self._pagina_actual = nueva_pagina
        self._cargar_proveedores()
    
    @Slot()
    def pagina_anterior(self):
        """Va a la página anterior"""
        if self._pagina_actual > 1:
            self.cambiar_pagina(self._pagina_actual - 1)
    
    @Slot()
    def pagina_siguiente(self):
        """Va a la página siguiente"""
        if self._pagina_actual < self._total_paginas:
            self.cambiar_pagina(self._pagina_actual + 1)
    
    @Slot(str)
    def buscar_proveedores(self, termino: str):
        """Busca proveedores con delay para evitar consultas excesivas"""
        self._termino_busqueda = termino.strip()
        self._pagina_actual = 1  # Resetear a primera página
        
        # Cancelar búsqueda anterior y programar nueva
        self.search_timer.stop()
        if len(self._termino_busqueda) >= 2:
            self.search_timer.start(500)  # 500ms delay
        elif len(self._termino_busqueda) == 0:
            self._cargar_proveedores()  # Cargar todos si no hay término
    
    def _ejecutar_busqueda(self):
        """Ejecuta la búsqueda real"""
        self._cargar_proveedores()
    
    @Slot()
    def limpiar_busqueda(self):
        """Limpia la búsqueda y recarga todos los proveedores"""
        self._termino_busqueda = ""
        self._pagina_actual = 1
        self._cargar_proveedores()
    
    @Slot()
    def refresh_proveedores(self):
        """Refresca la lista de proveedores - MEJORADO CON FORCE REFRESH"""
        print("🔄 REFRESH MANUAL de proveedores iniciado...")
        
        try:
            # Force refresh con invalidación completa
            self._cargar_proveedores(force_refresh=True)
            self._cargar_resumen()
            
            # Log detallado
            print(f"📊 Proveedores después de refresh: {len(self._proveedores)}")
            
            # Mensaje de éxito
            self.operacionExitosa.emit(f"Lista actualizada: {len(self._proveedores)} proveedores")
            
        except Exception as e:
            error_msg = f"Error refrescando proveedores: {str(e)}"
            print(f"❌ {error_msg}")
            self.operacionError.emit(error_msg)
    
    # ===============================
    # SLOTS PARA QML - CRUD PROVEEDORES - SIMPLIFICADO
    # ===============================
    
    @Slot(str, str, result=bool)
    def crear_proveedor(self, nombre: str, direccion: str) -> bool:
        """Crea nuevo proveedor - SOLO 2 CAMPOS REQUERIDOS"""
        if not nombre or not nombre.strip():
            self.operacionError.emit("Nombre de proveedor requerido")
            return False
        
        if not direccion or not direccion.strip():
            self.operacionError.emit("Dirección requerida")
            return False
        
        self._set_loading(True)
        
        try:
            proveedor_id = safe_execute(
                self.proveedor_repo.crear_proveedor,
                nombre.strip(),
                direccion.strip()
            )
            
            if proveedor_id:
                # Actualizar datos
                self._cargar_proveedores()
                self._cargar_resumen()
                
                # Emitir signals
                self.proveedorCreado.emit(proveedor_id, nombre.strip())
                self.operacionExitosa.emit(f"Proveedor '{nombre.strip()}' creado exitosamente")
                
                print(f"✅ Proveedor creado - ID: {proveedor_id}, Nombre: {nombre}")
                return True
            else:
                raise ValidationError("proveedor", nombre, "Error creando proveedor")
                
        except Exception as e:
            self.operacionError.emit(f"Error creando proveedor: {str(e)}")
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, str, str, result=bool)
    def actualizar_proveedor(self, proveedor_id: int, nombre: str, direccion: str) -> bool:
        """Actualiza proveedor existente - SOLO 3 CAMPOS"""
        if proveedor_id <= 0:
            self.operacionError.emit("ID de proveedor inválido")
            return False
        
        if not nombre or not nombre.strip():
            self.operacionError.emit("Nombre de proveedor requerido")
            return False
        
        if not direccion or not direccion.strip():
            self.operacionError.emit("Dirección requerida")
            return False
        
        self._set_loading(True)
        
        try:
            datos = {
                'Nombre': nombre.strip(),
                'Direccion': direccion.strip()
            }
            
            exito = safe_execute(
                self.proveedor_repo.actualizar_proveedor,
                proveedor_id,
                datos
            )
            
            if exito:
                # Actualizar datos
                self._cargar_proveedores()
                self._cargar_resumen()
                
                # Actualizar proveedor actual si es el mismo
                if self._proveedor_actual.get('id') == proveedor_id:
                    self.seleccionar_proveedor(proveedor_id)
                
                # Emitir signals
                self.proveedorActualizado.emit(proveedor_id, nombre.strip())
                self.operacionExitosa.emit(f"Proveedor '{nombre.strip()}' actualizado exitosamente")
                
                return True
            else:
                raise ValidationError("proveedor", proveedor_id, "Error actualizando proveedor")
                
        except Exception as e:
            self.operacionError.emit(f"Error actualizando proveedor: {str(e)}")
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, result=bool)
    def eliminar_proveedor(self, proveedor_id: int) -> bool:
        """Elimina proveedor si no tiene compras"""
        if proveedor_id <= 0:
            self.operacionError.emit("ID de proveedor inválido")
            return False
        
        self._set_loading(True)
        
        try:
            # Obtener nombre antes de eliminar
            proveedor = safe_execute(self.proveedor_repo.get_by_id, proveedor_id)
            nombre_proveedor = proveedor['Nombre'] if proveedor else f"ID {proveedor_id}"
            
            exito = safe_execute(self.proveedor_repo.eliminar_proveedor, proveedor_id)
            
            if exito:
                # Actualizar datos
                self._cargar_proveedores()
                self._cargar_resumen()
                
                # Limpiar proveedor actual si es el mismo
                if self._proveedor_actual.get('id') == proveedor_id:
                    self._proveedor_actual = {}
                    self._historial_compras = []
                    self._estadisticas = {}
                    self.proveedorActualChanged.emit()
                    self.historialComprasChanged.emit()
                    self.estadisticasChanged.emit()
                
                # Emitir signals
                self.proveedorEliminado.emit(proveedor_id, nombre_proveedor)
                self.operacionExitosa.emit(f"Proveedor '{nombre_proveedor}' eliminado exitosamente")
                
                return True
            else:
                raise ValidationError("proveedor", proveedor_id, "Error eliminando proveedor")
                
        except Exception as e:
            self.operacionError.emit(f"Error eliminando proveedor: {str(e)}")
            return False
        finally:
            self._set_loading(False)
    
    # ===============================
    # SLOTS PARA QML - CONSULTAS
    # ===============================
    
    @Slot(int)
    def seleccionar_proveedor(self, proveedor_id: int):
        """Selecciona un proveedor y carga sus datos detallados"""
        if proveedor_id <= 0:
            return
        
        self._set_loading(True)
        
        try:
            # Obtener datos del proveedor
            proveedor = safe_execute(self.proveedor_repo.get_by_id, proveedor_id)
            if not proveedor:
                raise ValidationError("proveedor_id", proveedor_id, "Proveedor no encontrado")
            
            # Obtener historial de compras
            historial = safe_execute(self.proveedor_repo.get_historial_compras, proveedor_id, 50)
            
            # Obtener estadísticas
            estadisticas = safe_execute(self.proveedor_repo.get_estadisticas_proveedor, proveedor_id)
            
            # Actualizar datos
            self._proveedor_actual = proveedor
            self._historial_compras = historial or []
            self._estadisticas = estadisticas or {}
            
            # Emitir signals
            self.proveedorActualChanged.emit()
            self.historialComprasChanged.emit()
            self.estadisticasChanged.emit()
            
            print(f"📋 Proveedor seleccionado: {proveedor['Nombre']}")
            
        except Exception as e:
            self.operacionError.emit(f"Error cargando detalles: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot(int, result='QVariant')
    def get_proveedor_detalle(self, proveedor_id: int):
        """Obtiene detalles de un proveedor específico"""
        try:
            proveedor = safe_execute(self.proveedor_repo.get_by_id, proveedor_id)
            return proveedor if proveedor else {}
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo proveedor: {str(e)}")
            return {}
    
    @Slot(str, result=bool)
    def existe_proveedor(self, nombre: str) -> bool:
        """Verifica si existe un proveedor con ese nombre"""
        try:
            return safe_execute(self.proveedor_repo.existe_proveedor, nombre.strip())
        except Exception:
            return False
    
    @Slot(result='QVariant')
    def obtener_todos_nombres(self):
        """Obtiene lista de nombres de todos los proveedores para autocompletado"""
        try:
            proveedores = safe_execute(self.proveedor_repo.get_all)
            return [p['Nombre'] for p in proveedores] if proveedores else []
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo nombres: {str(e)}")
            return []
    
    @Slot(result='QVariant')
    def get_estadisticas_globales(self):
        """Obtiene estadísticas globales de proveedores"""
        try:
            return safe_execute(self.proveedor_repo.get_resumen_todos_proveedores)
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo estadísticas: {str(e)}")
            return {}
    
    @Slot(int, float)
    def _on_proveedor_compra_completada(self, proveedor_id: int, monto_compra: float):
        """Slot que se ejecuta cuando se completa una compra con un proveedor - MEJORADO"""
        print(f"📢 RECIBIDO: Compra completada con proveedor {proveedor_id} por Bs{monto_compra}")
        
        try:
            # 1. Invalidar cache INMEDIATAMENTE
            self._invalidate_complete_cache()
            
            # 2. Force refresh datos CON DELAY para BD
            QTimer.singleShot(0, lambda: self._force_refresh_after_purchase_with_delay(proveedor_id))            
            # 3. Mensaje inmediato
            self.operacionExitosa.emit(f"Proveedor actualizado - Nueva compra: Bs{monto_compra:.2f}")
            
        except Exception as e:
            print(f"❌ Error actualizando proveedor después de compra: {str(e)}")
    
    @Slot()
    def _force_refresh_after_purchase(self):
        """Force refresh después de cualquier compra"""
        print("🔄 FORCE REFRESH de proveedores después de compra")
        
        try:
            # Invalidar todo el cache
            if hasattr(self.proveedor_repo, '_cache_manager'):
                self.proveedor_repo._cache_manager.invalidate_pattern('proveedores*')
                print("🗑️ Cache completo de proveedores invalidado")
            
            # Recargar todo
            self._cargar_proveedores()
            self._cargar_resumen()
            
            # Si hay un proveedor seleccionado, actualizarlo
            if self._proveedor_actual.get('id'):
                proveedor_id = self._proveedor_actual['id']
                self.seleccionar_proveedor(proveedor_id)
                print(f"🔄 Proveedor seleccionado ({proveedor_id}) actualizado")
            
            print("✅ Force refresh de proveedores completado")
            
        except Exception as e:
            print(f"❌ Error en force refresh: {str(e)}")

    @Slot()
    def force_complete_refresh(self):
        """Force refresh completo con log detallado - MEJORADO"""
        print("🔄 FORCE COMPLETE REFRESH - Iniciado por usuario")
        
        try:
            # 1. Invalidar cache AGRESIVAMENTE
            self._invalidate_complete_cache()
            
            # 2. Reset de datos locales
            self._proveedores = []
            self._proveedor_actual = {}
            self._historial_compras = []
            self._estadisticas = {}
            
            # 3. Recargar FORZADAMENTE desde BD
            print("🔄 Recargando datos desde BD...")
            self._cargar_proveedores(force_refresh=True)
            self._cargar_resumen()
            
            # 4. Log resultado detallado
            total_proveedores = len(self._proveedores)
            proveedores_activos = len([p for p in self._proveedores if p.get('Estado') == 'Activo'])
            proveedores_con_compras = len([p for p in self._proveedores if p.get('Total_Compras', 0) > 0])
            
            print(f"✅ REFRESH COMPLETADO:")
            print(f"   Total proveedores: {total_proveedores}")
            print(f"   Proveedores activos: {proveedores_activos}")
            print(f"   Proveedores con compras: {proveedores_con_compras}")
            
            # 5. Emitir mensaje de éxito DETALLADO
            self.operacionExitosa.emit(f"✅ Actualización completa: {total_proveedores} proveedores ({proveedores_activos} activos, {proveedores_con_compras} con compras)")
            
        except Exception as e:
            error_msg = f"Error en actualización completa: {str(e)}"
            print(f"❌ {error_msg}")
            self.operacionError.emit(error_msg)
    @Slot(int, float)
    def _on_compra_created(self, compra_id: int, monto_compra: float):
        """Slot que se ejecuta cuando se crea cualquier compra"""
        print(f"🛒 NUEVA COMPRA DETECTADA: ID {compra_id}, Monto: Bs{monto_compra}")
        
        # Force refresh inmediato
        Qt.callLater(lambda: self._force_refresh_complete_immediate())

    def set_compra_model_reference(self, compra_model):
        """Establece referencia bidireccional con CompraModel - MEJORADO"""
        self._compra_model_ref = compra_model
        
        if compra_model:
            try:
                # Conectar signals de CompraModel - VALIDAR ANTES DE CONECTAR
                if hasattr(compra_model, 'proveedorCompraCompletada'):
                    compra_model.proveedorCompraCompletada.connect(self._on_proveedor_compra_completada)
                    print("🔗 Signal proveedorCompraCompletada conectado")
                
                if hasattr(compra_model, 'proveedorDatosActualizados'):
                    compra_model.proveedorDatosActualizados.connect(self._force_refresh_after_purchase)
                    print("🔗 Signal proveedorDatosActualizados conectado")
                
                if hasattr(compra_model, 'compraCreada'):
                    compra_model.compraCreada.connect(self._on_compra_created)
                    print("🔗 Signal compraCreada conectado")
                
                # Establecer referencia bidireccional
                if hasattr(compra_model, 'set_proveedor_model_reference'):
                    compra_model.set_proveedor_model_reference(self)
                    print("🔗 Referencia bidireccional establecida")
                
                print("✅ ProveedorModel conectado a CompraModel para sync automático")
                
            except Exception as e:
                print(f"❌ Error conectando signals: {str(e)}")
        else:
            print("❌ CompraModel es None, no se pueden establecer conexiones")

    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_proveedores(self, force_refresh=False):
        """Carga proveedores con paginación - MEJORADO CON FORCE REFRESH"""
        try:
            print(f"📋 Cargando proveedores - Página: {self._pagina_actual}, Búsqueda: '{self._termino_busqueda}', Force: {force_refresh}")
            
            # Si es force refresh, invalidar cache antes
            if force_refresh:
                self._invalidate_complete_cache()
            
            resultado = safe_execute(
                self.proveedor_repo.get_proveedores_paginados,
                self._pagina_actual,
                self._por_pagina,
                self._termino_busqueda
            )
            
            if resultado:
                self._proveedores = resultado['data']
                self._total_proveedores = resultado['total']
                self._total_paginas = resultado['paginas']
                
                print(f"✅ Proveedores cargados: {len(self._proveedores)} de {self._total_proveedores}")
                
                # Log detallado de proveedores con compras recientes
                proveedores_activos = [p for p in self._proveedores if p.get('Estado') == 'Activo']
                if proveedores_activos:
                    print("📊 Proveedores ACTIVOS encontrados:")
                    for prov in proveedores_activos:
                        nombre = prov.get('Nombre', 'Sin nombre')
                        compras = prov.get('Total_Compras', 0)
                        monto = prov.get('Monto_Total', 0)
                        ultima = prov.get('Ultima_Compra', 'Sin fecha')
                        print(f"   • {nombre}: {compras} compras, Bs{monto}, última: {ultima}")
                
            else:
                self._proveedores = []
                self._total_proveedores = 0
                self._total_paginas = 0
                print("⚠️ No se obtuvieron proveedores")
            
            self.proveedoresChanged.emit()
            
        except Exception as e:
            print(f"❌ Error cargando proveedores: {e}")
            self._proveedores = []
            self.proveedoresChanged.emit()
    
    def _cargar_resumen(self):
        """Carga resumen estadístico"""
        try:
            resumen = safe_execute(self.proveedor_repo.get_resumen_todos_proveedores)
            self._resumen = resumen or {}
            self.resumenChanged.emit()
            
        except Exception as e:
            print(f"⚠ Error cargando resumen: {e}")
    
    def _auto_update_proveedores(self):
        """Actualización automática de proveedores"""
        if not self._loading:
            try:
                self._cargar_proveedores()
                self._cargar_resumen()
            except Exception as e:
                print(f"⚠ Error en auto-update proveedores: {e}")
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()

    def _invalidate_complete_cache(self):
        """Invalida completamente el cache de proveedores"""
        try:
            if hasattr(self.proveedor_repo, '_cache_manager'):
                # Invalidar TODOS los patrones relacionados
                self.proveedor_repo._cache_manager.invalidate_pattern('proveedores*')
                self.proveedor_repo._cache_manager.invalidate_pattern('compras*')
                self.proveedor_repo._cache_manager.clear()  # Clear completo si es necesario
                print("🗑️ Cache completo de proveedores invalidado")
            
        except Exception as e:
            print(f"❌ Error invalidando cache: {str(e)}")
    def _force_refresh_after_purchase_with_delay(self, proveedor_id: int):
        """Force refresh con delay para dar tiempo a la BD"""
        print(f"🔄 FORCE REFRESH CON DELAY - Proveedor: {proveedor_id}")
        
        try:
            # Esperar un poco más para que la BD se actualice
            QTimer.singleShot(1000, lambda: self._execute_delayed_refresh(proveedor_id))
        
        except Exception as e:
            print(f"❌ Error en refresh con delay: {str(e)}")   

    def _execute_delayed_refresh(self, proveedor_id: int):
        """Ejecuta el refresh real después del delay"""
        try:
            print(f"⏰ Ejecutando refresh delayed para proveedor {proveedor_id}")
            
            # 1. Recargar datos completos
            self._cargar_proveedores()
            self._cargar_resumen()
            
            # 2. Si hay un proveedor seleccionado, actualizarlo
            if self._proveedor_actual.get('id') == proveedor_id:
                self.seleccionar_proveedor(proveedor_id)
                print(f"🔄 Proveedor seleccionado ({proveedor_id}) actualizado")
            
            print("✅ Refresh delayed completado")
            
        except Exception as e:
            print(f"❌ Error en refresh delayed: {str(e)}")
    def _force_refresh_complete_immediate(self):
        """Force refresh completo inmediato"""
        print("🔄 FORCE REFRESH INMEDIATO COMPLETO")
        
        try:
            # 1. Invalidar cache
            self._invalidate_complete_cache()
            
            # 2. Recargar datos
            self._cargar_proveedores()
            self._cargar_resumen()
            
            # 3. Log resultado
            total_proveedores = len(self._proveedores)
            print(f"✅ REFRESH INMEDIATO COMPLETADO: {total_proveedores} proveedores")
            
        except Exception as e:
            print(f"❌ Error en refresh inmediato: {str(e)}")

    def emergency_disconnect(self):
        """Desconexión de emergencia para ProveedorModel"""
        try:
            print("🚨 ProveedorModel: Iniciando desconexión de emergencia...")
            
            # Detener timers
            if hasattr(self, 'search_timer') and self.search_timer.isActive():
                self.search_timer.stop()
                print("   ⏹️ Search timer detenido")
                
            if hasattr(self, 'update_timer') and self.update_timer.isActive():
                self.update_timer.stop()
                print("   ⏹️ Update timer detenido")
            
            # Romper referencia bidireccional
            self._compra_model_ref = None
            
            # Desconectar señales
            signals_to_disconnect = [
                'proveedoresChanged', 'proveedorActualChanged', 'historialComprasChanged',
                'estadisticasChanged', 'resumenChanged', 'proveedorCreado', 'proveedorActualizado',
                'proveedorEliminado', 'operacionExitosa', 'operacionError', 'loadingChanged',
                'searchResultsChanged'
            ]
            
            for signal_name in signals_to_disconnect:
                if hasattr(self, signal_name):
                    try:
                        getattr(self, signal_name).disconnect()
                    except:
                        pass
            
            # Limpiar datos
            self._proveedores = []
            self._proveedor_actual = {}
            self._historial_compras = []
            self._estadisticas = {}
            self._resumen = {}
            self._search_results = []
            
            # Anular repository
            self.proveedor_repo = None
            
            print("✅ ProveedorModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión ProveedorModel: {e}")

# Registrar el tipo para QML
def register_proveedor_model():
    qmlRegisterType(ProveedorModel, "ClinicaModels", 1, 0, "ProveedorModel")