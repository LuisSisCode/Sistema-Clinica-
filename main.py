# main.py - VERSIÃ“N FUSIONADA Y COMPLETA
import sys
import os
import gc
from PySide6.QtCore import QObject, Signal, Slot, QUrl, QTimer, Property, QSettings, QDateTime
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from generar_pdf import GeneradorReportesPDF

# IMPORTAR MODELS QOBJECT
from backend.models.inventario_model import InventarioModel, register_inventario_model
from backend.models.venta_model import VentaModel, register_venta_model
from backend.models.compra_model import CompraModel, register_compra_model
from backend.models.proveedor_model import ProveedorModel, register_proveedor_model
from backend.models.usuario_model import UsuarioModel, register_usuario_model
from backend.models.consulta_model import ConsultaModel, register_consulta_model
from backend.models.gasto_model import GastoModel, register_gasto_model
from backend.models.paciente_model import PacienteModel, register_paciente_model
from backend.models.laboratorio_model import LaboratorioModel, register_laboratorio_model
from backend.models.trabajador_model import TrabajadorModel, register_trabajador_model
from backend.models.enfermeria_model import EnfermeriaModel, register_enfermeria_model
from backend.models.reportes_model import ReportesModel, register_reportes_model
from backend.models.dashboard_model import DashboardModel, register_dashboard_model
from backend.models.ConfiguracionModel.ConfiServiciosbasicos_model import ConfiguracionModel, register_configuracion_model
from backend.models.ConfiguracionModel.ConfiLaboratorio_model import ConfiLaboratorioModel, register_confi_laboratorio_model
from backend.models.ConfiguracionModel.ConfiEnfermeria_model import ConfiEnfermeriaModel, register_confi_enfermeria_model
from backend.models.ConfiguracionModel.ConfiConsulta_model import ConfiConsultaModel, register_confi_consulta_model
from backend.models.ConfiguracionModel.ConfiTrabajadores_model import ConfiTrabajadoresModel, register_confi_trabajadores_model
from backend.models.auth_model import AuthModel, register_auth_model
from backend.models.cierre_caja_model import CierreCajaModel, register_cierre_caja_model
from backend.models.ingreso_extra_model import IngresoExtraModel, register_ingreso_extra_model

from setup_handler import SetupHandler
from backend.core.config_manager import ConfigManager
class NotificationWorker(QObject):
    finished = Signal(str, str)
    
    def __init__(self):
        super().__init__()
    
    @Slot(str, str)
    def process_notification(self, title, message):
        self.finished.emit(title, message)

