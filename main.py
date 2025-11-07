# main.py - VERSIÓN CORREGIDA PARA EJECUTABLE
"""
1. Sistema de logging a archivo (funciona con console=False)
2. Validación temprana de recursos
3. MessageBox de error para casos críticos
4. Try-catch global con manejo robusto
5. Get_resource_path mejorado
"""

import sys
import os
import gc
import logging
from pathlib import Path

# ============================================
# ✅ PASO 0: CONFIGURAR LOGGING ANTES DE TODO
# ============================================
from logger_config import setup_logger, log_exception, redirect_prints_to_logger
from resource_validator import (
    get_resource_path,
    validate_all_resources, 
    show_error_message,
    list_available_files
)

# Configurar logger ANTES de cualquier otra cosa
logger = setup_logger("ClinicaApp")

# Redirigir print() a logger si es ejecutable
redirect_prints_to_logger(logger)

logger.info("🚀 Iniciando aplicación...")

# Imports de Qt
try:
    from PySide6.QtCore import QObject, Signal, Slot, QUrl, QTimer, Property, QSettings, QDateTime
    from PySide6.QtGui import QGuiApplication, QIcon
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtWidgets import QMessageBox, QApplication
    logger.info("✅ Imports de Qt exitosos")
except Exception as e:
    logger.error(f"❌ Error importando Qt: {e}")
    show_error_message(
        "Error de Importación",
        "No se pudieron cargar las librerías de Qt.\n\nReinstala la aplicación.",
        str(e)
    )
    sys.exit(1)

# Imports del proyecto
try:
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
    
    logger.info("✅ Imports del proyecto exitosos")
    
except Exception as e:
    log_exception(logger, e, "Importando módulos del proyecto")
    show_error_message(
        "Error de Importación",
        "No se pudieron cargar los módulos del sistema.\n\nVerifica la instalación.",
        str(e)
    )
    sys.exit(1)


