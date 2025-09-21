import sys
import os
import gc
from PySide6.QtCore import QObject, Signal, Slot, QUrl, QTimer, Property
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
        
        # Usuario autenticado
        self._usuario_autenticado_id = 0
        self._usuario_autenticado_nombre = ""
        self._usuario_autenticado_rol = ""

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
            print("🏗️ Creando instancias de modelos...")
            
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
            self.trabajador_model = TrabajadorModel()  # ← AHORA SE CREA CORRECTAMENTE
            self.enfermeria_model = EnfermeriaModel()
            self.configuracion_model = ConfiguracionModel()
            self.confi_laboratorio_model = ConfiLaboratorioModel()
            self.confi_enfermeria_model = ConfiEnfermeriaModel()
            self.confi_consulta_model = ConfiConsultaModel()
            self.confi_trabajadores_model = ConfiTrabajadoresModel()
            self.reportes_model = ReportesModel()
            self.dashboard_model = DashboardModel()
            self.auth_model = AuthModel()

            print("🔗 Conectando signals entre modelos...")
            # Conectar signals entre models
            self._connect_models()
            
            print("✅ Modelos inicializados, listos para autenticación")
            self.modelsReady.emit()
            
            # ❌ REMOVER ESTA LÍNEA - La autenticación se establecerá desde AuthAppController
            # self._establecer_usuario_autenticado()
            
        except Exception as e:
            print(f"❌ Error inicializando models: {e}")
            import traceback
            traceback.print_exc()

    @Slot()
    def cleanup(self):
        """Limpia recursos usando el sistema de emergency shutdown"""
        self.emergency_shutdown()

    @Slot()
    def emergency_shutdown(self):
        """
        Sistema de shutdown de emergencia - detiene TODO inmediatamente
        Proceso sincronizado en 3 fases para evitar retención de procesos
        """
        try:
            print("🔴 EMERGENCY SHUTDOWN INICIADO")
            
            # FASE 1: DETENER TODOS LOS TIMERS INMEDIATAMENTE
            self._stop_all_timers_immediately()
            
            # FASE 2: DESCONECTAR SEÑALES ORDENADAMENTE  
            self._disconnect_all_signals_ordered()
            
            # FASE 3: LIMPIEZA SINCRONIZADA DE RECURSOS
            self._cleanup_resources_synchronously()
            
            print("✅ EMERGENCY SHUTDOWN COMPLETADO")
            
        except Exception as e:
            print(f"⚠️ Error en emergency shutdown: {e}")
            # Forzar limpieza básica aunque falle
            self._force_basic_cleanup()

    def _stop_all_timers_immediately(self):
        """FASE 1: Detiene TODOS los timers sin excepción"""
        try:
            print("⏹️ FASE 1: Deteniendo todos los timers...")
            
            # Lista de todos los modelos
            models = [
                self.inventario_model, self.venta_model, self.compra_model,
                self.proveedor_model, self.consulta_model, self.paciente_model,
                self.usuario_model, self.gasto_model, self.laboratorio_model,
                self.trabajador_model, self.enfermeria_model, self.configuracion_model,
                self.confi_laboratorio_model, self.confi_enfermeria_model,
                self.confi_consulta_model, self.confi_trabajadores_model,
                self.reportes_model, self.dashboard_model, self.auth_model
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
                                    print(f"   ⏹️ Timer detenido: {type(model).__name__}.{timer_name}")
                        
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
                                        print(f"   ⏹️ Timer detectado detenido: {type(model).__name__}.{attr_name}")
                                except:
                                    pass
                                    
                    except Exception as e:
                        print(f"⚠️ Error deteniendo timers en {type(model).__name__}: {e}")
            
            print(f"✅ FASE 1 COMPLETA: {timer_count} timers detenidos")
            
        except Exception as e:
            print(f"❌ Error en FASE 1: {e}")

    def _disconnect_all_signals_ordered(self):
        """FASE 2: Desconecta señales en orden específico"""
        try:
            print("🔌 FASE 2: Desconectando señales...")
            
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
                    print("   🔌 Señales globales desconectadas")
            except Exception as e:
                print(f"   ⚠️ Error desconectando señales globales: {e}")
            
            # 2.2: Desconectar referencias bidireccionales
            try:
                if self.compra_model and self.proveedor_model:
                    # Romper referencia bidireccional
                    if hasattr(self.compra_model, '_proveedor_model_ref'):
                        self.compra_model._proveedor_model_ref = None
                    if hasattr(self.proveedor_model, '_compra_model_ref'):
                        self.proveedor_model._compra_model_ref = None
                    print("   🔌 Referencias bidireccionales rotas")
            except Exception as e:
                print(f"   ⚠️ Error rompiendo referencias: {e}")
            
            # 2.3: Desconectar señales internas de cada modelo
            models = [
                self.inventario_model, self.venta_model, self.compra_model,
                self.proveedor_model, self.consulta_model, self.paciente_model,
                self.usuario_model, self.gasto_model, self.laboratorio_model,
                self.trabajador_model, self.enfermeria_model, self.configuracion_model,
                self.confi_laboratorio_model, self.confi_enfermeria_model,
                self.confi_consulta_model, self.confi_trabajadores_model,
                self.reportes_model, self.dashboard_model, self.auth_model
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
                        print(f"   ⚠️ Error cleanup {type(model).__name__}: {e}")
            
            print("✅ FASE 2 COMPLETA: Señales desconectadas")
            
        except Exception as e:
            print(f"❌ Error en FASE 2: {e}")

    def _cleanup_resources_synchronously(self):
        """FASE 3: Limpieza sincronizada de recursos"""
        try:
            print("🧹 FASE 3: Limpieza sincronizada...")
            
            # 3.1: Invalidar todos los caches
            models_with_repos = [
                self.inventario_model, self.venta_model, self.compra_model,
                self.proveedor_model, self.consulta_model, self.gasto_model,
                self.laboratorio_model, self.trabajador_model, self.enfermeria_model
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
                        print(f"   ⚠️ Error limpiando cache {type(model).__name__}: {e}")
            
            # 3.2: Establecer estados de shutdown
            all_models = [
                self.inventario_model, self.venta_model, self.compra_model,
                self.proveedor_model, self.consulta_model, self.paciente_model,
                self.usuario_model, self.gasto_model, self.laboratorio_model,
                self.trabajador_model, self.enfermeria_model, self.configuracion_model,
                self.confi_laboratorio_model, self.confi_enfermeria_model,
                self.confi_consulta_model, self.confi_trabajadores_model,
                self.reportes_model, self.dashboard_model, self.auth_model
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
                        print(f"   ⚠️ Error estableciendo shutdown {type(model).__name__}: {e}")
            
            # 3.3: Usar destroy() en lugar de deleteLater()
            for model in all_models:
                if model:
                    try:
                        # Disconnect all signals before destroying
                        model.blockSignals(True)
                        # Forzar destrucción inmediata
                        model.setParent(None)
                    except Exception as e:
                        print(f"   ⚠️ Error destruyendo {type(model).__name__}: {e}")
            
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
            
            # ✅ RESETEAR USUARIO AUTENTICADO
            self._usuario_autenticado_id = 0
            self._usuario_autenticado_nombre = ""
            self._usuario_autenticado_rol = ""
            
            print("✅ FASE 3 COMPLETA: Recursos limpiados")
            
        except Exception as e:
            print(f"❌ Error en FASE 3: {e}")

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
            print(f"   ⚠️ Error limpiando datos de modelo: {e}")

    def _force_basic_cleanup(self):
        """Limpieza básica de emergencia si falla el shutdown normal"""
        try:
            print("🆘 FORZANDO LIMPIEZA BÁSICA...")
            
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
            
            print("✅ Limpieza básica completada")
            
        except Exception as e:
            print(f"❌ Error en limpieza básica: {e}")

    def _connect_models(self):
        """Conecta signals entre models para sincronización"""
        try:
            # Conexiones básicas entre modelos
            self.venta_model.ventaCreada.connect(self._on_venta_creada)
            self.compra_model.compraCreada.connect(self._on_compra_creada)
            
            # Conectar errores y éxitos
            models_with_errors = [
                self.inventario_model, self.venta_model, self.compra_model,
                self.proveedor_model, self.usuario_model, self.gasto_model,
                self.consulta_model, self.paciente_model, self.laboratorio_model,
                self.trabajador_model, self.enfermeria_model, self.configuracion_model,
                self.confi_laboratorio_model, self.confi_enfermeria_model,
                self.confi_consulta_model, self.confi_trabajadores_model
            ]
            
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

            # Conexiones específicas para modelos especializados
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

        except Exception as e:
            print(f"Error conectando models: {e}")

    def _establecer_usuario_autenticado(self):
        """Establece el usuario autenticado en todos los modelos que lo necesiten"""
        if self._usuario_autenticado_id > 0:
            print(f"👤 Estableciendo usuario {self._usuario_autenticado_id} en modelos...")
            
            # ✅ MODELOS CON VERIFICACIÓN DE AUTENTICACIÓN IMPLEMENTADA - CORREGIDO
            models_to_set = [
                (self.usuario_model, 'set_usuario_actual_con_rol'),
                (self.venta_model, 'set_usuario_actual_con_rol'),
                (self.compra_model, 'set_usuario_actual'),
                (self.consulta_model, 'set_usuario_actual_con_rol'),    # ✅ CORREGIDO
                (self.enfermeria_model, 'set_usuario_actual_con_rol'),  # ✅ CORREGIDO  
                (self.laboratorio_model, 'set_usuario_actual_con_rol'), # ✅ CORREGIDO
                (self.gasto_model, 'set_usuario_actual_con_rol'),       # ✅ CORREGIDO
                (self.trabajador_model, 'set_usuario_actual_con_rol'),  
                (self.reportes_model, 'set_usuario_actual'),                 # ✅ CORREGIDO
            ]
            
            # ✅ MODELOS QUE DEBERÍAN TENER AUTENTICACIÓN PERO AÚN NO LA TIENEN
            models_pending_auth = [
                (self.gasto_model, 'set_usuario_actual'),           
                (self.paciente_model, 'set_usuario_actual'),        
                #(self.usuario_model, 'set_usuario_actual'), # ✅ CORREGIDO
                #(self.trabajador_model, 'set_usuario_actual'),      
                (self.proveedor_model, 'set_usuario_actual'),       
                # Modelos de configuración (operaciones críticas)
                (self.configuracion_model, 'set_usuario_actual'),
                (self.confi_laboratorio_model, 'set_usuario_actual'),
                (self.confi_enfermeria_model, 'set_usuario_actual'),
                (self.confi_consulta_model, 'set_usuario_actual'),
                (self.confi_trabajadores_model, 'set_usuario_actual'),
            ]
            
            # Establecer usuario en modelos que ya tienen autenticación
            for model, method_name in models_to_set:
                if model is None:
                    print(f"  ❌ Modelo {model} es None - no se puede establecer usuario")
                    continue
                if hasattr(model, method_name):
                    try:
                        if method_name == 'set_usuario_actual_con_rol':
                            getattr(model, method_name)(self._usuario_autenticado_id, self._usuario_autenticado_rol)
                            print(f"  ✅ Usuario establecido en {type(model).__name__} con rol")
                        else:
                            getattr(model, method_name)(self._usuario_autenticado_id)
                            print(f"  ✅ Usuario establecido en {type(model).__name__}")
                    except Exception as e:
                        print(f"  ❌ Error estableciendo usuario en {type(model).__name__}: {e}")
                else:
                    print(f"  ❌ {type(model).__name__} no tiene el método {method_name}")
            
            # Intentar establecer usuario en modelos pendientes
            for model, method_name in models_pending_auth:
                if model and hasattr(model, method_name):
                    try:
                        if method_name == 'set_usuario_actual_con_rol':
                            getattr(model, method_name)(self._usuario_autenticado_id, self._usuario_autenticado_rol)
                        else:
                            getattr(model, method_name)(self._usuario_autenticado_id)
                        print(f"  ✅ Usuario establecido en {type(model).__name__} (pendiente)")
                    except Exception as e:
                        print(f"  ⚠️ {type(model).__name__} no tiene autenticación implementada")
                else:
                    if model:
                        print(f"  ⏳ {type(model).__name__} pendiente de implementar autenticación")

    @Slot(int, str, str)
    def set_usuario_autenticado(self, usuario_id: int, usuario_nombre: str, usuario_rol: str):
        """Establece el usuario autenticado CON ROL"""
        self._usuario_autenticado_id = usuario_id
        self._usuario_autenticado_nombre = usuario_nombre
        self._usuario_autenticado_rol = usuario_rol
        
        print(f"👤 Usuario autenticado: {usuario_nombre} (ID: {usuario_id}, Rol: {usuario_rol})")
        
        
        # ✅ LLAMAR AL MÉTODO CORREGIDO INMEDIATAMENTE
        self._establecer_usuario_autenticado()
        
        # ✅ ESTABLECER USUARIO CON ROL EN MODELOS ADICIONALES (REDUNDANCIA PARA GARANTIZAR)
        models_with_roles_extra = [
            (self.reportes_model, 'set_usuario_actual_con_rol'),
            (self.dashboard_model, 'set_usuario_actual_con_rol'),
        ]

        # ✅ VERIFICACIÓN ESPECÍFICA PARA REPORTES
        if self.reportes_model:
            try:
                self.reportes_model.set_usuario_actual(usuario_id)
                print(f"✅ Usuario {usuario_id} establecido específicamente en ReportesModel")
            except Exception as e:
                print(f"❌ Error estableciendo usuario en ReportesModel: {e}")

        # Establecer referencia al authModel en gastoModel para verificación de roles
        if self.gasto_model and hasattr(self, 'auth_model'):
            if hasattr(self.gasto_model, 'set_auth_model_ref'):
                self.gasto_model.set_auth_model_ref(self.auth_model)
            else:
                self.gasto_model._auth_model_ref = self.auth_model
        for model, method_name in models_with_roles_extra:
            if model and hasattr(model, method_name):
                try:
                    getattr(model, method_name)(usuario_id, usuario_rol)
                    print(f"  ✅ Rol establecido en {type(model).__name__}")
                except Exception as e:
                    print(f"  ❌ Error estableciendo rol en {type(model).__name__}: {e}")

    # Handlers para eventos específicos de modelos
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
    def _on_venta_creada(self, venta_id: int, total: float):
        if self.inventario_model:
            QTimer.singleShot(1000, self.inventario_model.refresh_productos)

    @Slot(int, float)
    def _on_compra_creada(self, compra_id: int, total: float):
        if self.inventario_model:
            QTimer.singleShot(1000, self.inventario_model.refresh_productos)

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

    @Slot(bool, str)
    def _on_procedimiento_creado(self, success: bool, message: str):
        if success:
            self.showNotification("Procedimiento Creado", message)

    @Slot(bool, str)
    def _on_procedimiento_actualizado(self, success: bool, message: str):
        if success:
            self.showNotification("Procedimiento Actualizado", message)

    @Slot(bool, str)
    def _on_procedimiento_eliminado(self, success: bool, message: str):
        if success:
            self.showNotification("Procedimiento Eliminado", message)

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
        self.showNotification("Error", mensaje)

    @Slot(str)
    def _on_model_success(self, mensaje: str):
        pass  # Opcional: mostrar notificación de éxito

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
    def auth_model_instance(self):
        return self.auth_model

    # ===============================
    # MÉTODOS DE NAVEGACIÓN Y NOTIFICACIONES
    # ===============================
    
    @Slot(str, str)
    def showNotification(self, title, message):
        QTimer.singleShot(0, lambda: self.notification_worker.process_notification(title, message))
    
    @Slot(str)
    def navigateToModule(self, module_name):
        pass  # Implementación en QML

    # ===============================
    # MÉTODOS DE GENERACIÓN DE PDF (SIN CAMBIOS)
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
            print(f"Error generando reporte de configuración: {e}")
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
            print(f"Error generando reporte de configuración de laboratorio: {e}")
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
            print(f"Error generando reporte de configuración de enfermería: {e}")
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
            print(f"Error generando reporte de configuración de consultas: {e}")
            return ""

    @Slot(str, str, str, str, result=str)
    def generarReportePDF(self, datos_json, tipo_reporte, fecha_desde, fecha_hasta):
        try:
            if not datos_json or datos_json.strip() == "":
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
    
    @Slot(str, result=bool)
    def abrirCarpetaReportes(self, archivo_path=""):
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
    """Controller principal con manejo de autenticación"""
    
    # Signals
    authenticationRequired = Signal()
    authenticationSuccess = Signal()
    loadMainApp = Signal()
    
    def __init__(self):
        super().__init__()
        self.auth_model = AuthModel()
        self.main_controller = None
        self.authenticated = False
        self.main_engine = None
        # alamcenar datos de autenticación pendientes
        self._pending_auth_data = None
        
        # Conectar signals del AuthModel
        self.auth_model.loginSuccessful.connect(self.handleLoginSuccess)
        self.auth_model.loginFailed.connect(self.handleLoginFailed)
        self.auth_model.logoutCompleted.connect(self.handleLogout)
    
    @Slot(bool, str, 'QVariantMap')
    def handleLoginSuccess(self, success: bool, message: str, userData: dict):
        if success:
            self.authenticated = True
            
            # ✅ ALMACENAR DATOS PARA ESTABLECER DESPUÉS
            self._pending_auth_data = {
                'user_id': userData.get('id', 0),
                'user_name': userData.get('Nombre', 'Usuario') + " " + userData.get('Apellido_Paterno', ''),
                'user_role': userData.get('rol_nombre', 'Usuario')
            }
            
            print(f"🔄 Datos de autenticación almacenados: {self._pending_auth_data}")
            
            # Delay para mostrar animación
            QTimer.singleShot(1000, self.initializeMainApp)
        
    @Slot(str)
    def handleLoginFailed(self, message: str):
        pass
    
    @Slot()
    def handleLogout(self):
        try:
            print("🚪 Cerrando sesión y limpiando recursos...")
            self.authenticated = False
            
            # Limpiar controlador principal si existe
            if self.main_controller:
                try:
                    self.main_controller.cleanup()
                except Exception as e:
                    print(f"⚠️ Error en cleanup del controlador: {e}")
                self.main_controller = None
            
            # Destruir motor principal si existe
            if self.main_engine:
                try:
                    self.main_engine.deleteLater()
                except Exception as e:
                    print(f"⚠️ Error destruyendo motor: {e}")
                self.main_engine = None
                
            # Emitir señal para mostrar login
            self.authenticationRequired.emit()
            print("✅ Logout completado exitosamente")
            
        except Exception as e:
            print(f"❌ Error durante logout: {e}")
            # Asegurarse de emitir la señal incluso si hay error
            self.authenticationRequired.emit()

    def initializeMainApp(self):
        try:
            if not self.main_controller:
                self.main_controller = AppController()
                
                # Crear nueva engine para main app
                self.main_engine = QQmlApplicationEngine()
                
                # Configurar contexto para app principal
                root_context = self.main_engine.rootContext()
                root_context.setContextProperty("appController", self.main_controller)
                root_context.setContextProperty("authModel", self.auth_model)
                
                # Cargar main.qml
                main_qml = os.path.join(os.path.dirname(__file__), "main.qml")
                self.main_engine.load(QUrl.fromLocalFile(main_qml))
                
                # ✅ INICIALIZAR MODELOS Y LUEGO ESTABLECER AUTENTICACIÓN
                QTimer.singleShot(500, self._initialize_models_and_auth)
                
                self.authenticationSuccess.emit()
            
        except Exception as e:
            print(f"Error inicializando app principal: {e}")
            import traceback
            traceback.print_exc()

    def _initialize_models_and_auth(self):
        """Inicializa modelos y establece autenticación en el orden correcto"""
        try:
            print("🔧 Inicializando modelos...")
            
            # 1. Inicializar modelos primero
            self.main_controller.initialize_models()
            
            # 2. Esperar un momento para que terminen de inicializarse
            QTimer.singleShot(200, self._set_pending_authentication)
            
        except Exception as e:
            print(f"❌ Error en _initialize_models_and_auth: {e}")

    def _set_pending_authentication(self):
        """Establece la autenticación pendiente después de que los modelos estén listos"""
        try:
            if self._pending_auth_data and self.main_controller:
                print(f"🔐 Estableciendo autenticación pendiente: {self._pending_auth_data}")
                
                self.main_controller.set_usuario_autenticado(
                    self._pending_auth_data['user_id'],
                    self._pending_auth_data['user_name'], 
                    self._pending_auth_data['user_role']
                )
                
                # Limpiar datos pendientes
                self._pending_auth_data = None
                print("✅ Autenticación establecida exitosamente después de inicialización")
                
        except Exception as e:
            print(f"❌ Error estableciendo autenticación pendiente: {e}")
    
    @Slot()
    def showLogin(self):
        self.authenticationRequired.emit()
    
    @Slot()
    def exitApp(self):
        QGuiApplication.quit()

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

def setup_qml_context(engine, controller):
    root_context = engine.rootContext()
    root_context.setContextProperty("authController", controller)
    root_context.setContextProperty("authModel", controller.auth_model)

def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Sistema de Gestión Médica")
    app.setApplicationVersion("1.0.0")
    app.setOrganizationName("Clínica Maria Inmaculada")
    
    try:
        register_qml_types()
        
        login_engine = QQmlApplicationEngine()
        auth_controller = AuthAppController()
        
        setup_qml_context(login_engine, auth_controller)
        
        login_qml = os.path.join(os.path.dirname(__file__), "login.qml")
        if not os.path.exists(login_qml):
            return -1
        
        login_engine.load(QUrl.fromLocalFile(login_qml))
        
        if not login_engine.rootObjects():
            return -1
        
        return app.exec()
        
    except Exception as e:
        print(f"Error crítico iniciando aplicación: {e}")
        import traceback
        traceback.print_exc()
        return -1

if __name__ == "__main__":
    sys.exit(main())