class AppController(QObject):
    modelsReady = Signal()
    notificationProcessed = Signal(str, str)
    
    def __init__(self):
        super().__init__()
        
        self.notification_worker = NotificationWorker()
        self.notification_worker.finished.connect(self.notificationProcessed)
        
        # INICIALIZAR GENERADOR DE PDF
        self.pdf_generator = GeneradorReportesPDF()
        
        # MODELS QOBJECT - Se inicializarÃ¡n despuÃ©s
        self.inventario_model = None
        self.venta_model = None
        self.compra_model = None
        self.proveedor_model = None
        self.consulta_model = None
        self.paciente_model = None
        self.usuario_model = None
        self.gasto_model = None
        self.laboratorio_model = None
        self.trabajador_model = None
        self.enfermeria_model = None
        self.configuracion_model = None
        self.confi_laboratorio_model = None
        self.confi_enfermeria_model = None
        self.confi_consulta_model = None
        self.confi_trabajadores_model = None
        self.reportes_model = None
        self.dashboard_model = None
        self.auth_model = None
        self.cierre_caja_model = None
        self.ingreso_extra_model = None
        
        # Usuario autenticado - SIMPLIFICADO
        self._usuario_autenticado_id = 0
        self._usuario_autenticado_nombre = ""
        self._usuario_autenticado_rol = ""
        self._is_shutting_down = False

    # Propiedades para usuario autenticado
    usuarioChanged = Signal()

    @Property(int, notify=usuarioChanged)
    def usuario_actual_id(self):
        return self._usuario_autenticado_id

    @Property(str, notify=usuarioChanged) 
    def usuario_actual_rol(self):
        return self._usuario_autenticado_rol

    @Slot()
    def initialize_models(self):
        """Inicializa todos los models QObject"""
        try:
            print("ðŸ—‚ï¸ Creando instancias de modelos...")
            
            # Crear instancias de models
            self.auth_model = AuthModel() 
            self.inventario_model = InventarioModel()
            self.venta_model = VentaModel()
            self.compra_model = CompraModel()
            self.proveedor_model = ProveedorModel()
            self.consulta_model = ConsultaModel()
            self.paciente_model = PacienteModel()
            self.usuario_model = UsuarioModel()
            self.gasto_model = GastoModel()
            self.laboratorio_model = LaboratorioModel()
            self.trabajador_model = TrabajadorModel()
            self.enfermeria_model = EnfermeriaModel()
            self.configuracion_model = ConfiguracionModel()
            self.confi_laboratorio_model = ConfiLaboratorioModel()
            self.confi_enfermeria_model = ConfiEnfermeriaModel()
            self.confi_consulta_model = ConfiConsultaModel()
            self.confi_trabajadores_model = ConfiTrabajadoresModel()
            self.reportes_model = ReportesModel()
            self.dashboard_model = DashboardModel()
            self.venta_model.stockModificado.connect(self.inventario_model.actualizar_por_venta)
            self.cierre_caja_model = CierreCajaModel()
            self.ingreso_extra_model = IngresoExtraModel()


            print("ðŸ”— Conectando signals entre modelos...")
            # Conectar signals entre models
            self._connect_models()
            
            print("âœ… Modelos inicializados correctamente")
            self.modelsReady.emit()
            
        except Exception as e:
            print(f"âŒ Error inicializando models: {e}")
            import traceback
            traceback.print_exc()

    @Slot()
    def cleanup(self):
        """Limpia recursos usando el sistema de cleanup gradual"""
        self.gradual_cleanup()

    @Slot()
    def emergency_shutdown(self):
        """
        Sistema de shutdown de emergencia - VERSIÃ“N SEGURA
        NO destruye modelos si estÃ¡n en operaciÃ³n activa
        """
        try:
            print("ðŸ”´ EMERGENCY SHUTDOWN INICIADO")
            
            # âœ… MARCAR QUE ESTAMOS EN SHUTDOWN INMEDIATAMENTE
            self._is_shutting_down = True
            
            # âœ… VALIDAR QUE NO HAY OPERACIONES ACTIVAS
            if self._hay_operaciones_activas():
                print("â¸ï¸ Operaciones activas detectadas - Shutdown pospuesto")
                # Reintentar despuÃ©s de 500ms
                QTimer.singleShot(500, self.emergency_shutdown)
                return
            
            print("âœ… No hay operaciones activas - Procediendo con shutdown")
            
            # FASE 1: DETENER TODOS LOS TIMERS INMEDIATAMENTE
            self._stop_all_timers_immediately()
            
            # FASE 2: DESCONECTAR SEÃ‘ALES ORDENADAMENTE  
            self._disconnect_all_signals_ordered()
            
            # FASE 3: LIMPIEZA SINCRONIZADA DE RECURSOS
            self._cleanup_resources_synchronously()
            
            print("âœ… EMERGENCY SHUTDOWN COMPLETADO")
            
        except Exception as e:
            print(f"âš ï¸ Error en emergency shutdown: {e}")
            # Forzar limpieza bÃ¡sica aunque falle
            self._force_basic_cleanup()
    def _hay_operaciones_activas(self) -> bool:
        """âœ… NUEVO: Verifica si hay operaciones activas en algÃºn modelo"""
        try:
            # Lista de modelos a verificar
            models_to_check = [
                self.cierre_caja_model,
                self.venta_model,
                self.compra_model,
                self.inventario_model,
                self.consulta_model,
                self.laboratorio_model,
                self.enfermeria_model,
                self.gasto_model
            ]
            
            for model in models_to_check:
                if model:
                    # Verificar si tiene flag de loading activo
                    if hasattr(model, '_loading') and model._loading:
                        print(f"âš ï¸ {type(model).__name__} estÃ¡ en operaciÃ³n")
                        return True
                    
                    # Verificar si tiene lock activo
                    if hasattr(model, '_operation_lock') and model._operation_lock:
                        print(f"âš ï¸ {type(model).__name__} tiene lock activo")
                        return True
            
            return False
            
        except Exception as e:
            print(f"âš ï¸ Error verificando operaciones activas: {e}")
            # En caso de error, asumir que NO hay operaciones (mÃ¡s seguro)
            return False
    def _stop_all_timers_immediately(self):
        """FASE 1: Detiene TODOS los timers sin excepciÃ³n"""
        try:
            print("â¹ï¸ FASE 1: Deteniendo todos los timers...")
            
            # Lista de todos los modelos
            models = [
                self.inventario_model, self.venta_model, self.compra_model,
                self.proveedor_model, self.consulta_model, self.paciente_model,
                self.usuario_model, self.gasto_model, self.laboratorio_model,
                self.trabajador_model, self.enfermeria_model, self.configuracion_model,
                self.confi_laboratorio_model, self.confi_enfermeria_model,
                self.confi_consulta_model, self.confi_trabajadores_model,
                self.reportes_model, self.dashboard_model, self.auth_model,
                self.cierre_caja_model, self.ingreso_extra_model
            ]
            
            timer_count = 0
            
            for model in models:
                if model:
                    try:
                        # Buscar y detener timers por nombres conocidos
                        timer_names = [
                            '_refresh_timer', 'update_timer', '_autoRefreshTimer', 
                            'search_timer', '_timer', 'refresh_timer', 'auto_timer',
                            'notification_timer', '_update_timer'
                        ]
                        
                        for timer_name in timer_names:
                            if hasattr(model, timer_name):
                                timer = getattr(model, timer_name)
                                if timer and hasattr(timer, 'isActive') and timer.isActive():
                                    timer.stop()
                                    timer_count += 1
                                    print(f"   â¹ï¸ Timer detenido: {type(model).__name__}.{timer_name}")
                        
                        # Buscar timers por inspecciÃ³n de atributos
                        for attr_name in dir(model):
                            if not attr_name.startswith('__'):
                                try:
                                    attr = getattr(model, attr_name)
                                    if (hasattr(attr, 'isActive') and 
                                        hasattr(attr, 'stop') and 
                                        callable(getattr(attr, 'stop')) and
                                        attr.isActive()):
                                        attr.stop()
                                        timer_count += 1
                                        print(f"   â¹ï¸ Timer detectado detenido: {type(model).__name__}.{attr_name}")
                                except:
                                    pass
                                    
                    except Exception as e:
                        print(f"âš ï¸ Error deteniendo timers en {type(model).__name__}: {e}")
            
            print(f"âœ… FASE 1 COMPLETA: {timer_count} timers detenidos")
            
        except Exception as e:
            print(f"âŒ Error en FASE 1: {e}")

    def _disconnect_all_signals_ordered(self):
        """FASE 2: Desconecta seÃ±ales en orden especÃ­fico"""
        try:
            print("ðŸ”Œ FASE 2: Desconectando seÃ±ales...")
            
            # 2.1: Desconectar seÃ±ales globales primero
            try:
                # Intentar desconectar seÃ±ales globales si existen
                app = QGuiApplication.instance()
                if app:
                    # Desconectar todas las seÃ±ales de la aplicaciÃ³n
                    for signal_name in dir(app):
                        if not signal_name.startswith('__'):
                            try:
                                signal = getattr(app, signal_name)
                                if hasattr(signal, 'disconnect'):
                                    signal.disconnect()
                            except:
                                pass
                    print("   ðŸ”Œ SeÃ±ales globales desconectadas")
            except Exception as e:
                print(f"   âš ï¸ Error desconectando seÃ±ales globales: {e}")
            
            # 2.2: Desconectar referencias bidireccionales
            try:
                if self.compra_model and self.proveedor_model:
                    # Romper referencia bidireccional
                    if hasattr(self.compra_model, '_proveedor_model_ref'):
                        self.compra_model._proveedor_model_ref = None
                    if hasattr(self.proveedor_model, '_compra_model_ref'):
                        self.proveedor_model._compra_model_ref = None
                    print("   ðŸ”Œ Referencias bidireccionales rotas")
            except Exception as e:
                print(f"   âš ï¸ Error rompiendo referencias: {e}")
            
            # 2.3: Desconectar seÃ±ales internas de cada modelo
            models = [
                self.inventario_model, self.venta_model, self.compra_model,
                self.proveedor_model, self.consulta_model, self.paciente_model,
                self.usuario_model, self.gasto_model, self.laboratorio_model,
                self.trabajador_model, self.enfermeria_model, self.configuracion_model,
                self.confi_laboratorio_model, self.confi_enfermeria_model,
                self.confi_consulta_model, self.confi_trabajadores_model,
                self.reportes_model, self.dashboard_model, self.auth_model,
                self.cierre_caja_model, self.ingreso_extra_model
            ]
            
            for model in models:
                if model:
                    try:
                        # Llamar mÃ©todo cleanup especÃ­fico si existe
                        if hasattr(model, 'emergency_disconnect'):
                            model.emergency_disconnect()
                        elif hasattr(model, 'cleanup'):
                            model.cleanup()
                    except Exception as e:
                        print(f"   âš ï¸ Error cleanup {type(model).__name__}: {e}")
            
            print("âœ… FASE 2 COMPLETA: SeÃ±ales desconectadas")
            
        except Exception as e:
            print(f"âŒ Error en FASE 2: {e}")

    def _cleanup_resources_synchronously(self):
        """FASE 3: Limpieza sincronizada de recursos"""
        try:
            print("ðŸ§¹ FASE 3: Limpieza sincronizada...")
            
            # 3.1: Invalidar todos los caches
            models_with_repos = [
                self.inventario_model, self.venta_model, self.compra_model,
                self.proveedor_model, self.consulta_model, self.gasto_model,
                self.laboratorio_model, self.trabajador_model, self.enfermeria_model
                , self.ingreso_extra_model
            ]
            
            for model in models_with_repos:
                if model and hasattr(model, 'repository'):
                    try:
                        repo = model.repository
                        if hasattr(repo, '_cache_manager'):
                            repo._cache_manager.clear()
                        if hasattr(repo, 'invalidate_all_caches'):
                            repo.invalidate_all_caches()
                    except Exception as e:
                        print(f"   âš ï¸ Error limpiando cache {type(model).__name__}: {e}")
            
            # 3.2: Establecer estados de shutdown
            all_models = [
                self.inventario_model, self.venta_model, self.compra_model,
                self.proveedor_model, self.consulta_model, self.paciente_model,
                self.usuario_model, self.gasto_model, self.laboratorio_model,
                self.trabajador_model, self.enfermeria_model, self.configuracion_model,
                self.confi_laboratorio_model, self.confi_enfermeria_model,
                self.confi_consulta_model, self.confi_trabajadores_model,
                self.reportes_model, self.dashboard_model, self.auth_model,
                self.cierre_caja_model, self.ingreso_extra_model
            ]
            
            for model in all_models:
                if model:
                    try:
                        # Establecer estado shutdown
                        if hasattr(model, '_estadoActual'):
                            model._estadoActual = "shutdown"
                        if hasattr(model, '_loading'):
                            model._loading = False
                        # âœ… RESETEAR USUARIO EN TODOS LOS MODELOS
                        if hasattr(model, '_usuario_actual_id'):
                            model._usuario_actual_id = 0
                        # Limpiar datos en memoria
                        self._clear_model_data(model)
                    except Exception as e:
                        print(f"   âš ï¸ Error estableciendo shutdown {type(model).__name__}: {e}")
            
            # 3.3: Usar destroy() en lugar de deleteLater()
            for model in all_models:
                if model:
                    try:
                        # Disconnect all signals before destroying
                        model.blockSignals(True)
                        # Forzar destrucciÃ³n inmediata
                        model.setParent(None)
                    except Exception as e:
                        print(f"   âš ï¸ Error destruyendo {type(model).__name__}: {e}")
            
            # 3.4: Limpiar referencias
            self.inventario_model = None
            self.venta_model = None
            self.compra_model = None
            self.proveedor_model = None
            self.consulta_model = None
            self.paciente_model = None
            self.usuario_model = None
            self.gasto_model = None
            self.laboratorio_model = None
            self.trabajador_model = None
            self.enfermeria_model = None
            self.configuracion_model = None
            self.confi_laboratorio_model = None
            self.confi_enfermeria_model = None
            self.confi_consulta_model = None
            self.confi_trabajadores_model = None
            self.reportes_model = None
            self.dashboard_model = None
            self.auth_model = None
            self.cierre_caja_model = None
            
            # âœ… RESETEAR USUARIO AUTENTICADO
            self._usuario_autenticado_id = 0
            self._usuario_autenticado_nombre = ""
            self._usuario_autenticado_rol = ""
            
            print("âœ… FASE 3 COMPLETA: Recursos limpiados")
            
        except Exception as e:
            print(f"âŒ Error en FASE 3: {e}")

    def _force_basic_cleanup(self):
        """Limpieza bÃ¡sica de emergencia si falla el shutdown normal"""
        try:
            print("ðŸ†˜ FORZANDO LIMPIEZA BÃSICA...")
            
            # Forzar parada de todos los QTimer activos
            # No hay una forma directa de obtener todos los QTimer, 
            # pero podemos forzar garbage collection
            gc.collect()
            
            # Establecer todas las referencias a None
            for attr_name in dir(self):
                if attr_name.endswith('_model') and not attr_name.startswith('__'):
                    try:
                        setattr(self, attr_name, None)
                    except:
                        pass
            
            print("âœ… Limpieza bÃ¡sica completada")
            
        except Exception as e:
            print(f"âŒ Error en limpieza bÃ¡sica: {e}")

    @Slot()
    def gradual_cleanup(self):
        """Sistema de cleanup gradual - preserva la estructura para transiciones"""
        try:
            print("ðŸ§¹ CLEANUP GRADUAL INICIADO")
            
            # RESETEAR USUARIO AUTENTICADO INMEDIATAMENTE
            self._usuario_autenticado_id = 0
            self._usuario_autenticado_nombre = ""
            self._usuario_autenticado_rol = ""
            self.usuarioChanged.emit()
            
            # LIMPIAR DATOS EN MEMORIA SIN DESTRUIR OBJETOS
            self._clear_model_data_only()
            
            print("âœ… CLEANUP GRADUAL COMPLETADO")
            
        except Exception as e:
            print(f"âš ï¸ Error en cleanup gradual: {e}")

    def _clear_model_data_only(self):
        """Limpia datos sin destruir objetos"""
        try:
            print("ðŸ§¹ Limpiando datos...")
            
            all_models = [
                self.inventario_model, self.venta_model, self.compra_model,
                self.proveedor_model, self.consulta_model, self.paciente_model,
                self.usuario_model, self.gasto_model, self.laboratorio_model,
                self.trabajador_model, self.enfermeria_model, self.configuracion_model,
                self.confi_laboratorio_model, self.confi_enfermeria_model,
                self.confi_consulta_model, self.confi_trabajadores_model,
                self.reportes_model, self.dashboard_model,
                self.cierre_caja_model, self.ingreso_extra_model
            ]
            
            for model in all_models:
                if model:
                    try:
                        # Establecer estado shutdown sin destruir
                        if hasattr(model, '_usuario_actual_id'):
                            model._usuario_actual_id = 0
                        if hasattr(model, '_usuario_actual_rol'):
                            model._usuario_actual_rol = ""
                        
                        # Limpiar datos en memoria
                        self._clear_model_data(model)
                        
                    except Exception as e:
                        print(f"âš ï¸ Error limpiando datos {type(model).__name__}: {e}")
            
            print("âœ… Datos limpiados")
            
        except Exception as e:
            print(f"âŒ Error en limpieza de datos: {e}")

    def _clear_model_data(self, model):
        """Limpia datos especÃ­ficos de un modelo"""
        try:
            # Limpiar listas comunes
            data_attrs = [
                '_consultasData', '_procedimientosData', '_examenesData',
                '_trabajadoresData', '_proveedores', '_pacientes', '_usuarios',
                '_gastos', '_ventas', '_compras', '_productos'
            ]
            
            for attr_name in data_attrs:
                if hasattr(model, attr_name):
                    setattr(model, attr_name, [])
            
            # Limpiar diccionarios comunes
            dict_attrs = [
                '_dashboardData', '_estadisticas', '_resumen', '_filtros'
            ]
            
            for attr_name in dict_attrs:
                if hasattr(model, attr_name):
                    setattr(model, attr_name, {})
                    
        except Exception as e:
            print(f"   âš ï¸ Error limpiando datos de modelo: {e}")

    def _connect_models(self):
        """Conecta signals entre models para sincronizaciÃ³n - VERSIÃ“N CORREGIDA"""
        try:
            print("ðŸ”— Configurando conexiones entre modelos...")
            
            # ===== CONEXIONES BÃSICAS =====
            if self.venta_model:
                self.venta_model.ventaCreada.connect(self._on_venta_creada)
                print("   âœ… VERIFICADO: Ventas â†’ Cierre de Caja conectado")
                
            if self.compra_model:
                self.compra_model.compraCreada.connect(self._on_compra_creada)
            
            # ===== CONEXIONES ESPECÃFICAS PARA CIERRE DE CAJA =====
            if self.cierre_caja_model:
                # Solo establecer referencia para PDFs
                self.cierre_caja_model.set_app_controller(self)
                print("   âœ… AppController conectado al CierreCajaModel para PDFs")
            if self.ingreso_extra_model:
                if hasattr(self.ingreso_extra_model, 'errorOcurrido'):
                    self.ingreso_extra_model.errorOcurrido.connect(self._on_model_error)
                print("   âœ… IngresoExtraModel conectado")
            # ===== CONEXIONES DE ERRORES Y Ã‰XITOS - VERSIÃ“N SEGURA =====
            models_with_errors = [
                self.inventario_model, self.venta_model, self.compra_model,
                self.proveedor_model, self.usuario_model, self.gasto_model,
                self.consulta_model, self.paciente_model, self.laboratorio_model,
                self.trabajador_model, self.enfermeria_model, self.configuracion_model,
                self.confi_laboratorio_model, self.confi_enfermeria_model,
                self.confi_consulta_model, self.confi_trabajadores_model, 
                self.cierre_caja_model, self.ingreso_extra_model
            ]

            for model in models_with_errors:
                if model:
                    try:
                        # âœ… CONECTAR SEÃ‘ALES CON TRY-CATCH
                        if hasattr(model, 'operacionError'):
                            model.operacionError.connect(self._on_model_error)
                        if hasattr(model, 'errorOccurred'):
                            model.errorOccurred.connect(self._on_model_error)
                        if hasattr(model, 'operacionExitosa'):
                            model.operacionExitosa.connect(self._on_model_success)
                        if hasattr(model, 'successMessage'):
                            model.successMessage.connect(self._on_model_success)
                    except Exception as e:
                        print(f"âš ï¸ Error conectando seÃ±ales de {type(model).__name__}: {e}")
            
            for model in models_with_errors:
                if model:
                    if hasattr(model, 'operacionError'):
                        model.operacionError.connect(self._on_model_error)
                    if hasattr(model, 'errorOccurred'):
                        model.errorOccurred.connect(self._on_model_error)
                    if hasattr(model, 'operacionExitosa'):
                        model.operacionExitosa.connect(self._on_model_success)
                    if hasattr(model, 'successMessage'):
                        model.successMessage.connect(self._on_model_success)

            # ===== CONEXIONES ESPECÃFICAS PARA MODELOS =====
            if self.proveedor_model:
                self.proveedor_model.proveedorCreado.connect(self._on_proveedor_creado)
                self.proveedor_model.proveedorActualizado.connect(self._on_proveedor_actualizado)
                self.proveedor_model.proveedorEliminado.connect(self._on_proveedor_eliminado)
                
            if self.trabajador_model:
                self.trabajador_model.trabajadorCreado.connect(self._on_trabajador_creado)
                self.trabajador_model.trabajadorActualizado.connect(self._on_trabajador_actualizado)
                self.trabajador_model.trabajadorEliminado.connect(self._on_trabajador_eliminado)
                
            if self.gasto_model:
                self.gasto_model.gastoCreado.connect(self._on_gasto_creado)
                self.gasto_model.gastoActualizado.connect(self._on_gasto_actualizado)
                self.gasto_model.gastoEliminado.connect(self._on_gasto_eliminado)
                
            if self.enfermeria_model:
                self.enfermeria_model.procedimientoCreado.connect(self._on_procedimiento_creado)
                self.enfermeria_model.procedimientoActualizado.connect(self._on_procedimiento_actualizado)
                self.enfermeria_model.procedimientoEliminado.connect(self._on_procedimiento_eliminado)
                
            if self.configuracion_model:
                self.configuracion_model.tipoGastoCreado.connect(self._on_tipo_gasto_creado)
                self.configuracion_model.tipoGastoActualizado.connect(self._on_tipo_gasto_actualizado)
                self.configuracion_model.tipoGastoEliminado.connect(self._on_tipo_gasto_eliminado)
                
            if self.confi_laboratorio_model:
                self.confi_laboratorio_model.tipoAnalisisCreado.connect(self._on_tipo_analisis_creado)
                self.confi_laboratorio_model.tipoAnalisisActualizado.connect(self._on_tipo_analisis_actualizado)
                self.confi_laboratorio_model.tipoAnalisisEliminado.connect(self._on_tipo_analisis_eliminado)
                
            if self.confi_enfermeria_model:
                self.confi_enfermeria_model.tipoProcedimientoCreado.connect(self._on_tipo_procedimiento_creado)
                self.confi_enfermeria_model.tipoProcedimientoActualizado.connect(self._on_tipo_procedimiento_actualizado)
                self.confi_enfermeria_model.tipoProcedimientoEliminado.connect(self._on_tipo_procedimiento_eliminado)
                
            if self.confi_consulta_model:
                self.confi_consulta_model.especialidadCreada.connect(self._on_especialidad_creada)
                self.confi_consulta_model.especialidadActualizada.connect(self._on_especialidad_actualizada)
                self.confi_consulta_model.especialidadEliminada.connect(self._on_especialidad_eliminada)
                
            if self.confi_trabajadores_model:
                self.confi_trabajadores_model.tipoTrabajadorCreado.connect(self._on_tipo_trabajador_creado)
                self.confi_trabajadores_model.tipoTrabajadorActualizado.connect(self._on_tipo_trabajador_actualizado)
                self.confi_trabajadores_model.tipoTrabajadorEliminado.connect(self._on_tipo_trabajador_eliminado)
                
            if self.reportes_model:
                self.reportes_model.reporteError.connect(self._on_model_error)
                self.reportes_model.reporteGenerado.connect(self._on_reporte_generado)
                self.reportes_model.set_app_controller(self)

            if self.cierre_caja_model:
                # Solo establecer referencia para PDFs
                self.cierre_caja_model.set_app_controller(self)
                print("   âœ… AppController conectado al CierreCajaModel para PDFs")

        except Exception as e:
            print(f"âŒ Error conectando models: {e}")
            import traceback
            traceback.print_exc()

    @Slot(int, str, str)
    def set_usuario_autenticado(self, usuario_id: int, usuario_nombre: str, usuario_rol: str):
        
        
        # Establecer usuario inmediatamente
        self._usuario_autenticado_id = usuario_id
        self._usuario_autenticado_nombre = usuario_nombre
        self._usuario_autenticado_rol = usuario_rol
        
        # Emitir seÃ±al de cambio
        self.usuarioChanged.emit()
        
        # Establecer usuario en todos los modelos
        self._establecer_usuario_en_modelos()
        
        print(f"âœ… Usuario autenticado establecido correctamente")

    def _establecer_usuario_en_modelos(self):
        """Establece el usuario autenticado en todos los modelos que lo necesiten"""
        if self._usuario_autenticado_id > 0:
            print(f"ðŸ‘¤ Estableciendo usuario {self._usuario_autenticado_id} en modelos...")
            
            # Lista de modelos y sus mÃ©todos de autenticaciÃ³n
            models_to_set = [
                (self.usuario_model, 'set_usuario_actual_con_rol'),
                (self.venta_model, 'set_usuario_actual_con_rol'),
                (self.compra_model, 'set_usuario_actual'),
                (self.proveedor_model, 'set_usuario_actual_con_rol'),  
                (self.consulta_model, 'set_usuario_actual_con_rol'),
                (self.enfermeria_model, 'set_usuario_actual_con_rol'),
                (self.laboratorio_model, 'set_usuario_actual_con_rol'),
                (self.gasto_model, 'set_usuario_actual_con_rol'),
                (self.trabajador_model, 'set_usuario_actual_con_rol'),  
                (self.reportes_model, 'set_usuario_actual'),
                (self.dashboard_model, 'set_usuario_actual_con_rol'),
                (self.cierre_caja_model, 'set_usuario_actual_con_rol'),
                (self.ingreso_extra_model, 'set_usuario_actual_con_rol'),
            ]
            
            # Establecer usuario en cada modelo
            for model, method_name in models_to_set:
                if model and hasattr(model, method_name):
                    try:
                        if method_name == 'set_usuario_actual_con_rol':
                            getattr(model, method_name)(self._usuario_autenticado_id, self._usuario_autenticado_rol)
                            print(f"  âœ… Usuario establecido en {type(model).__name__} con rol")
                        else:
                            getattr(model, method_name)(self._usuario_autenticado_id)
                            print(f"  âœ… Usuario establecido en {type(model).__name__}")
                    except Exception as e:
                        print(f"  âŒ Error estableciendo usuario en {type(model).__name__}: {e}")

    # Handlers para eventos especÃ­ficos de modelos
    @Slot(int, float)
    def _on_venta_creada(self, venta_id: int, total: float):
        """Handler SIMPLIFICADO para ventas creadas"""
        try:
            print(f"ðŸ›’ Venta creada - ID: {venta_id}, Total: Bs {total:,.2f}")
            
            # Actualizar inventario Ãºnicamente
            if self.inventario_model:
                QTimer.singleShot(1000, self.inventario_model.refresh_productos)
                
        except Exception as e:
            print(f"âŒ Error procesando venta creada: {e}")

    @Slot(int, float)
    def _on_compra_creada(self, compra_id: int, total: float):
        """Handler SIMPLIFICADO para compras creadas"""
        try:
            print(f"ðŸ›ï¸ Compra creada - ID: {compra_id}, Total: Bs {total:,.2f}")
            
            # Actualizar inventario Ãºnicamente
            if self.inventario_model:
                QTimer.singleShot(1000, self.inventario_model.refresh_productos)
                
        except Exception as e:
            print(f"âŒ Error procesando compra creada: {e}")
    @Slot(int, str)
    def _on_proveedor_creado(self, proveedor_id: int, nombre: str):
        self.showNotification("Proveedor Creado", f"Proveedor '{nombre}' agregado exitosamente")

    @Slot(int, str)
    def _on_proveedor_actualizado(self, proveedor_id: int, nombre: str):
        self.showNotification("Proveedor Actualizado", f"Proveedor '{nombre}' actualizado exitosamente")

    @Slot(int, str)
    def _on_proveedor_eliminado(self, proveedor_id: int, nombre: str):
        self.showNotification("Proveedor Eliminado", f"Proveedor '{nombre}' eliminado exitosamente")

    @Slot(bool, str, int)
    def _on_reporte_generado(self, success: bool, message: str, total_registros: int):
        if success:
            self.showNotification("Reporte Generado", message)
        else:
            self.showNotification("Error en Reporte", message)

    @Slot(int, float)
    def _on_transaccion_financiera(self, transaccion_id: int, monto: float):
        """Handler genÃ©rico para transacciones financieras - MEJORADO"""
        try:
            if self.cierre_caja_model:
                print(f"ðŸ’° TransacciÃ³n registrada - ID: {transaccion_id}, Monto: {monto}")
                
                # Refresh inmediato sin delay
                self.cierre_caja_model.repository.refresh_cache_immediately()
                # Delay mÃ­nimo para que la BD se actualice
                QTimer.singleShot(200, lambda: self._refresh_cierre_caja("TransacciÃ³n general"))
        except Exception as e:
            print(f"âŒ Error procesando transacciÃ³n: {e}")

    def _refresh_cierre_directo(self, tipo_transaccion: str, transaccion_id: int, monto: float):
        """
        MÃ©todo UNIFICADO de refresh directo - USA LA LÃ“GICA QUE FUNCIONA
        """
        try:
            # 1. Invalidar cachÃ© inmediatamente
            self.repository.invalidar_cache_transaccion()
            
            # 2. Log de la transacciÃ³n (sin polling complejo)
            if hasattr(self.repository, 'notificar_transaccion_nueva'):
                self.repository.notificar_transaccion_nueva(tipo_transaccion, monto, transaccion_id)
            
            # 3. Refresh inmediato usando el mÃ©todo que funciona
            self.repository.refresh_cache_immediately()
            
            # 4. Forzar actualizaciÃ³n del modelo
            self._cargar_datos_dia()
            
            print(f"âœ… Cierre de caja actualizado por {tipo_transaccion} {transaccion_id}")
            
        except Exception as e:
            print(f"âŒ Error en refresh directo: {e}")
            # Fallback: al menos invalidar y recargar bÃ¡sico
            try:
                self.repository.invalidar_cache_completo()
                self._cargar_datos_dia()
            except:
                pass

    @Slot(str)
    def _refresh_cierre_caja(self, mensaje: str = ""):
        """Refresca los datos del cierre de caja - MÃ‰TODO MEJORADO"""
        try:
            if self.cierre_caja_model:
                print(f"ðŸ”„ Refrescando datos de Cierre de Caja... ({mensaje})")
                
                # 1. Invalidar cachÃ© inmediatamente
                if hasattr(self.cierre_caja_model.repository, 'refresh_cache_immediately'):
                    self.cierre_caja_model.repository.refresh_cache_immediately()
                
                # 2. Forzar actualizaciÃ³n del modelo
                self.cierre_caja_model.forzarActualizacion()
                
                print(f"âœ… Cierre de caja actualizado: {mensaje}")
                
        except Exception as e:
            print(f"âŒ Error refrescando cierre de caja: {e}")

    @Slot(bool, str)
    def _on_gasto_creado(self, success: bool, message: str):
        if success:
            self.showNotification("Gasto Creado", message)

    @Slot(bool, str)
    def _on_gasto_actualizado(self, success: bool, message: str):
        if success:
            self.showNotification("Gasto Actualizado", message)

    @Slot(bool, str)
    def _on_gasto_eliminado(self, success: bool, message: str):
        if success:
            self.showNotification("Gasto Eliminado", message)

    @Slot(bool, str)
    def _on_trabajador_creado(self, success: bool, message: str):
        if success:
            self.showNotification("Trabajador Creado", message)

    @Slot(bool, str)
    def _on_trabajador_actualizado(self, success: bool, message: str):
        if success:
            self.showNotification("Trabajador Actualizado", message)

    @Slot(bool, str)
    def _on_trabajador_eliminado(self, success: bool, message: str):
        if success:
            self.showNotification("Trabajador Eliminado", message)

    @Slot(str)
    def _on_procedimiento_creado(self, message: str):
        """Handler para procedimiento creado - Solo recibe mensaje JSON"""
        try:
            import json
            data = json.loads(message)
            if data.get('exito', False):
                self.showNotification("Procedimiento Creado", "Procedimiento creado exitosamente")
        except Exception as e:
            print(f"Error en handler procedimiento creado: {e}")

    @Slot(str)
    def _on_procedimiento_actualizado(self, message: str):
        """Handler para procedimiento actualizado - Solo recibe mensaje JSON"""
        try:
            import json
            data = json.loads(message)
            if data.get('exito', False):
                self.showNotification("Procedimiento Actualizado", "Procedimiento actualizado exitosamente")
        except Exception as e:
            print(f"Error en handler procedimiento actualizado: {e}")

    @Slot(str)
    def _on_procedimiento_eliminado(self, message: str):
        """Handler para procedimiento eliminado - Solo recibe mensaje JSON"""
        try:
            import json
            data = json.loads(message)
            if data.get('exito', False):
                self.showNotification("Procedimiento Eliminado", "Procedimiento eliminado exitosamente")
        except Exception as e:
            print(f"Error en handler procedimiento eliminado: {e}")

    @Slot(bool, str)
    def _on_tipo_gasto_creado(self, success: bool, message: str):
        if success:
            self.showNotification("Tipo Creado", message)

    @Slot(bool, str)
    def _on_tipo_gasto_actualizado(self, success: bool, message: str):
        if success:
            self.showNotification("Tipo Actualizado", message)

    @Slot(bool, str)
    def _on_tipo_gasto_eliminado(self, success: bool, message: str):
        if success:
            self.showNotification("Tipo Eliminado", message)

    @Slot(bool, str)
    def _on_tipo_analisis_creado(self, success: bool, message: str):
        if success:
            self.showNotification("AnÃ¡lisis Creado", message)

    @Slot(bool, str)
    def _on_tipo_analisis_actualizado(self, success: bool, message: str):
        if success:
            self.showNotification("AnÃ¡lisis Actualizado", message)

    @Slot(bool, str)
    def _on_tipo_analisis_eliminado(self, success: bool, message: str):
        if success:
            self.showNotification("AnÃ¡lisis Eliminado", message)

    @Slot(bool, str)
    def _on_tipo_procedimiento_creado(self, success: bool, message: str):
        if success:
            self.showNotification("Procedimiento Creado", message)

    @Slot(bool, str)
    def _on_tipo_procedimiento_actualizado(self, success: bool, message: str):
        if success:
            self.showNotification("Procedimiento Actualizado", message)

    @Slot(bool, str)
    def _on_tipo_procedimiento_eliminado(self, success: bool, message: str):
        if success:
            self.showNotification("Procedimiento Eliminado", message)

    @Slot(bool, str)
    def _on_especialidad_creada(self, success: bool, message: str):
        if success:
            self.showNotification("Especialidad Creada", message)

    @Slot(bool, str)
    def _on_especialidad_actualizada(self, success: bool, message: str):
        if success:
            self.showNotification("Especialidad Actualizada", message)

    @Slot(bool, str)
    def _on_especialidad_eliminada(self, success: bool, message: str):
        if success:
            self.showNotification("Especialidad Eliminada", message)

    @Slot(bool, str)
    def _on_tipo_trabajador_creado(self, success: bool, message: str):
        if success:
            self.showNotification("Tipo Creado", message)

    @Slot(bool, str)
    def _on_tipo_trabajador_actualizado(self, success: bool, message: str):
        if success:
            self.showNotification("Tipo Actualizado", message)

    @Slot(bool, str)
    def _on_tipo_trabajador_eliminado(self, success: bool, message: str):
        if success:
            self.showNotification("Tipo Eliminado", message)

    @Slot(str)
    def _on_model_error(self, mensaje: str):
        """Handler de errores de modelos - VERSIÃ“N SEGURA"""
        try:
            # âœ… NO PROCESAR DURANTE SHUTDOWN
            if hasattr(self, '_is_shutting_down') and self._is_shutting_down:
                print(f"â¸ï¸ Error de modelo ignorado durante shutdown: {mensaje}")
                return
            
            # âœ… LOG DEL ERROR
            print(f"âŒ Error de modelo: {mensaje}")
            
            # âœ… MOSTRAR NOTIFICACIÃ“N DE FORMA SEGURA
            self.showNotification("Error", mensaje)
            
        except Exception as e:
            print(f"âš ï¸ Error en handler de errores: {e}")

    @Slot(str)
    def _on_model_success(self, mensaje: str):
        """Handler de Ã©xitos de modelos - VERSIÃ“N SEGURA"""
        try:
            # âœ… NO PROCESAR DURANTE SHUTDOWN
            if hasattr(self, '_is_shutting_down') and self._is_shutting_down:
                return
            
            # âœ… LOG OPCIONAL (comentado para no saturar)
            # print(f"âœ… Ã‰xito de modelo: {mensaje}")
            
            # Opcional: mostrar notificaciÃ³n
            # self.showNotification("Ã‰xito", mensaje)
            
        except Exception as e:
            print(f"âš ï¸ Error en handler de Ã©xitos: {e}")

    # ===============================
    # GETTERS PARA MODELS (ACCESO DESDE QML)
    # ===============================
    
    @Property(QObject, notify=modelsReady)
    def inventario_model_instance(self):
        return self.inventario_model
    
    @Property(QObject, notify=modelsReady)
    def venta_model_instance(self):
        return self.venta_model
    
    @Property(QObject, notify=modelsReady)
    def compra_model_instance(self):
        return self.compra_model
    
    @Property(QObject, notify=modelsReady)
    def proveedor_model_instance(self):
        return self.proveedor_model
    
    @Property(QObject, notify=modelsReady)
    def consulta_model_instance(self):
        return self.consulta_model

    @Property(QObject, notify=modelsReady)
    def paciente_model_instance(self):
        return self.paciente_model
    
    @Property(QObject, notify=modelsReady)
    def usuario_model_instance(self):
        return self.usuario_model
    
    @Property(QObject, notify=modelsReady)
    def gasto_model_instance(self):
        return self.gasto_model
    
    @Property(QObject, notify=modelsReady)
    def laboratorio_model_instance(self):
        return self.laboratorio_model

    @Property(QObject, notify=modelsReady)
    def trabajador_model_instance(self):
        return self.trabajador_model
    
    @Property(QObject, notify=modelsReady)
    def enfermeria_model_instance(self):
        return self.enfermeria_model
    
    @Property(QObject, notify=modelsReady)
    def configuracion_model_instance(self):
        return self.configuracion_model
    
    @Property(QObject, notify=modelsReady)
    def confi_trabajadores_model_instance(self):
        return self.confi_trabajadores_model

    @Property(QObject, notify=modelsReady)
    def confi_laboratorio_model_instance(self):
        return self.confi_laboratorio_model
    
    @Property(QObject, notify=modelsReady)
    def confi_enfermeria_model_instance(self):
        return self.confi_enfermeria_model
    
    @Property(QObject, notify=modelsReady)
    def confi_consulta_model_instance(self):
        return self.confi_consulta_model
    
    @Property(QObject, notify=modelsReady)
    def reportes_model_instance(self):
        return self.reportes_model

    @Property(QObject, notify=modelsReady)
    def dashboard_model_instance(self):
        return self.dashboard_model
    
    @Property(QObject, notify=modelsReady)
    def cierre_caja_model_instance(self):
        return self.cierre_caja_model

    @Property(QObject, notify=modelsReady)
    def auth_model_instance(self):
        return self.auth_model
    
    @Property(QObject, notify=modelsReady)
    def ingreso_extra_model_instance(self):
        return self.ingreso_extra_model

    # ===============================
    # MÃ‰TODOS DE NAVEGACIÃ“N Y NOTIFICACIONES
    # ===============================
    
    @Slot(str, str)
    def showNotification(self, title, message):
        """Muestra notificaciÃ³n de forma segura - VERSIÃ“N MEJORADA"""
        try:
            # âœ… VALIDAR QUE NO ESTEMOS EN SHUTDOWN
            if hasattr(self, '_is_shutting_down') and self._is_shutting_down:
                print(f"â¸ï¸ NotificaciÃ³n bloqueada durante shutdown: {title}")
                return
            
            # âœ… VALIDAR QUE notification_worker EXISTA
            if not hasattr(self, 'notification_worker') or not self.notification_worker:
                print(f"âš ï¸ notification_worker no disponible: {title} - {message}")
                return
            
            # âœ… EMITIR DIRECTAMENTE SIN QTimer (mÃ¡s seguro)
            self.notification_worker.process_notification(title, message)
            
        except Exception as e:
            print(f"âš ï¸ Error en showNotification: {e}")
    
    @Slot(str)
    def navigateToModule(self, module_name):
        pass  # ImplementaciÃ³n en QML

    # ===============================
    # MÃ‰TODOS DE GENERACIÃ“N DE PDF (COMPLETOS)
    # ===============================
    
    @Slot(str, result=str)
    def generar_reporte_inventario(self, tipo_reporte: str):
        try:
            if not self.inventario_model:
                return ""
            
            if tipo_reporte == "productos":
                datos = self.inventario_model.productos
            elif tipo_reporte == "vencimientos":
                datos = self.inventario_model.get_reporte_vencimientos()
            elif tipo_reporte == "valor":
                datos = self.inventario_model.get_valor_inventario()
            else:
                datos = []
            
            if not datos:
                return ""
            
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json, 
                tipo_reporte, 
                "", ""
            )
            
        except Exception as e:
            print(f"Error generando reporte inventario: {e}")
            return ""

    @Slot(str, result=str)
    def generar_reporte_ventas(self, periodo: str):
        try:
            if not self.venta_model:
                return ""
            
            if periodo == "hoy":
                datos = self.venta_model.ventas_hoy
            elif periodo == "estadisticas":
                datos = self.venta_model.get_reporte_ingresos()
            elif periodo == "top_productos":
                datos = self.venta_model.get_productos_mas_vendidos(30)
            else:
                datos = []
            
            if not datos:
                return ""
            
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json,
                f"ventas_{periodo}",
                "", ""
            )
            
        except Exception as e:
            print(f"Error generando reporte ventas: {e}")
            return ""

    @Slot(str, result=str)
    def generar_reporte_proveedores(self, tipo_reporte: str):
        try:
            if not self.proveedor_model:
                return ""
            
            datos = []
            
            if tipo_reporte == "todos":
                datos = self.proveedor_model.proveedores
            elif tipo_reporte == "estadisticas":
                datos = self.proveedor_model.resumen
            elif tipo_reporte == "activos":
                datos = [p for p in self.proveedor_model.proveedores if p.get('Estado') == 'Activo']
            elif tipo_reporte == "compras_recientes":
                datos = [p for p in self.proveedor_model.proveedores if p.get('Total_Compras', 0) > 0]
            else:
                return ""
            
            if not datos:
                return ""
            
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json,
                f"proveedores_{tipo_reporte}",
                "", ""
            )
            
        except Exception as e:
            print(f"Error generando reporte de proveedores: {e}")
            return ""

    @Slot(str, result=str)
    def generar_reporte_usuarios(self, tipo_reporte: str):
        try:
            if not self.usuario_model:
                return ""
            
            if tipo_reporte == "todos":
                datos = self.usuario_model.usuarios
            elif tipo_reporte == "estadisticas":
                datos = self.usuario_model.estadisticas
            elif tipo_reporte == "administradores":
                datos = self.usuario_model.obtenerAdministradores()
            elif tipo_reporte == "medicos":
                datos = self.usuario_model.obtenerMedicos()
            else:
                datos = []
            
            if not datos:
                return ""
            
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json,
                f"usuarios_{tipo_reporte}",
                "", ""
            )
            
        except Exception as e:
            print(f"Error generando reporte usuarios: {e}")
            return ""

    @Slot(str, result=str)
    def generar_reporte_trabajadores(self, tipo_reporte: str):
        try:
            if not self.trabajador_model:
                return ""
            
            datos = []
            
            if tipo_reporte == "todos":
                datos = self.trabajador_model.trabajadores
            elif tipo_reporte == "estadisticas":
                datos = self.trabajador_model.estadisticas
            elif tipo_reporte == "tipos":
                datos = self.trabajador_model.tiposTrabajador
            elif tipo_reporte == "laboratorio":
                datos = self.trabajador_model.obtenerTrabajadoresLaboratorio()
            elif tipo_reporte == "enfermeria":
                datos = self.trabajador_model.obtenerTrabajadoresEnfermeria()
            elif tipo_reporte == "administrativos":
                datos = self.trabajador_model.obtenerTrabajadoresAdministrativos()
            elif tipo_reporte == "sin_asignaciones":
                datos = self.trabajador_model.obtenerTrabajadoresSinAsignaciones()
            elif tipo_reporte == "carga_trabajo":
                datos = self.trabajador_model.obtenerDistribucionCarga()
            else:
                return ""
            
            if not datos:
                return ""
            
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json,
                f"trabajadores_{tipo_reporte}",
                "", ""
            )
            
        except Exception as e:
            print(f"Error generando reporte de trabajadores: {e}")
            return ""

    @Slot(str, str, str, result=str)
    def generar_reporte_gastos(self, tipo_reporte: str, fecha_desde: str = "", fecha_hasta: str = ""):
        try:
            if not self.gasto_model:
                return ""
            
            datos = []
            
            if tipo_reporte == "todos":
                datos = self.gasto_model.gastos
            elif tipo_reporte == "estadisticas":
                datos = self.gasto_model.estadisticas
            elif tipo_reporte == "tipos":
                datos = self.gasto_model.tiposGastos
            elif tipo_reporte == "periodo":
                if fecha_desde and fecha_hasta:
                    self.gasto_model.generarReporte(fecha_desde, fecha_hasta)
                    datos = self.gasto_model.gastos
                else:
                    return ""
            elif tipo_reporte == "dashboard":
                datos = self.gasto_model.obtenerDashboard()
            else:
                return ""
            
            if not datos:
                return ""
            
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json,
                f"gastos_{tipo_reporte}",
                fecha_desde,
                fecha_hasta
            )
            
        except Exception as e:
            print(f"Error generando reporte de gastos: {e}")
            return ""

    @Slot(str, result=str)
    def generar_reporte_configuracion(self, tipo_reporte: str):
        try:
            if not self.configuracion_model:
                return ""
            
            datos = []
            
            if tipo_reporte == "todos":
                datos = self.configuracion_model.tiposGastos
            elif tipo_reporte == "estadisticas":
                datos = self.configuracion_model.estadisticas
            elif tipo_reporte == "resumen_uso":
                datos = self.configuracion_model.obtenerResumenUso()
            else:
                return ""
            
            if not datos:
                return ""
            
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json,
                f"configuracion_{tipo_reporte}",
                "", ""
            )
            
        except Exception as e:
            print(f"Error generando reporte de configuraciÃ³n: {e}")
            return ""

    @Slot(str, result=str)
    def generar_reporte_confi_laboratorio(self, tipo_reporte: str):
        try:
            if not self.confi_laboratorio_model:
                return ""
            
            datos = []
            
            if tipo_reporte == "todos":
                datos = self.confi_laboratorio_model.tiposAnalisis
            elif tipo_reporte == "estadisticas":
                datos = self.confi_laboratorio_model.estadisticas
            elif tipo_reporte == "precios":
                datos = self.confi_laboratorio_model.obtenerTiposAnalisisPorRangoPrecios(0, -1)
            elif tipo_reporte == "resumen_uso":
                datos = self.confi_laboratorio_model.obtenerResumenUso()
            else:
                return ""
            
            if not datos:
                return ""
            
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json,
                f"confi_laboratorio_{tipo_reporte}",
                "", ""
            )
            
        except Exception as e:
            print(f"Error generando reporte de configuraciÃ³n de laboratorio: {e}")
            return ""

    @Slot(str, result=str)
    def generar_reporte_confi_enfermeria(self, tipo_reporte: str):
        try:
            if not self.confi_enfermeria_model:
                return ""
            
            datos = []
            
            if tipo_reporte == "todos":
                datos = self.confi_enfermeria_model.tiposProcedimientos
            elif tipo_reporte == "estadisticas":
                datos = self.confi_enfermeria_model.estadisticas
            elif tipo_reporte == "precios":
                datos = self.confi_enfermeria_model.obtenerTiposProcedimientosPorRangoPrecios(0, -1)
            elif tipo_reporte == "resumen_uso":
                datos = self.confi_enfermeria_model.obtenerResumenUso()
            else:
                return ""
            
            if not datos:
                return ""
            
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json,
                f"confi_enfermeria_{tipo_reporte}",
                "", ""
            )
            
        except Exception as e:
            print(f"Error generando reporte de configuraciÃ³n de enfermerÃ­a: {e}")
            return ""

    @Slot(str, result=str)
    def generar_reporte_confi_consulta(self, tipo_reporte: str):
        try:
            if not self.confi_consulta_model:
                return ""
            
            datos = []
            
            if tipo_reporte == "todos":
                datos = self.confi_consulta_model.especialidades
            elif tipo_reporte == "estadisticas":
                datos = self.confi_consulta_model.estadisticas
            elif tipo_reporte == "precios":
                datos = self.confi_consulta_model.obtenerEspecialidadesPorRangoPrecios(0, -1)
            elif tipo_reporte == "resumen_uso":
                datos = self.confi_consulta_model.obtenerResumenUso()
            else:
                return ""
            
            if not datos:
                return ""
            
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json,
                f"confi_consulta_{tipo_reporte}",
                "", ""
            )
            
        except Exception as e:
            print(f"Error generando reporte de configuraciÃ³n de consultas: {e}")
            return ""

    @Slot(str, str, str, str, result=str)
    def generarReportePDF(self, datos_json, tipo_reporte, fecha_desde, fecha_hasta):
        try:
            if not datos_json or datos_json.strip() == "":
                if tipo_reporte != "9":
                    return ""
            
            resultado = self.pdf_generator.generar_reporte_pdf(
                datos_json,
                tipo_reporte, 
                fecha_desde,
                fecha_hasta
            )
            
            return resultado if resultado else ""
                
        except Exception as e:
            print(f"Error generando PDF: {e}")
            return ""

    # ===============================
    # MÃ‰TODOS AUXILIARES PARA PDFs
    # ===============================
    
    @Slot(result=str)
    def obtenerDirectorioReportes(self):
        return self.pdf_generator.pdf_dir
    
    @Slot(result=bool)
    def verificarDirectorioReportes(self):
        try:
            return os.path.exists(self.pdf_generator.pdf_dir)
        except:
            return False
    
    @Slot(result=bool)  # ← SIN declarar tipo de argumento
    def abrirCarpetaReportes(self, archivo_path=None):
        """Abrir carpeta de reportes en el explorador del sistema"""
        try:
            if archivo_path:
                carpeta = os.path.dirname(archivo_path)
            else:
                carpeta = self.pdf_generator.pdf_dir
            
            import platform
            if platform.system() == "Windows":
                os.startfile(carpeta)
            elif platform.system() == "Darwin":
                os.system(f"open '{carpeta}'")
            else:
                os.system(f"xdg-open '{carpeta}'")
            
            return True
        except Exception as e:
            print(f"Error abriendo carpeta: {e}")
            return False