# ============================================
# ✅ CLASE AppController (CON LOGGING)
# ============================================

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
        logger.info("📦 Inicializando AppController...")
        
        self.notification_worker = NotificationWorker()
        self.notification_worker.finished.connect(self.notificationProcessed)
        
        # INICIALIZAR GENERADOR DE PDF
        self.pdf_generator = GeneradorReportesPDF()
        
        # MODELS QOBJECT - Se inicializarán después
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
        
        # Usuario autenticado
        self._usuario_autenticado_id = 0
        self._usuario_autenticado_nombre = ""
        self._usuario_autenticado_rol = ""
        self._is_shutting_down = False
        
        logger.info("✅ AppController inicializado")

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
            logger.info("🔄 Creando instancias de modelos...")
            
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

            logger.info("🔗 Conectando signals entre modelos...")
            # Conectar signals entre models
            self._connect_models()
            
            logger.info("✅ Modelos inicializados correctamente")
            self.modelsReady.emit()
            
        except Exception as e:
            logger.error(f"❌ Error inicializando models: {e}")
            import traceback
            traceback.print_exc()

    @Slot()
    def cleanup(self):
        """Limpia recursos usando el sistema de cleanup gradual"""
        self.gradual_cleanup()

    @Slot()
    def emergency_shutdown(self):
        """
        Sistema de shutdown de emergencia - VERSIÓN SEGURA
        NO destruye modelos si están en operación activa
        """
        try:
            logger.warning("🛑 EMERGENCY SHUTDOWN INICIADO")
            
            # ✅ MARCAR QUE ESTAMOS EN SHUTDOWN INMEDIATAMENTE
            self._is_shutting_down = True
            
            # ✅ VALIDAR QUE NO HAY OPERACIONES ACTIVAS
            if self._hay_operaciones_activas():
                logger.info("⏸️ Operaciones activas detectadas - Shutdown pospuesto")
                # Reintentar después de 500ms
                QTimer.singleShot(500, self.emergency_shutdown)
                return
            
            logger.info("✅ No hay operaciones activas - Procediendo con shutdown")
            
            # FASE 1: DETENER TODOS LOS TIMERS INMEDIATAMENTE
            self._stop_all_timers_immediately()
            
            # FASE 2: DESCONECTAR SEÑALES ORDENADAMENTE  
            self._disconnect_all_signals_ordered()
            
            # FASE 3: LIMPIEZA SINCRONIZADA DE RECURSOS
            self._cleanup_resources_synchronously()
            
            logger.info("✅ EMERGENCY SHUTDOWN COMPLETADO")
            
        except Exception as e:
            logger.error(f"❌ Error en emergency shutdown: {e}")
            # Forzar limpieza básica aunque falle
            self._force_basic_cleanup()

    def _hay_operaciones_activas(self) -> bool:
        """✅ Verifica si hay operaciones activas en algún modelo"""
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
                        logger.warning(f"⚠️ {type(model).__name__} está en operación")
                        return True
                    
                    # Verificar si tiene lock activo
                    if hasattr(model, '_operation_lock') and model._operation_lock:
                        logger.warning(f"⚠️ {type(model).__name__} tiene lock activo")
                        return True
            
            return False
            
        except Exception as e:
            logger.error(f"⚠️ Error verificando operaciones activas: {e}")
            # En caso de error, asumir que NO hay operaciones (más seguro)
            return False

    def _stop_all_timers_immediately(self):
        """FASE 1: Detiene TODOS los timers sin excepción"""
        try:
            logger.info("⏱️ FASE 1: Deteniendo todos los timers...")
            
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
                                    logger.info(f"⏱️ Timer detenido: {type(model).__name__}.{timer_name}")
                        
                        # Buscar timers por inspección de atributos
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
                                        logger.info(f"⏱️ Timer detectado detenido: {type(model).__name__}.{attr_name}")
                                except:
                                    pass
                                    
                    except Exception as e:
                        logger.error(f"⚠️ Error deteniendo timers en {type(model).__name__}: {e}")
            
            logger.info(f"✅ FASE 1 COMPLETA: {timer_count} timers detenidos")
            
        except Exception as e:
            logger.error(f"❌ Error en FASE 1: {e}")

    def _disconnect_all_signals_ordered(self):
        """FASE 2: Desconecta señales en orden específico"""
        try:
            logger.info("🔌 FASE 2: Desconectando señales...")
            
            # 2.1: Desconectar señales globales primero
            try:
                # Intentar desconectar señales globales si existen
                app = QGuiApplication.instance()
                if app:
                    # Desconectar todas las señales de la aplicación
                    for signal_name in dir(app):
                        if not signal_name.startswith('__'):
                            try:
                                signal = getattr(app, signal_name)
                                if hasattr(signal, 'disconnect'):
                                    signal.disconnect()
                            except:
                                pass
                    logger.info("🔌 Señales globales desconectadas")
            except Exception as e:
                logger.error(f"⚠️ Error desconectando señales globales: {e}")
            
            # 2.2: Desconectar referencias bidireccionales
            try:
                if self.compra_model and self.proveedor_model:
                    # Romper referencia bidireccional
                    if hasattr(self.compra_model, '_proveedor_model_ref'):
                        self.compra_model._proveedor_model_ref = None
                    if hasattr(self.proveedor_model, '_compra_model_ref'):
                        self.proveedor_model._compra_model_ref = None
                    logger.info("🔌 Referencias bidireccionales rotas")
            except Exception as e:
                logger.error(f"⚠️ Error rompiendo referencias: {e}")
            
            # 2.3: Desconectar señales internas de cada modelo
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
                        # Llamar método cleanup específico si existe
                        if hasattr(model, 'emergency_disconnect'):
                            model.emergency_disconnect()
                        elif hasattr(model, 'cleanup'):
                            model.cleanup()
                    except Exception as e:
                        logger.error(f"⚠️ Error cleanup {type(model).__name__}: {e}")
            
            logger.info("✅ FASE 2 COMPLETA: Señales desconectadas")
            
        except Exception as e:
            logger.error(f"❌ Error en FASE 2: {e}")

    def _cleanup_resources_synchronously(self):
        """FASE 3: Limpieza sincronizada de recursos"""
        try:
            logger.info("🧹 FASE 3: Limpieza sincronizada...")
            
            # 3.1: Invalidar todos los caches
            models_with_repos = [
                self.inventario_model, self.venta_model, self.compra_model,
                self.proveedor_model, self.consulta_model, self.gasto_model,
                self.laboratorio_model, self.trabajador_model, self.enfermeria_model,
                self.ingreso_extra_model
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
                        logger.error(f"⚠️ Error limpiando cache {type(model).__name__}: {e}")
            
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
                        # ✅ RESETEAR USUARIO EN TODOS LOS MODELOS
                        if hasattr(model, '_usuario_actual_id'):
                            model._usuario_actual_id = 0
                        # Limpiar datos en memoria
                        self._clear_model_data(model)
                    except Exception as e:
                        logger.error(f"⚠️ Error estableciendo shutdown {type(model).__name__}: {e}")
            
            # 3.3: Usar destroy() en lugar de deleteLater()
            for model in all_models:
                if model:
                    try:
                        # Disconnect all signals before destroying
                        model.blockSignals(True)
                        # Forzar destrucción inmediata
                        model.setParent(None)
                    except Exception as e:
                        logger.error(f"⚠️ Error destruyendo {type(model).__name__}: {e}")
            
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
            
            # ✅ RESETEAR USUARIO AUTENTICADO
            self._usuario_autenticado_id = 0
            self._usuario_autenticado_nombre = ""
            self._usuario_autenticado_rol = ""
            
            logger.info("✅ FASE 3 COMPLETA: Recursos limpiados")
            
        except Exception as e:
            logger.error(f"❌ Error en FASE 3: {e}")

    def _force_basic_cleanup(self):
        """Limpieza básica de emergencia si falla el shutdown normal"""
        try:
            logger.warning("🔄 FORZANDO LIMPIEZA BÁSICA...")
            
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
            
            logger.info("✅ Limpieza básica completada")
            
        except Exception as e:
            logger.error(f"❌ Error en limpieza básica: {e}")

    @Slot()
    def gradual_cleanup(self):
        """Sistema de cleanup gradual - preserva la estructura para transiciones"""
        try:
            logger.info("🧹 CLEANUP GRADUAL INICIADO")
            
            # RESETEAR USUARIO AUTENTICADO INMEDIATAMENTE
            self._usuario_autenticado_id = 0
            self._usuario_autenticado_nombre = ""
            self._usuario_autenticado_rol = ""
            self.usuarioChanged.emit()
            
            # LIMPIAR DATOS EN MEMORIA SIN DESTRUIR OBJETOS
            self._clear_model_data_only()
            
            logger.info("✅ CLEANUP GRADUAL COMPLETADO")
            
        except Exception as e:
            logger.error(f"⚠️ Error en cleanup gradual: {e}")

    def _clear_model_data_only(self):
        """Limpia datos sin destruir objetos"""
        try:
            logger.info("🧹 Limpiando datos...")
            
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
                        logger.error(f"⚠️ Error limpiando datos {type(model).__name__}: {e}")
            
            logger.info("✅ Datos limpiados")
            
        except Exception as e:
            logger.error(f"❌ Error en limpieza de datos: {e}")

    def _clear_model_data(self, model):
        """Limpia datos específicos de un modelo"""
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
            logger.error(f"⚠️ Error limpiando datos de modelo: {e}")

    def _connect_models(self):
        """Conecta signals entre models para sincronización - VERSIÓN CORREGIDA"""
        try:
            logger.info("🔗 Configurando conexiones entre modelos...")
            
            # ===== CONEXIONES BÁSICAS =====
            if self.venta_model:
                self.venta_model.ventaCreada.connect(self._on_venta_creada)
                logger.info("✅ VERIFICADO: Ventas → Cierre de Caja conectado")
                
            if self.compra_model:
                self.compra_model.compraCreada.connect(self._on_compra_creada)
            
            # ===== CONEXIONES ESPECÍFICAS PARA CIERRE DE CAJA =====
            if self.cierre_caja_model:
                # Solo establecer referencia para PDFs
                self.cierre_caja_model.set_app_controller(self)
                logger.info("✅ AppController conectado al CierreCajaModel para PDFs")
            if self.ingreso_extra_model:
                if hasattr(self.ingreso_extra_model, 'errorOcurrido'):
                    self.ingreso_extra_model.errorOcurrido.connect(self._on_model_error)
                logger.info("✅ IngresoExtraModel conectado")
            # ===== CONEXIONES DE ERRORES Y ÉXITOS - VERSIÓN SEGURA =====
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
                        # ✅ CONECTAR SEÑALES CON TRY-CATCH
                        if hasattr(model, 'operacionError'):
                            model.operacionError.connect(self._on_model_error)
                        if hasattr(model, 'errorOccurred'):
                            model.errorOccurred.connect(self._on_model_error)
                        if hasattr(model, 'operacionExitosa'):
                            model.operacionExitosa.connect(self._on_model_success)
                        if hasattr(model, 'successMessage'):
                            model.successMessage.connect(self._on_model_success)
                    except Exception as e:
                        logger.error(f"⚠️ Error conectando señales de {type(model).__name__}: {e}")
            
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

            # ===== CONEXIONES ESPECÍFICAS PARA MODELOS =====
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
                logger.info("✅ AppController conectado al CierreCajaModel para PDFs")

        except Exception as e:
            logger.error(f"❌ Error conectando models: {e}")
            import traceback
            traceback.print_exc()

    @Slot(int, str, str)
    def set_usuario_autenticado(self, usuario_id: int, usuario_nombre: str, usuario_rol: str):
        
        # Establecer usuario inmediatamente
        self._usuario_autenticado_id = usuario_id
        self._usuario_autenticado_nombre = usuario_nombre
        self._usuario_autenticado_rol = usuario_rol
        
        # Emitir señal de cambio
        self.usuarioChanged.emit()
        
        # Establecer usuario en todos los modelos
        self._establecer_usuario_en_modelos()
        
        logger.info(f"✅ Usuario autenticado establecido correctamente")

    def _establecer_usuario_en_modelos(self):
        """
        ✅ VERSIÓN CORREGIDA: Establece el usuario autenticado en TODOS los modelos
        CRÍTICO: Este método debe llamarse DESPUÉS de initialize_models()
        """
        if self._usuario_autenticado_id > 0:
            logger.info(f"\n{'='*60}")
            logger.info(f"🔐 ESTABLECIENDO USUARIO EN TODOS LOS MODELOS")
            logger.info(f"{'='*60}")
            logger.info(f"   Usuario ID: {self._usuario_autenticado_id}")
            logger.info(f"   Nombre: {self._usuario_autenticado_nombre}")
            logger.info(f"   Rol: {self._usuario_autenticado_rol}")
            logger.info("")
            
            # ✅ MODELO INVENTARIO (usa set_usuario_actual)
            if self.inventario_model and hasattr(self.inventario_model, 'set_usuario_actual'):
                try:
                    self.inventario_model.set_usuario_actual(self._usuario_autenticado_id)
                    logger.info("✅ Usuario establecido en InventarioModel")
                except Exception as e:
                    logger.error(f"❌ Error en InventarioModel: {e}")
            
            # ✅ MODELO VENTA (CRÍTICO - usa set_usuario_actual_con_rol)
            if self.venta_model and hasattr(self.venta_model, 'set_usuario_actual_con_rol'):
                try:
                    logger.info(f"🔍 Estableciendo usuario en VentaModel...")
                    logger.info(f"   ID: {self._usuario_autenticado_id}")
                    logger.info(f"   Rol: {self._usuario_autenticado_rol}")
                    
                    self.venta_model.set_usuario_actual_con_rol(
                        self._usuario_autenticado_id,
                        self._usuario_autenticado_rol
                    )
                    
                    # Verificar que se estableció correctamente
                    actual_id = self.venta_model.usuario_actual_id
                    logger.info(f"✅ VentaModel configurado - Usuario verificado: {actual_id}")
                    
                    if actual_id != self._usuario_autenticado_id:
                        logger.warning(f"⚠️ ADVERTENCIA: Usuario no coincide en VentaModel!")
                        logger.warning(f"   Esperado: {self._usuario_autenticado_id}, Actual: {actual_id}")
                        
                except Exception as e:
                    logger.error(f"❌ Error CRÍTICO en VentaModel: {e}")
                    import traceback
                    traceback.print_exc()
            
            # ✅ MODELO COMPRA (usa set_usuario_actual)
            if self.compra_model and hasattr(self.compra_model, 'set_usuario_actual'):
                try:
                    self.compra_model.set_usuario_actual(self._usuario_autenticado_id)
                    logger.info("✅ Usuario establecido en CompraModel")
                except Exception as e:
                    logger.error(f"❌ Error en CompraModel: {e}")
            
            # ✅ MODELO PROVEEDOR (usa set_usuario_actual_con_rol)
            if self.proveedor_model and hasattr(self.proveedor_model, 'set_usuario_actual_con_rol'):
                try:
                    self.proveedor_model.set_usuario_actual_con_rol(
                        self._usuario_autenticado_id,
                        self._usuario_autenticado_rol
                    )
                    logger.info("✅ Usuario establecido en ProveedorModel")
                except Exception as e:
                    logger.error(f"❌ Error en ProveedorModel: {e}")
            
            # ✅ MODELO CONSULTA (usa set_usuario_actual_con_rol)
            if self.consulta_model and hasattr(self.consulta_model, 'set_usuario_actual_con_rol'):
                try:
                    self.consulta_model.set_usuario_actual_con_rol(
                        self._usuario_autenticado_id,
                        self._usuario_autenticado_rol
                    )
                    logger.info("✅ Usuario establecido en ConsultaModel")
                except Exception as e:
                    logger.error(f"❌ Error en ConsultaModel: {e}")
            
            # ✅ MODELO ENFERMERÍA (usa set_usuario_actual_con_rol)
            if self.enfermeria_model and hasattr(self.enfermeria_model, 'set_usuario_actual_con_rol'):
                try:
                    self.enfermeria_model.set_usuario_actual_con_rol(
                        self._usuario_autenticado_id,
                        self._usuario_autenticado_rol
                    )
                    logger.info("✅ Usuario establecido en EnfermeriaModel")
                except Exception as e:
                    logger.error(f"❌ Error en EnfermeriaModel: {e}")
            
            # ✅ MODELO LABORATORIO (usa set_usuario_actual_con_rol)
            if self.laboratorio_model and hasattr(self.laboratorio_model, 'set_usuario_actual_con_rol'):
                try:
                    self.laboratorio_model.set_usuario_actual_con_rol(
                        self._usuario_autenticado_id,
                        self._usuario_autenticado_rol
                    )
                    logger.info("✅ Usuario establecido en LaboratorioModel")
                except Exception as e:
                    logger.error(f"❌ Error en LaboratorioModel: {e}")
            
            # ✅ MODELO GASTO (usa set_usuario_actual_con_rol)
            if self.gasto_model and hasattr(self.gasto_model, 'set_usuario_actual_con_rol'):
                try:
                    self.gasto_model.set_usuario_actual_con_rol(
                        self._usuario_autenticado_id,
                        self._usuario_autenticado_rol
                    )
                    logger.info("✅ Usuario establecido en GastoModel")
                except Exception as e:
                    logger.error(f"❌ Error en GastoModel: {e}")
            
            # ✅ MODELO TRABAJADOR (usa set_usuario_actual_con_rol)
            if self.trabajador_model and hasattr(self.trabajador_model, 'set_usuario_actual_con_rol'):
                try:
                    self.trabajador_model.set_usuario_actual_con_rol(
                        self._usuario_autenticado_id,
                        self._usuario_autenticado_rol
                    )
                    logger.info("✅ Usuario establecido en TrabajadorModel")
                except Exception as e:
                    logger.error(f"❌ Error en TrabajadorModel: {e}")
            
            # ✅ MODELO USUARIO (usa set_usuario_actual_con_rol)
            if self.usuario_model and hasattr(self.usuario_model, 'set_usuario_actual_con_rol'):
                try:
                    self.usuario_model.set_usuario_actual_con_rol(
                        self._usuario_autenticado_id,
                        self._usuario_autenticado_rol
                    )
                    logger.info("✅ Usuario establecido en UsuarioModel")
                except Exception as e:
                    logger.error(f"❌ Error en UsuarioModel: {e}")
            
            # ✅ MODELO REPORTES (usa set_usuario_actual)
            if self.reportes_model and hasattr(self.reportes_model, 'set_usuario_actual'):
                try:
                    self.reportes_model.set_usuario_actual(self._usuario_autenticado_id)
                    logger.info("✅ Usuario establecido en ReportesModel")
                except Exception as e:
                    logger.error(f"❌ Error en ReportesModel: {e}")
            
            # ✅ MODELO DASHBOARD (usa set_usuario_actual_con_rol)
            if self.dashboard_model and hasattr(self.dashboard_model, 'set_usuario_actual_con_rol'):
                try:
                    self.dashboard_model.set_usuario_actual_con_rol(
                        self._usuario_autenticado_id,
                        self._usuario_autenticado_rol
                    )
                    logger.info("✅ Usuario establecido en DashboardModel")
                except Exception as e:
                    logger.error(f"❌ Error en DashboardModel: {e}")
            
            # ✅ MODELO CIERRE CAJA (usa set_usuario_actual_con_rol)
            if self.cierre_caja_model and hasattr(self.cierre_caja_model, 'set_usuario_actual_con_rol'):
                try:
                    self.cierre_caja_model.set_usuario_actual_con_rol(
                        self._usuario_autenticado_id,
                        self._usuario_autenticado_rol
                    )
                    logger.info("✅ Usuario establecido en CierreCajaModel")
                except Exception as e:
                    logger.error(f"❌ Error en CierreCajaModel: {e}")
            
            # ✅ MODELO INGRESO EXTRA (usa set_usuario_actual_con_rol)
            if self.ingreso_extra_model and hasattr(self.ingreso_extra_model, 'set_usuario_actual_con_rol'):
                try:
                    self.ingreso_extra_model.set_usuario_actual_con_rol(
                        self._usuario_autenticado_id,
                        self._usuario_autenticado_rol
                    )
                    logger.info("✅ Usuario establecido en IngresoExtraModel")
                except Exception as e:
                    logger.error(f"❌ Error en IngresoExtraModel: {e}")
            
            logger.info("")
            logger.info("="*60)
            logger.info("✅ USUARIO ESTABLECIDO EN TODOS LOS MODELOS")
            logger.info("="*60)
            logger.info("")

    # Handlers para eventos específicos de modelos
    @Slot(int, float)
    def _on_venta_creada(self, venta_id: int, total: float):
        """Handler SIMPLIFICADO para ventas creadas"""
        try:
            logger.info(f"💰 Venta creada - ID: {venta_id}, Total: Bs {total:,.2f}")
            
            # Actualizar inventario únicamente
            if self.inventario_model:
                QTimer.singleShot(1000, self.inventario_model.refresh_productos)
                
        except Exception as e:
            logger.error(f"❌ Error procesando venta creada: {e}")

    @Slot(int, float)
    def _on_compra_creada(self, compra_id: int, total: float):
        """Handler SIMPLIFICADO para compras creadas"""
        try:
            logger.info(f"🛒 Compra creada - ID: {compra_id}, Total: Bs {total:,.2f}")
            
            # Actualizar inventario únicamente
            if self.inventario_model:
                QTimer.singleShot(1000, self.inventario_model.refresh_productos)
                
        except Exception as e:
            logger.error(f"❌ Error procesando compra creada: {e}")

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
        """Handler genérico para transacciones financieras - MEJORADO"""
        try:
            if self.cierre_caja_model:
                logger.info(f"💳 Transacción registrada - ID: {transaccion_id}, Monto: {monto}")
                
                # Refresh inmediato sin delay
                self.cierre_caja_model.repository.refresh_cache_immediately()
                # Delay mínimo para que la BD se actualice
                QTimer.singleShot(200, lambda: self._refresh_cierre_caja("Transacción general"))
        except Exception as e:
            logger.error(f"❌ Error procesando transacción: {e}")

    def _refresh_cierre_directo(self, tipo_transaccion: str, transaccion_id: int, monto: float):
        """
        Método UNIFICADO de refresh directo - USA LA LÓGICA QUE FUNCIONA
        """
        try:
            # 1. Invalidar caché inmediatamente
            self.repository.invalidar_cache_transaccion()
            
            # 2. Log de la transacción (sin polling complejo)
            if hasattr(self.repository, 'notificar_transaccion_nueva'):
                self.repository.notificar_transaccion_nueva(tipo_transaccion, monto, transaccion_id)
            
            # 3. Refresh inmediato usando el método que funciona
            self.repository.refresh_cache_immediately()
            
            # 4. Forzar actualización del modelo
            self._cargar_datos_dia()
            
            logger.info(f"✅ Cierre de caja actualizado por {tipo_transaccion} {transaccion_id}")
            
        except Exception as e:
            logger.error(f"❌ Error en refresh directo: {e}")
            # Fallback: al menos invalidar y recargar básico
            try:
                self.repository.invalidar_cache_completo()
                self._cargar_datos_dia()
            except:
                pass

    @Slot(str)
    def _refresh_cierre_caja(self, mensaje: str = ""):
        """Refresca los datos del cierre de caja - MÉTODO MEJORADO"""
        try:
            if self.cierre_caja_model:
                logger.info(f"🔄 Refrescando datos de Cierre de Caja... ({mensaje})")
                
                # 1. Invalidar caché inmediatamente
                if hasattr(self.cierre_caja_model.repository, 'refresh_cache_immediately'):
                    self.cierre_caja_model.repository.refresh_cache_immediately()
                
                # 2. Forzar actualización del modelo
                self.cierre_caja_model.forzarActualizacion()
                
                logger.info(f"✅ Cierre de caja actualizado: {mensaje}")
                
        except Exception as e:
            logger.error(f"❌ Error refrescando cierre de caja: {e}")

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
            logger.error(f"Error en handler procedimiento creado: {e}")

    @Slot(str)
    def _on_procedimiento_actualizado(self, message: str):
        """Handler para procedimiento actualizado - Solo recibe mensaje JSON"""
        try:
            import json
            data = json.loads(message)
            if data.get('exito', False):
                self.showNotification("Procedimiento Actualizado", "Procedimiento actualizado exitosamente")
        except Exception as e:
            logger.error(f"Error en handler procedimiento actualizado: {e}")

    @Slot(str)
    def _on_procedimiento_eliminado(self, message: str):
        """Handler para procedimiento eliminado - Solo recibe mensaje JSON"""
        try:
            import json
            data = json.loads(message)
            if data.get('exito', False):
                self.showNotification("Procedimiento Eliminado", "Procedimiento eliminado exitosamente")
        except Exception as e:
            logger.error(f"Error en handler procedimiento eliminado: {e}")

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
            self.showNotification("Análisis Creado", message)

    @Slot(bool, str)
    def _on_tipo_analisis_actualizado(self, success: bool, message: str):
        if success:
            self.showNotification("Análisis Actualizado", message)

    @Slot(bool, str)
    def _on_tipo_analisis_eliminado(self, success: bool, message: str):
        if success:
            self.showNotification("Análisis Eliminado", message)

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
        """Handler de errores de modelos - VERSIÓN SEGURA"""
        try:
            # ✅ NO PROCESAR DURANTE SHUTDOWN
            if hasattr(self, '_is_shutting_down') and self._is_shutting_down:
                logger.warning(f"⏸️ Error de modelo ignorado durante shutdown: {mensaje}")
                return
            
            # ✅ LOG DEL ERROR
            logger.error(f"❌ Error de modelo: {mensaje}")
            
            # ✅ MOSTRAR NOTIFICACIÓN DE FORMA SEGURA
            self.showNotification("Error", mensaje)
            
        except Exception as e:
            logger.error(f"⚠️ Error en handler de errores: {e}")

    @Slot(str)
    def _on_model_success(self, mensaje: str):
        """Handler de éxitos de modelos - VERSIÓN SEGURA"""
        try:
            # ✅ NO PROCESAR DURANTE SHUTDOWN
            if hasattr(self, '_is_shutting_down') and self._is_shutting_down:
                return
            
            # ✅ LOG OPCIONAL (comentado para no saturar)
            # logger.info(f"✅ Éxito de modelo: {mensaje}")
            
            # Opcional: mostrar notificación
            # self.showNotification("Éxito", mensaje)
            
        except Exception as e:
            logger.error(f"⚠️ Error en handler de éxitos: {e}")

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
    # MÉTODOS DE NAVEGACIÓN Y NOTIFICACIONES
    # ===============================
    
    @Slot(str, str)
    def showNotification(self, title, message):
        """Muestra notificación de forma segura - VERSIÓN MEJORADA"""
        try:
            # ✅ VALIDAR QUE NO ESTEMOS EN SHUTDOWN
            if hasattr(self, '_is_shutting_down') and self._is_shutting_down:
                logger.warning(f"⏸️ Notificación bloqueada durante shutdown: {title}")
                return
            
            # ✅ VALIDAR QUE notification_worker EXISTA
            if not hasattr(self, 'notification_worker') or not self.notification_worker:
                logger.error(f"⚠️ notification_worker no disponible: {title} - {message}")
                return
            
            # ✅ EMITIR DIRECTAMENTE SIN QTimer (más seguro)
            self.notification_worker.process_notification(title, message)
            
        except Exception as e:
            logger.error(f"⚠️ Error en showNotification: {e}")
    
    @Slot(str)
    def navigateToModule(self, module_name):
        pass  # Implementación en QML

    # ===============================
    # MÉTODOS DE GENERACIÓN DE PDF (COMPLETOS)
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
            logger.error(f"Error generando reporte inventario: {e}")
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
            logger.error(f"Error generando reporte ventas: {e}")
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
            logger.error(f"Error generando reporte de proveedores: {e}")
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
            logger.error(f"Error generando reporte usuarios: {e}")
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
            logger.error(f"Error generando reporte de trabajadores: {e}")
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
            logger.error(f"Error generando reporte de gastos: {e}")
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
            logger.error(f"Error generando reporte de configuración: {e}")
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
            logger.error(f"Error generando reporte de configuración de laboratorio: {e}")
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
            logger.error(f"Error generando reporte de configuración de enfermería: {e}")
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
            logger.error(f"Error generando reporte de configuración de consultas: {e}")
            return ""

    @Slot(str, str, str, str, result=str)
    def generarReportePDF(self, datos_json, tipo_reporte, fecha_desde, fecha_hasta):
        """
        ✅ MODIFICADO: Ahora establece el responsable antes de generar el PDF
        """
        try:
            if not datos_json or datos_json.strip() == "":
                if tipo_reporte != "9":
                    return ""
            
            # ✅ NUEVO: Establecer responsable ANTES de generar PDF
            usuario_nombre = self._usuario_autenticado_nombre or "Usuario Sistema"
            usuario_rol = self._usuario_autenticado_rol or "Usuario"
            
            logger.info(f"\n{'='*60}")
            logger.info(f"📄 GENERANDO PDF CON RESPONSABLE")
            logger.info(f"{'='*60}")
            logger.info(f"   👤 Nombre: {usuario_nombre}")
            logger.info(f"   🔑 Rol: {usuario_rol}")
            logger.info(f"   📊 Tipo Reporte: {tipo_reporte}")
            logger.info(f"   📅 Período: {fecha_desde} - {fecha_hasta}")
            logger.info(f"{'='*60}\n")
            
            # ✅ ESTABLECER RESPONSABLE EN EL GENERADOR
            self.pdf_generator.set_responsable(usuario_nombre, usuario_rol)
            
            # Generar PDF normalmente
            resultado = self.pdf_generator.generar_reporte_pdf(
                datos_json,
                tipo_reporte, 
                fecha_desde,
                fecha_hasta
            )
            
            if resultado:
                logger.info(f"✅ PDF generado exitosamente: {resultado}")
                logger.info(f"   👤 Responsable registrado: {usuario_nombre}\n")
            
            return resultado if resultado else ""
                
        except Exception as e:
            logger.error(f"❌ Error generando PDF: {e}")
            import traceback
            traceback.print_exc()
            return ""

    # ===============================
    # MÉTODOS AUXILIARES PARA PDFs
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
            logger.error(f"Error abriendo carpeta: {e}")
            return False


# ============================================
# ✅ CLASE AuthAppController (CON LOGGING Y VALIDACIÓN)
# ============================================

class AuthAppController(QObject):
    """
    ✅ VERSIÓN MEJORADA: Con validación de recursos y logging
    """
    
    # Signals
    authenticationRequired = Signal()
    authenticationSuccess = Signal()
    loadMainApp = Signal()
    setupRequired = Signal()
    
    def __init__(self):
        super().__init__()
        logger.info("🔐 Inicializando AuthAppController...")
        
        try:
            self.config_manager = ConfigManager()
            self.setup_handler = SetupHandler()
            self.auth_model = AuthModel()
            
            self.main_controller = None
            self.authenticated = False
            self.main_engine = None
            self.login_engine = None
            self.setup_engine = None
            
            # Conectar signals
            self.auth_model.loginSuccessful.connect(self.handleLoginSuccess)
            self.auth_model.loginFailed.connect(self.handleLoginFailed)
            self.auth_model.logoutCompleted.connect(self.handleLogout)
            self.setup_handler.setupCompleted.connect(self.handleSetupCompleted)
            
            logger.info("✅ AuthAppController inicializado")
            
        except Exception as e:
            log_exception(logger, e, "Inicializando AuthAppController")
            raise
    
    @Slot(bool, str, 'QVariantMap')
    def handleLoginSuccess(self, success: bool, message: str, userData: dict):
        """Manejo de login exitoso con logging"""
        if success:
            logger.info(f"✅ Login exitoso: {userData.get('Nombre', 'Usuario')}")
            self.authenticated = True
            QTimer.singleShot(1500, lambda: self.initializeMainApp(userData))
        else:
            logger.warning(f"⚠️ Login no exitoso pero success=True")
    
    @Slot(str)
    def handleLoginFailed(self, message: str):
        """Manejo de login fallido"""
        logger.warning(f"❌ Login fallido: {message}")
    
    @Slot()
    def handleLogout(self):
        """Logout con validación y logging"""
        try:
            logger.info("🚪 Cerrando sesión...")
            
            if not self.main_controller:
                logger.warning("main_controller ya es None")
                self.authenticated = False
                QTimer.singleShot(100, self.createAndShowLogin)
                return
            
            if hasattr(self.main_controller, '_hay_operaciones_activas'):
                if self.main_controller._hay_operaciones_activas():
                    logger.info("⏸️ Operaciones activas - Logout pospuesto")
                    QTimer.singleShot(1000, self.handleLogout)
                    return
            
            self.authenticated = False
            
            # Cleanup
            try:
                self.main_controller.gradual_cleanup()
                self.main_controller = None
                logger.info("✅ main_controller limpiado")
            except Exception as e:
                log_exception(logger, e, "Limpiando main_controller")
                self.main_controller = None
            
            # Destruir engine
            if self.main_engine:
                try:
                    self.main_engine.deleteLater()
                    self.main_engine = None
                    logger.info("✅ main_engine destruido")
                except Exception as e:
                    log_exception(logger, e, "Destruyendo main_engine")
                    self.main_engine = None
            
            gc.collect()
            QTimer.singleShot(500, self.createAndShowLogin)
            
            logger.info("✅ Logout completado")
            
        except Exception as e:
            log_exception(logger, e, "Durante logout")
            self.main_controller = None
            self.main_engine = None
            self.authenticated = False
            QTimer.singleShot(1000, self.createAndShowLogin)
    
    def createAndShowLogin(self):
        """✅ VERSIÓN MEJORADA: Crea login con validación de recursos"""
        try:
            logger.info("🔑 Creando ventana de login...")
            
            # Limpiar login anterior
            if self.login_engine:
                try:
                    self.login_engine.deleteLater()
                    self.login_engine = None
                except:
                    pass
            
            # ✅ VALIDAR QUE login.qml EXISTA
            try:
                login_qml = get_resource_path("login.qml", logger)
                logger.info(f"✅ login.qml encontrado: {login_qml}")
            except FileNotFoundError as e:
                logger.error(f"❌ login.qml NO ENCONTRADO")
                show_error_message(
                    "Archivo Faltante",
                    "No se encontró el archivo login.qml\n\nReinstala la aplicación.",
                    str(e)
                )
                return
            
            # Crear engine
            self.login_engine = QQmlApplicationEngine()
            
            # Configurar contexto
            root_context = self.login_engine.rootContext()
            root_context.setContextProperty("authController", self)
            root_context.setContextProperty("authModel", self.auth_model)
            
            # Cargar QML
            self.login_engine.load(QUrl.fromLocalFile(login_qml))
            
            # ✅ VALIDAR CARGA
            if not self.login_engine.rootObjects():
                logger.error("❌ login.qml no se cargó correctamente")
                show_error_message(
                    "Error de Carga",
                    "No se pudo cargar la ventana de login.\n\nVerifica los logs.",
                    f"login.qml: {login_qml}"
                )
                return
            
            self.authenticationRequired.emit()
            logger.info("✅ Login creado y mostrado")
            
        except Exception as e:
            log_exception(logger, e, "Creando login")
            show_error_message(
                "Error Crítico",
                "No se pudo iniciar la aplicación.\n\nRevisa el archivo de logs.",
                str(e)
            )
    
    def createAndShowSetupWizard(self):
        """✅ VERSIÓN MEJORADA: Crea setup wizard con validación"""
        try:
            logger.info("🚀 Creando Setup Wizard...")
            
            # ✅ VALIDAR QUE setup_wizard.qml EXISTA
            try:
                setup_qml = get_resource_path("setup_wizard.qml", logger)
                logger.info(f"✅ setup_wizard.qml encontrado: {setup_qml}")
            except FileNotFoundError as e:
                logger.error(f"❌ setup_wizard.qml NO ENCONTRADO")
                show_error_message(
                    "Archivo Faltante",
                    "No se encontró el archivo setup_wizard.qml\n\nReinstala la aplicación.",
                    str(e)
                )
                # Fallback: mostrar login directamente
                self.createAndShowLogin()
                return
            
            # Crear engine
            self.setup_engine = QQmlApplicationEngine()
            
            # Configurar contexto
            root_context = self.setup_engine.rootContext()
            root_context.setContextProperty("setupHandler", self.setup_handler)
            root_context.setContextProperty("authController", self)
            
            # Cargar QML
            self.setup_engine.load(QUrl.fromLocalFile(setup_qml))
            
            # ✅ VALIDAR CARGA
            if not self.setup_engine.rootObjects():
                logger.error("❌ setup_wizard.qml no se cargó")
                show_error_message(
                    "Error de Carga",
                    "No se pudo cargar el Setup Wizard.\n\nIntenta reinstalar.",
                    f"setup_wizard.qml: {setup_qml}"
                )
                # Fallback
                self.createAndShowLogin()
                return
            
            self.setupRequired.emit()
            logger.info("✅ Setup Wizard mostrado")
            
        except Exception as e:
            log_exception(logger, e, "Creando Setup Wizard")
            show_error_message(
                "Error Crítico",
                "No se pudo iniciar el Setup.\n\nRevisa el archivo de logs.",
                str(e)
            )
            # Fallback
            self.createAndShowLogin()
    
    @Slot(bool, str, 'QVariantMap')
    def handleSetupCompleted(self, success: bool, message: str, credenciales: dict):
        """Maneja completación del setup"""
        logger.info(f"📊 Setup completado: {success} - {message}")
        
        if success:
            logger.info(f"✅ Credenciales: {credenciales.get('username', 'N/A')}")
        else:
            logger.error(f"❌ Setup falló: {message}")
    
    def initializeMainApp(self, userData):
        """Inicializa la aplicación principal - CORREGIDO para recrear siempre"""
        try:
            # PASO 1: Destruir login engine si existe
            if self.login_engine:
                try:
                    logger.info("🗑️ Destruyendo login_engine...")
                    self.login_engine.deleteLater()
                    self.login_engine = None
                    logger.info("✅ login_engine destruido")
                except Exception as e:
                    logger.error(f"⚠️ Error destruyendo login engine: {e}")
                    self.login_engine = None
            
            # PASO 2: SIEMPRE crear nuevo controller (no reutilizar)
            logger.info("🔧 Creando nuevo AppController...")
            self.main_controller = AppController()
            logger.info("✅ Nuevo AppController creado")
            
            # PASO 3: Crear nueva engine para main app
            self.main_engine = QQmlApplicationEngine()
            
            # PASO 4: Configurar contexto para app principal
            root_context = self.main_engine.rootContext()
            root_context.setContextProperty("appController", self.main_controller)
            root_context.setContextProperty("authModel", self.auth_model)
            root_context.setContextProperty("authController", self)
            
            # PASO 5: Cargar main.qml
            main_qml = get_resource_path("main.qml", logger)
            self.main_engine.load(QUrl.fromLocalFile(main_qml))
            
            # PASO 6: Verificar que se cargó correctamente
            if not self.main_engine.rootObjects():
                logger.error("❌ Error: main.qml no se cargó correctamente")
                return
            
            logger.info("✅ main.qml cargado exitosamente")
            
            # ✅ ✅ ✅ AGREGAR ESTAS LÍNEAS AQUÍ (DESPUÉS DE VERIFICAR rootObjects)
            # =========================================================
            # ESTABLECER ICONO EN LA VENTANA PRINCIPAL
            # =========================================================
            try:
                window = self.main_engine.rootObjects()[0]
                
                # Obtener ruta del icono
                if getattr(sys, 'frozen', False):
                    base_path = Path(sys._MEIPASS)
                else:
                    base_path = Path(__file__).parent
                
                icon_paths = [
                    base_path / "Resources" / "iconos" / "Logo_de_Emergencia_Médica_RGL-removebg-preview.ico",
                    base_path / "_internal" / "Resources" / "iconos" / "Logo_de_Emergencia_Médica_RGL-removebg-preview.ico",
                ]
                
                for icon_path in icon_paths:
                    if icon_path.exists():
                        window.setIcon(QIcon(str(icon_path)))
                        logger.info(f"✅ Icono establecido en ventana principal: {icon_path}")
                        break
                else:
                    logger.warning("⚠️ No se encontró archivo de icono para la ventana principal")
                    
            except Exception as e:
                logger.warning(f"⚠️ Error estableciendo icono en ventana principal: {e}")
            # =========================================================
            
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
                        logger.info(f"✅ Icono de ventana establecido: {icon_path}")
                        icon_loaded = True
                        break
                
                if not icon_loaded:
                    logger.warning("⚠️ No se encontró ningún archivo de icono para la ventana")
                    
            except Exception as e:
                logger.error(f"⚠️ Error estableciendo icono de ventana: {e}")
            # ===== FIN ICONO =====
            
            # PASO 7: Inicializar modelos
            logger.info("🔧 Inicializando modelos...")
            self.main_controller.initialize_models()
            
            # PASO 8: Establecer autenticación con delay
            QTimer.singleShot(800, lambda: self._set_user_authentication(userData))
            
            self.authenticationSuccess.emit()
            logger.info("🎉 Aplicación principal inicializada exitosamente")
            
        except Exception as e:
            logger.error(f"❌ Error inicializando app principal: {e}")
            import traceback
            traceback.print_exc()
            
            # En caso de error, mostrar login nuevamente
            QTimer.singleShot(2000, self.createAndShowLogin)

    def _set_user_authentication(self, userData):
        """Establece la autenticación del usuario - MEJORADO con verificaciones"""
        try:
            if not self.main_controller:
                logger.error("❌ Error: main_controller es None al establecer autenticación")
                return
            
            if not userData:
                logger.error("❌ Error: userData es None al establecer autenticación")
                return
            
            user_id = userData.get('id', 0)
            user_name = f"{userData.get('Nombre', '')} {userData.get('Apellido_Paterno', '')}"
            user_role = userData.get('rol_nombre', 'Usuario')
            # Verificar que los datos son válidos
            if user_id <= 0:
                logger.error("❌ Error: ID de usuario inválido")
                return
            
            if not user_role:
                logger.error("❌ Error: Rol de usuario vacío")
                return
            
            # Establecer autenticación
            self.main_controller.set_usuario_autenticado(user_id, user_name, user_role)
            
            logger.info("✅ Autenticación establecida exitosamente")
            
            # Verificación adicional con delay
            QTimer.singleShot(1000, lambda: self._verify_authentication(user_id, user_role))
            
        except Exception as e:
            logger.error(f"❌ Error estableciendo autenticación: {e}")
            import traceback
            traceback.print_exc()
    
    def _verify_authentication(self, expected_id, expected_role):
        """Verifica que la autenticación se estableció correctamente"""
        try:
            if self.main_controller:
                actual_id = self.main_controller.usuario_actual_id
                actual_role = self.main_controller.usuario_actual_rol
                
                logger.info(f"🔍 VERIFICACIÓN DE AUTENTICACIÓN:")
                logger.info(f"   Esperado: ID={expected_id}, Rol='{expected_role}'")
                logger.info(f"   Actual: ID={actual_id}, Rol='{actual_role}'")
                
                if actual_id == expected_id and actual_role == expected_role:
                    pass
                else:
                    logger.warning("⚠️ Autenticación no coincide - reintentando...")
                    # Reintentar establecer autenticación
                    user_name = f"Usuario {expected_id}"
                    self.main_controller.set_usuario_autenticado(expected_id, user_name, expected_role)
            else:
                logger.error("❌ main_controller es None durante verificación")
                
        except Exception as e:
            logger.error(f"❌ Error verificando autenticación: {e}")
    
    # Métodos públicos para QML
    @Slot()
    def showLogin(self):
        """Muestra login (para uso desde QML)"""
        logger.info("📞 showLogin() llamado desde QML")
        
        # Destruir setup engine si existe
        if self.setup_engine:
            try:
                logger.info("🗑️ Destruyendo setup_engine antes de crear login...")
                self.setup_engine.deleteLater()
                self.setup_engine = None
                logger.info("✅ Setup engine destruido")
            except Exception as e:
                logger.error(f"⚠️ Error destruyendo setup engine: {e}")
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
        logger.info("🔄 FORZANDO REINICIO COMPLETO...")
        
        # Limpiar todo
        self.main_controller = None
        self.main_engine = None
        self.login_engine = None
        self.setup_engine = None
        self.authenticated = False
        
        # Forzar garbage collection
        import gc
        gc.collect()
        
        # Recrear login después de un delay
        QTimer.singleShot(1000, self.createAndShowLogin)
        
        logger.info("✅ Reinicio completo ejecutado")


# ============================================
# ✅ FUNCIONES AUXILIARES
# ============================================

def register_qml_types():
    """Registra tipos QML con manejo de errores"""
    try:
        logger.info("📝 Registrando tipos QML...")
        
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
        
        logger.info("✅ Tipos QML registrados")
        return True
        
    except Exception as e:
        log_exception(logger, e, "Registrando tipos QML")
        return False


def setup_qml_context(engine, controller):
    """Configura contexto QML"""
    root_context = engine.rootContext()
    root_context.setContextProperty("authController", controller)
    root_context.setContextProperty("authModel", controller.auth_model)


# ============================================
# ✅ FUNCIÓN MAIN MEJORADA
# ============================================

def main():
    """
    ✅ FUNCIÓN MAIN MEJORADA
    - Validación temprana de recursos
    - Logging completo
    - Manejo robusto de errores
    - MessageBox para errores críticos
    """
    
    # ============================================
    # PASO 1: VALIDAR RECURSOS ANTES DE INICIAR
    # ============================================
    logger.info("="*60)
    logger.info("🔍 VALIDANDO RECURSOS DEL EJECUTABLE")
    logger.info("="*60)
    
    try:
        # Listar archivos disponibles (debugging)
        list_available_files(logger)
        
        # Validar que todos los recursos existan
        recursos_ok, error_msg = validate_all_resources(logger)
        
        if not recursos_ok:
            logger.error(f"❌ Validación de recursos falló:\n{error_msg}")
            show_error_message(
                "Recursos Faltantes",
                "La aplicación no puede iniciar porque faltan archivos necesarios.\n\n"
                "Reinstala la aplicación o contacta soporte.",
                error_msg
            )
            return 1
        
        logger.info("✅ Validación de recursos exitosa")
        
    except Exception as e:
        log_exception(logger, e, "Validando recursos")
        show_error_message(
            "Error de Validación",
            "No se pudieron validar los recursos del sistema.",
            str(e)
        )
        return 1
    
    # ============================================
    # PASO 2: CONFIGURAR APLICACIÓN QT
    # ============================================
    try:
        logger.info("🎨 Configurando aplicación Qt...")
        
        os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
        
        app = QGuiApplication(sys.argv)
        app.setApplicationName("Sistema de Gestión Médica")
        app.setApplicationVersion("1.0.0")
        app.setOrganizationName("Clínica Maria Inmaculada")

        try:
            if getattr(sys, 'frozen', False):
                base_path = Path(sys._MEIPASS)
            else:
                base_path = Path(__file__).parent
            
            icon_paths = [
                base_path / "Resources" / "iconos" / "Logo_de_Emergencia_Médica_RGL-removebg-preview.ico",
                base_path / "_internal" / "Resources" / "iconos" / "Logo_de_Emergencia_Médica_RGL-removebg-preview.ico",
            ]
            
            for icon_path in icon_paths:
                if icon_path.exists():
                    app.setWindowIcon(QIcon(str(icon_path)))
                    logger.info(f"✅ Icono de aplicación establecido: {icon_path}")
                    break
        except Exception as e:
            logger.warning(f"⚠️ No se pudo establecer icono: {e}")
        
        logger.info("✅ Aplicación Qt configurada")
        
    except Exception as e:
        log_exception(logger, e, "Configurando Qt")
        show_error_message(
            "Error de Inicialización",
            "No se pudo inicializar la aplicación Qt.",
            str(e)
        )
        return 1
    
    # ============================================
    # PASO 3: CONFIGURAR ICONO
    # ============================================
    try:
        icon_path = os.path.join(
            os.path.dirname(__file__), 
            "Resources/iconos/Logo_de_Emergencia_Médica_RGL-removebg-preview.ico"
        )
        
        if os.path.exists(icon_path):
            app.setWindowIcon(QIcon(icon_path))
            logger.info(f"✅ Icono cargado: {icon_path}")
        else:
            logger.warning(f"⚠️ Icono no encontrado: {icon_path}")
            
    except Exception as e:
        logger.warning(f"⚠️ Error cargando icono: {e}")
        # No crítico, continuar
    
    # ============================================
    # PASO 4: REGISTRAR TIPOS QML
    # ============================================
    try:
        logger.info("📝 Registrando tipos QML...")
        
        if not register_qml_types():
            show_error_message(
                "Error de Registro",
                "No se pudieron registrar los tipos QML.\n\nRevisa los logs.",
                "Ver logs/ClinicaApp_YYYYMMDD.log"
            )
            return 1
        
        logger.info("✅ Tipos QML registrados")
        
    except Exception as e:
        log_exception(logger, e, "Registrando tipos QML")
        show_error_message(
            "Error de Registro",
            "No se pudieron registrar los tipos QML.",
            str(e)
        )
        return 1
    
    # ============================================
    # PASO 5: CREAR CONTROLADOR DE AUTENTICACIÓN
    # ============================================
    try:
        logger.info("🔐 Creando AuthAppController...")
        
        auth_controller = AuthAppController()
        
        logger.info("✅ AuthAppController creado")
        
    except Exception as e:
        log_exception(logger, e, "Creando AuthAppController")
        show_error_message(
            "Error de Inicialización",
            "No se pudo crear el controlador de autenticación.",
            str(e)
        )
        return 1
    
    # ============================================
    # PASO 6: VERIFICAR CONFIGURACIÓN Y BASE DE DATOS
    # ============================================
    logger.info("")
    logger.info("="*60)
    logger.info("🔍 VERIFICANDO CONFIGURACIÓN Y BASE DE DATOS")
    logger.info("="*60)
    
    es_primera_vez = False
    bd_disponible = False
    
    try:
        config_manager = ConfigManager()
        es_primera_vez = config_manager.es_primera_vez()
        logger.info(f"✅ ConfigManager inicializado")
        logger.info(f"   Primera vez: {es_primera_vez}")
        
        # ✅ NUEVO: Verificar si la BD existe (solo si NO es primera vez)
        if not es_primera_vez:
            logger.info("🔍 Verificando existencia de base de datos...")
            try:
                from backend.core.db_installer import DatabaseInstaller
                db_installer = DatabaseInstaller()
                
                # ✅ LEER CONFIGURACIÓN PARA PASAR PARÁMETROS
                config = config_manager.leer_configuracion()   
                server = config.get('DB_SERVER', 'localhost\\SQLEXPRESS')
                database = config.get('DB_DATABASE', 'ClinicaMariaInmaculada')
                
                # ✅ LLAMAR CON PARÁMETROS CORRECTOS
                bd_disponible, mensaje_bd = db_installer.verificar_base_datos_existe(server, database)
                
                logger.info(f"   Base de datos disponible: {bd_disponible}")
                if not bd_disponible:
                    logger.warning(f"   ⚠️ {mensaje_bd}")
                    logger.info("   → Forzando Setup Wizard")
                else:
                    logger.info(f"   ✅ {mensaje_bd}")
            except Exception as e_bd:
                logger.error(f"   ❌ Error verificando BD: {e_bd}")
                logger.info("   → Forzando Setup Wizard por seguridad")
                bd_disponible = False
        
    except FileNotFoundError as e:
        logger.warning(f"⚠️ Archivo .env no encontrado")
        logger.info("   → Forzando Setup Wizard (primera vez)")
        es_primera_vez = True
        
    except Exception as e:
        log_exception(logger, e, "Leyendo configuración")
        logger.warning("   → Forzando Setup Wizard por seguridad")
        es_primera_vez = True
    
    # ============================================
    # PASO 7: DECIDIR QUÉ MOSTRAR (SETUP O LOGIN)
    # ============================================
    try:
        # ✅ NUEVA LÓGICA: Mostrar Setup si es primera vez O si la BD no existe
        if es_primera_vez or not bd_disponible:
            logger.info("")
            logger.info("🆕 SETUP REQUERIDO")
            if es_primera_vez:
                logger.info("   Razón: Primera ejecución detectada")
            if not bd_disponible:
                logger.info("   Razón: Base de datos no disponible")
            logger.info("   → Mostrando Setup Wizard")
            logger.info("")
            
            auth_controller.createAndShowSetupWizard()
            
        else:
            logger.info("")
            logger.info("✅ CONFIGURACIÓN Y BASE DE DATOS OK")
            logger.info("   → Mostrando Login Normal")
            logger.info("")
            
            # Crear y configurar login engine
            login_engine = QQmlApplicationEngine()
            setup_qml_context(login_engine, auth_controller)
            
            # Obtener ruta de login.qml (ya validada en PASO 1)
            login_qml = get_resource_path("login.qml", logger)
            
            # Cargar
            login_engine.load(QUrl.fromLocalFile(login_qml))
            
            # Validar carga
            if not login_engine.rootObjects():
                logger.error("❌ login.qml no se cargó correctamente")
                show_error_message(
                    "Error de Carga",
                    "No se pudo cargar la ventana de login.",
                    f"Archivo: {login_qml}"
                )
                return 1
            
            logger.info("✅ Login cargado correctamente")
        
    except Exception as e:
        log_exception(logger, e, "Mostrando interfaz inicial")
        show_error_message(
            "Error Crítico",
            "No se pudo mostrar la interfaz inicial.\n\nRevisa los logs.",
            str(e)
        )
        return 1
    
    # ============================================
    # PASO 8: EJECUTAR APLICACIÓN
    # ============================================
    logger.info("")
    logger.info("="*60)
    logger.info("🚀 APLICACIÓN INICIADA EXITOSAMENTE")
    logger.info("="*60)
    logger.info("")
    
    try:
        return app.exec()
        
    except Exception as e:
        log_exception(logger, e, "Ejecutando aplicación")
        show_error_message(
            "Error de Ejecución",
            "La aplicación encontró un error durante la ejecución.",
            str(e)
        )
        return 1


# ============================================
# ✅ PUNTO DE ENTRADA CON TRY-CATCH GLOBAL
# ============================================
if __name__ == "__main__":
    try:
        exit_code = main()
        logger.info(f"🏁 Aplicación finalizada con código: {exit_code}")
        sys.exit(exit_code)
        
    except Exception as e:
        # Último recurso: capturar cualquier excepción no manejada
        log_exception(logger, e, "EXCEPCIÓN NO CAPTURADA EN MAIN")
        
        show_error_message(
            "Error Fatal",
            "La aplicación encontró un error fatal.\n\nConsulta el archivo de logs.",
            str(e)
        )
        
        logger.critical("💥 APLICACIÓN TERMINADA POR ERROR FATAL")
        sys.exit(1)