class AuthAppController(QObject):
    """Controller principal SIMPLIFICADO - CORREGIDO para cambios de usuario y SETUP WIZARD"""
    
    # Signals
    authenticationRequired = Signal()
    authenticationSuccess = Signal()
    loadMainApp = Signal()
    setupRequired = Signal()  # 🆕 Nueva señal para setup
    
    def __init__(self):
        super().__init__()
        
        # 🆕 AGREGAR: Gestor de configuración y setup
        self.config_manager = ConfigManager()
        self.setup_handler = SetupHandler()
        
        self.auth_model = AuthModel()
        self.main_controller = None
        self.authenticated = False
        self.main_engine = None
        self.login_engine = None
        self.setup_engine = None  # 🆕 Engine para setup wizard
        
        # Conectar signals del AuthModel
        self.auth_model.loginSuccessful.connect(self.handleLoginSuccess)
        self.auth_model.loginFailed.connect(self.handleLoginFailed)
        self.auth_model.logoutCompleted.connect(self.handleLogout)
        
        # 🆕 Conectar signals del SetupHandler
        self.setup_handler.setupCompleted.connect(self.handleSetupCompleted)
    
    @Slot(bool, str, 'QVariantMap')
    def handleLoginSuccess(self, success: bool, message: str, userData: dict):
        """Manejo simplificado de login exitoso"""
        if success:
            self.authenticated = True
            
            # Delay para mostrar animación y asegurar destrucción completa
            QTimer.singleShot(1500, lambda: self.initializeMainApp(userData))
        
    @Slot(str)
    def handleLoginFailed(self, message: str):
        """Manejo de login fallido"""
        print(f"❌ Login fallido: {message}")
    
    @Slot()
    def handleLogout(self):
        """LOGOUT MANUAL - VERSIÓN SEGURA CON VALIDACIÓN"""
        try:
            print("🚪 Cierre de sesión manual solicitado...")
            
            # ✅ VALIDAR QUE EL CONTROLADOR EXISTA
            if not self.main_controller:
                print("⚠️ main_controller ya es None - Creando login directo")
                self.authenticated = False
                QTimer.singleShot(100, self.createAndShowLogin)
                return
            
            # ✅ VALIDAR QUE NO HAY OPERACIONES ACTIVAS
            if hasattr(self.main_controller, '_hay_operaciones_activas'):
                if self.main_controller._hay_operaciones_activas():
                    print("⏸️ Operaciones activas - Logout pospuesto")
                    QTimer.singleShot(1000, self.handleLogout)
                    return
            
            print("✅ No hay operaciones activas - Procediendo con logout")
            
            self.authenticated = False
            
            # PASO 1: Cleanup del controlador principal CON VALIDACIÓN
            try:
                print("🧹 Limpiando main_controller...")
                # Usar gradual_cleanup en lugar de emergency_shutdown
                self.main_controller.gradual_cleanup()
                self.main_controller = None
                print("✅ main_controller limpiado")
            except Exception as e:
                print(f"⚠️ Error en cleanup del controlador: {e}")
                self.main_controller = None
            
            # PASO 2: Destruir motor principal con delay
            if self.main_engine:
                try:
                    print("🗑️ Destruyendo main_engine...")
                    self.main_engine.deleteLater()
                    self.main_engine = None
                    print("✅ main_engine destruido")
                except Exception as e:
                    print(f"⚠️ Error destruyendo motor principal: {e}")
                    self.main_engine = None
            
            # PASO 3: Forzar garbage collection
            import gc
            gc.collect()
            
            # PASO 4: Crear y mostrar nuevo login con delay
            QTimer.singleShot(500, self.createAndShowLogin)
            
            print("✅ Logout manual completado")
            
        except Exception as e:
            print(f"❌ Error durante logout manual: {e}")
            import traceback
            traceback.print_exc()
            
            # Forzar reset completo en caso de error
            self.main_controller = None
            self.main_engine = None
            self.authenticated = False
            QTimer.singleShot(1000, self.createAndShowLogin)

    def createAndShowLogin(self):
        """Crea y muestra una nueva instancia de login - MEJORADO"""
        try:
            print("🔐 Creando nueva instancia de login...")
            
            # Asegurar que login anterior esté destruido
            if self.login_engine:
                try:
                    self.login_engine.deleteLater()
                    self.login_engine = None
                except:
                    pass
            
            # Crear nueva engine para login
            self.login_engine = QQmlApplicationEngine()
            
            # Configurar contexto para login
            root_context = self.login_engine.rootContext()
            root_context.setContextProperty("authController", self)
            root_context.setContextProperty("authModel", self.auth_model)
            
            # Cargar login.qml
            login_qml = os.path.join(os.path.dirname(__file__), "login.qml")
            self.login_engine.load(QUrl.fromLocalFile(login_qml))
            
            # Verificar que se cargó correctamente
            if not self.login_engine.rootObjects():
                print("❌ Error: login.qml no se cargó correctamente")
                return
            
            self.authenticationRequired.emit()
            print("✅ Login creado y mostrado exitosamente")
            
        except Exception as e:
            print(f"❌ Error creando login: {e}")
            import traceback
            traceback.print_exc()

    # 🆕 NUEVO MÉTODO: Crear y mostrar Setup Wizard
    def createAndShowSetupWizard(self):
        """Crea y muestra el Setup Wizard para primera configuración"""
        try:
            print("🚀 Creando Setup Wizard...")
            
            # Crear nueva engine para setup
            self.setup_engine = QQmlApplicationEngine()
            
            # Configurar contexto para setup
            root_context = self.setup_engine.rootContext()
            root_context.setContextProperty("setupHandler", self.setup_handler)
            root_context.setContextProperty("authController", self)
            
            # Cargar setup_wizard.qml
            setup_qml = os.path.join(os.path.dirname(__file__), "setup_wizard.qml")
            
            if not os.path.exists(setup_qml):
                print(f"❌ Error: setup_wizard.qml no encontrado: {setup_qml}")
                return
            
            self.setup_engine.load(QUrl.fromLocalFile(setup_qml))
            
            # Verificar que se cargó correctamente
            if not self.setup_engine.rootObjects():
                print("❌ Error: setup_wizard.qml no se cargó correctamente")
                return
            
            self.setupRequired.emit()
            print("✅ Setup Wizard creado y mostrado exitosamente")
            
        except Exception as e:
            print(f"❌ Error creando Setup Wizard: {e}")
            import traceback
            traceback.print_exc()
    
    @Slot(bool, str, 'QVariantMap')
    def handleSetupCompleted(self, success: bool, message: str, credenciales: dict):
        """Maneja la completación del setup wizard"""
        try:
            print(f"📊 Setup completado: {success} - {message}")
            
            if success:
                print("✅ Setup exitoso - Las credenciales se mostraron en el wizard")
                print(f"   Usuario: {credenciales.get('username', 'N/A')}")
                print(f"   Base de datos: {credenciales.get('database', 'N/A')}")
                
                # ❌ NO DESTRUIR setup_engine aquí
                # El wizard sigue vivo hasta que el usuario haga click en "IR AL LOGIN"
                print("ℹ️ Esperando que el usuario haga click en 'IR AL LOGIN'...")
                
            else:
                print(f"❌ Setup falló: {message}")
                # El wizard mostrará el error internamente
                
        except Exception as e:
            print(f"❌ Error manejando setup completado: {e}")
            import traceback
            traceback.print_exc()

    def initializeMainApp(self, userData):
        """Inicializa la aplicación principal - CORREGIDO para recrear siempre"""
        try:
            # PASO 1: Destruir login engine si existe
            if self.login_engine:
                try:
                    print("🗑️ Destruyendo login_engine...")
                    self.login_engine.deleteLater()
                    self.login_engine = None
                    print("✅ login_engine destruido")
                except Exception as e:
                    print(f"⚠️ Error destruyendo login engine: {e}")
                    self.login_engine = None
            
            # PASO 2: SIEMPRE crear nuevo controller (no reutilizar)
            print("🔧 Creando nuevo AppController...")
            self.main_controller = AppController()
            print("✅ Nuevo AppController creado")
            
            # PASO 3: Crear nueva engine para main app
            self.main_engine = QQmlApplicationEngine()
            
            # PASO 4: Configurar contexto para app principal
            root_context = self.main_engine.rootContext()
            root_context.setContextProperty("appController", self.main_controller)
            root_context.setContextProperty("authModel", self.auth_model)
            root_context.setContextProperty("authController", self)
            
            # PASO 5: Cargar main.qml
            main_qml = os.path.join(os.path.dirname(__file__), "main.qml")
            self.main_engine.load(QUrl.fromLocalFile(main_qml))
            
            # PASO 6: Verificar que se cargó correctamente
            if not self.main_engine.rootObjects():
                print("❌ Error: main.qml no se cargó correctamente")
                return
            
            print("✅ main.qml cargado exitosamente")
            
            # ===== AGREGAR ICONO A LA VENTANA PRINCIPAL =====
            try:
                # Obtener la ventana principal
                window = self.main_engine.rootObjects()[0]
                
                # Buscar el icono en diferentes ubicaciones
                possible_icon_paths = [
                    os.path.join(os.path.dirname(__file__), "icono.ico"),
                    os.path.join(os.path.dirname(__file__), "Resources/iconos/logo_CMI.ico"),
                    os.path.join(os.path.dirname(__file__), "Resources/iconos/logo_CMI.png"),
                    os.path.join(os.path.dirname(__file__), "Resources/iconos/logo_CMI.svg"),
                ]
                
                icon_loaded = False
                for icon_path in possible_icon_paths:
                    if os.path.exists(icon_path):
                        from PySide6.QtGui import QIcon
                        window.setIcon(QIcon(icon_path))
                        print(f"✅ Icono de ventana establecido: {icon_path}")
                        icon_loaded = True
                        break
                
                if not icon_loaded:
                    print("⚠️ No se encontró ningún archivo de icono para la ventana")
                    
            except Exception as e:
                print(f"⚠️ Error estableciendo icono de ventana: {e}")
            # ===== FIN ICONO =====
            
            # PASO 7: Inicializar modelos
            print("🔧 Inicializando modelos...")
            self.main_controller.initialize_models()
            
            # PASO 8: Establecer autenticación con delay
            QTimer.singleShot(800, lambda: self._set_user_authentication(userData))
            
            self.authenticationSuccess.emit()
            print("🎉 Aplicación principal inicializada exitosamente")
            
        except Exception as e:
            print(f"❌ Error inicializando app principal: {e}")
            import traceback
            traceback.print_exc()
            
            # En caso de error, mostrar login nuevamente
            QTimer.singleShot(2000, self.createAndShowLogin)

    def _set_user_authentication(self, userData):
        """Establece la autenticación del usuario - MEJORADO con verificaciones"""
        try:
            if not self.main_controller:
                print("❌ Error: main_controller es None al establecer autenticación")
                return
            
            if not userData:
                print("❌ Error: userData es None al establecer autenticación")
                return
            
            user_id = userData.get('id', 0)
            user_name = f"{userData.get('Nombre', '')} {userData.get('Apellido_Paterno', '')}"
            user_role = userData.get('rol_nombre', 'Usuario')
            # Verificar que los datos son válidos
            if user_id <= 0:
                print("❌ Error: ID de usuario inválido")
                return
            
            if not user_role:
                print("❌ Error: Rol de usuario vacío")
                return
            
            # Establecer autenticación
            self.main_controller.set_usuario_autenticado(user_id, user_name, user_role)
            
            print("✅ Autenticación establecida exitosamente")
            
            # Verificación adicional con delay
            QTimer.singleShot(1000, lambda: self._verify_authentication(user_id, user_role))
            
        except Exception as e:
            print(f"❌ Error estableciendo autenticación: {e}")
            import traceback
            traceback.print_exc()
    
    def _verify_authentication(self, expected_id, expected_role):
        """Verifica que la autenticación se estableció correctamente"""
        try:
            if self.main_controller:
                actual_id = self.main_controller.usuario_actual_id
                actual_role = self.main_controller.usuario_actual_rol
                
                print(f"🔍 VERIFICACIÓN DE AUTENTICACIÓN:")
                print(f"   Esperado: ID={expected_id}, Rol='{expected_role}'")
                print(f"   Actual: ID={actual_id}, Rol='{actual_role}'")
                
                if actual_id == expected_id and actual_role == expected_role:
                    pass
                else:
                    print("⚠️ Autenticación no coincide - reintentando...")
                    # Reintentar establecer autenticación
                    user_name = f"Usuario {expected_id}"
                    self.main_controller.set_usuario_autenticado(expected_id, user_name, expected_role)
            else:
                print("❌ main_controller es None durante verificación")
                
        except Exception as e:
            print(f"❌ Error verificando autenticación: {e}")
    
    # Métodos públicos para QML
    @Slot()
    def showLogin(self):
        """Muestra login (para uso desde QML)"""
        print("📞 showLogin() llamado desde QML")
        
        # Destruir setup engine si existe
        if self.setup_engine:
            try:
                print("🗑️ Destruyendo setup_engine antes de crear login...")
                self.setup_engine.deleteLater()
                self.setup_engine = None
                print("✅ Setup engine destruido")
            except Exception as e:
                print(f"⚠️ Error destruyendo setup engine: {e}")
                self.setup_engine = None
        
        # Usar un timer para crear el login después de un pequeño delay
        QTimer.singleShot(300, self.createAndShowLogin)
    
    @Slot()
    def exitApp(self):
        """Sale de la aplicación"""
        QGuiApplication.quit()
    
    @Slot()
    def forceRestart(self):
        """Fuerza un reinicio completo (para debug)"""
        print("🔄 FORZANDO REINICIO COMPLETO...")
        
        # Limpiar todo
        self.main_controller = None
        self.main_engine = None
        self.login_engine = None
        self.setup_engine = None  # 🆕
        self.authenticated = False
        
        # Forzar garbage collection
        import gc
        gc.collect()
        
        # Recrear login después de un delay
        QTimer.singleShot(1000, self.createAndShowLogin)
        
        print("✅ Reinicio completo ejecutado")
def register_qml_types():
    register_inventario_model()
    register_venta_model() 
    register_compra_model()
    register_proveedor_model()
    register_usuario_model()
    register_consulta_model()
    register_gasto_model()
    register_paciente_model()
    register_laboratorio_model()
    register_trabajador_model()
    register_enfermeria_model()
    register_configuracion_model()
    register_confi_laboratorio_model()
    register_confi_enfermeria_model()
    register_confi_consulta_model()
    register_confi_trabajadores_model()
    register_reportes_model()
    register_dashboard_model()
    register_auth_model()
    register_cierre_caja_model()
    register_ingreso_extra_model()

def setup_qml_context(engine, controller):
    root_context = engine.rootContext()
    root_context.setContextProperty("authController", controller)
    root_context.setContextProperty("authModel", controller.auth_model)

def main():
    # 🆕 CONFIGURAR ESTILO ANTES DE CREAR LA APP
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Sistema de GestiÃ³n MÃ©dica")
    app.setApplicationVersion("1.0.0")
    app.setOrganizationName("Clínica Maria Inmaculada")
    
    try:
        # Ruta al archivo de icono (puede ser .ico, .png, .svg)
        icon_path = os.path.join(os.path.dirname(__file__), "Resources/iconos/Logo_de_Emergencia_MÃƒÂ©dica_RGL-removebg-preview.ico")
        
        # Si el archivo existe, establecerlo como icono
        if os.path.exists(icon_path):
            from PySide6.QtGui import QIcon
            app.setWindowIcon(QIcon(icon_path))
            print(f"Ã¢Å“â€¦ Icono de aplicaciÃƒÂ³n cargado: {icon_path}")
        else:
            print(f"Ã¢Å¡ Ã¯Â¸Â Icono no encontrado en: {icon_path}")
    except Exception as e:
        print(f"Ã¢Å¡ Ã¯Â¸Â Error cargando icono: {e}")
    # ===== FIN ICONO =====
    try:
        register_qml_types()
        
        auth_controller = AuthAppController()
        
        # 🆕 VERIFICAR SI ES PRIMERA VEZ
        print("\n" + "="*60)
        print("🔍 VERIFICANDO CONFIGURACIÓN INICIAL")
        print("="*60 + "\n")
        
        config_manager = ConfigManager()
        es_primera_vez = config_manager.es_primera_vez()
        
        if es_primera_vez:
            print("🆕 PRIMERA EJECUCIÓN DETECTADA")
            print("   → Mostrando Setup Wizard\n")
            
            # Mostrar Setup Wizard
            auth_controller.createAndShowSetupWizard()
        else:
            print("✅ CONFIGURACIÓN EXISTENTE ENCONTRADA")
            print("   → Mostrando Login Normal\n")
            
            # Mostrar Login Normal
            login_engine = QQmlApplicationEngine()
            setup_qml_context(login_engine, auth_controller)
            
            login_qml = os.path.join(os.path.dirname(__file__), "login.qml")
            if not os.path.exists(login_qml):
                print(f"❌ Archivo login.qml no encontrado: {login_qml}")
                return -1
            
            login_engine.load(QUrl.fromLocalFile(login_qml))
            
            if not login_engine.rootObjects():
                print("❌ Error cargando login.qml")
                return -1
        
        print("="*60)
        print("✅ Aplicación iniciada correctamente")
        print("="*60 + "\n")
        
        return app.exec()
        
    except Exception as e:
        print(f"❌ Error crítico iniciando aplicación: {e}")
        import traceback
        traceback.print_exc()
        return -1

if __name__ == "__main__":
    sys.exit(main())