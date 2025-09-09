import sys
import os
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Universal"
import json
import time
from PySide6.QtCore import QObject, Slot, QUrl, Property, Signal, QTimer, QThreadPool
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from pathlib import Path

from backend.core.login import LoginApplication
from generar_pdf import GeneradorReportesPDF

# Models
from backend.models.inventario_model import InventarioModel, register_inventario_model
from backend.models.venta_model import VentaModel, register_venta_model
from backend.models.compra_model import CompraModel, register_compra_model
from backend.models.usuario_model import UsuarioModel, register_usuario_model
from backend.models.consulta_model import ConsultaModel, register_consulta_model
from backend.models.gasto_model import GastoModel, register_gasto_model
from backend.models.paciente_model import PacienteModel, register_paciente_model
from backend.models.laboratorio_model import LaboratorioModel, register_laboratorio_model
from backend.models.trabajador_model import TrabajadorModel, register_trabajador_model
from backend.models.enfermeria_model import EnfermeriaModel, register_enfermeria_model
from backend.models.reportes_model import ReportesModel, register_reportes_model
from backend.models.dashboard_model import DashboardModel, register_dashboard_model

# Configuration Models
from backend.models.ConfiguracionModel.ConfiServiciosbasicos_model import ConfiguracionModel, register_configuracion_model
from backend.models.ConfiguracionModel.ConfiLaboratorio_model import ConfiLaboratorioModel, register_confi_laboratorio_model
from backend.models.ConfiguracionModel.ConfiEnfermeria_model import ConfiEnfermeriaModel, register_confi_enfermeria_model
from backend.models.ConfiguracionModel.ConfiConsulta_model import ConfiConsultaModel, register_confi_consulta_model
from backend.models.ConfiguracionModel.ConfiTrabajadores_model import ConfiTrabajadoresModel, register_confi_trabajadores_model

class NotificationWorker(QObject):
    finished = Signal(str, str)
    
    def __init__(self):
        super().__init__()
    
    @Slot(str, str)
    def process_notification(self, title, message):
        print(f"Notificación - {title}: {message}")
        self.finished.emit(title, message)

class LoginManager(QObject):
    loginSuccess = Signal('QVariant')
    loginCancelled = Signal()
    
    def __init__(self):
        super().__init__()
        self.login_app = None
        self.authenticated_user = None
    
    @Slot('QVariant')
    def _on_user_authenticated(self, user_data):
        self.authenticated_user = user_data
        print(f"Usuario autenticado: {user_data}")
        self.loginSuccess.emit(user_data)
    
    @Slot(bool, str, 'QVariant')
    def _on_login_result(self, success, message, user_data):
        if success:
            print(f"Login exitoso: {message}")
        else:
            print(f"Login fallido: {message}")

class AppController(QObject):
    notificationProcessed = Signal(str, str)
    modelsReady = Signal()
    
    def __init__(self, authenticated_user=None):
        super().__init__()
        self.thread_pool = QThreadPool()
        self.thread_pool.setMaxThreadCount(4)
        
        self.authenticated_user = authenticated_user
        self.current_user_id = None
        
        if authenticated_user:
            self.current_user_id = authenticated_user.get('id')
            print(f"Usuario autenticado: {authenticated_user.get('full_name')} (ID: {self.current_user_id})")
        
        self.notification_worker = NotificationWorker()
        self.notification_worker.finished.connect(self.notificationProcessed)
        
        self.preload_timer = QTimer()
        self.preload_timer.setSingleShot(True)
        self.preload_timer.timeout.connect(self._preload_components)
        
        self._navigation_cache = {}
        self.pdf_generator = GeneradorReportesPDF()
        
        # Initialize all models to None
        self._init_model_attributes()

    def _init_model_attributes(self):
        """Initialize all model attributes to None"""
        self.inventario_model = None
        self.venta_model = None
        self.compra_model = None
        self.consulta_model = None
        self.paciente_model = None
        self.usuario_model = None
        self.laboratorio_model = None
        self.gasto_model = None
        self.trabajador_model = None 
        self.enfermeria_model = None
        self.configuracion_model = None
        self.confi_laboratorio_model = None
        self.confi_enfermeria_model = None
        self.confi_consulta_model = None
        self.confi_trabajadores_model = None
        self.reportes_model = None
        self.dashboard_model = None

    # User Properties
    @Property('QVariant', constant=True)
    def currentUser(self):
        return self.authenticated_user
    
    @Slot(result=int)
    def getCurrentUserId(self):
        return self.current_user_id if self.current_user_id else 0
    
    @Slot(result=str)
    def getCurrentUserName(self):
        if self.authenticated_user:
            return self.authenticated_user.get('full_name', 'Usuario')
        return "Usuario"
    
    @Slot(result=str)
    def getCurrentUserRole(self):
        if self.authenticated_user:
            return self.authenticated_user.get('role', 'user')
        return "user"
    
    @Slot(result=str)
    def getCurrentUserEmail(self):
        if self.authenticated_user:
            return self.authenticated_user.get('email', '')
        return ""

    # Model Initialization
    @Slot()
    def initialize_models(self):
        try:
            print("Inicializando Models QObject...")
            
            # Create model instances
            self.inventario_model = InventarioModel()
            self.venta_model = VentaModel()
            self.compra_model = CompraModel()
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

            if self.reportes_model:
                self.reportes_model.set_app_controller(self)

            self._connect_models()
            self._establecer_usuario_autenticado()
            
            print("Models QObject inicializados correctamente")
            self.modelsReady.emit()
            
        except Exception as e:
            print(f"Error inicializando models: {e}")
            import traceback
            traceback.print_exc()
    
    def _establecer_usuario_autenticado(self):
        try:
            if not self.current_user_id:
                print("No hay usuario autenticado, usando fallback")
                self._establecer_usuario_fallback()
                return
            
            print(f"Estableciendo usuario autenticado en models: ID {self.current_user_id}")
            
            # Set user in models that require it
            models_with_user = [
                (self.venta_model, "VentaModel"),
                (self.compra_model, "CompraModel"),
                (self.consulta_model, "ConsultaModel"),
                (self.enfermeria_model, "EnfermeriaModel")
            ]
            
            for model, name in models_with_user:
                if model:
                    model.set_usuario_actual(self.current_user_id)
                    print(f"Usuario establecido en {name}: {self.getCurrentUserName()}")
            
            # Models ready without specific user
            ready_models = [
                (self.gasto_model, "GastoModel"),
                (self.trabajador_model, "TrabajadorModel"),
                (self.confi_laboratorio_model, "ConfiLaboratorioModel"),
                (self.confi_enfermeria_model, "ConfiEnfermeriaModel"),
                (self.confi_consulta_model, "ConfiConsultaModel"),
                (self.confi_trabajadores_model, "ConfiTrabajadoresModel")
            ]
            
            for model, name in ready_models:
                if model:
                    print(f"{name} listo para usuario: {self.getCurrentUserName()}")
            
            print(f"Usuario {self.getCurrentUserName()} establecido en todos los models")
                
        except Exception as e:
            print(f"Error estableciendo usuario autenticado: {e}")
            self._establecer_usuario_fallback()

    def _establecer_usuario_fallback(self):
        print("Usando fallback: buscando administrador disponible")
        
        try:
            if self.usuario_model:
                administradores = self.usuario_model.obtenerAdministradores()
                
                if administradores and len(administradores) > 0:
                    admin_usuario = administradores[0]
                    usuario_id = int(admin_usuario.get('usuarioId', 0))
                    
                    if usuario_id > 0:
                        self.current_user_id = usuario_id
                        
                        models = [self.venta_model, self.compra_model, self.consulta_model, self.enfermeria_model]
                        for model in models:
                            if model:
                                model.set_usuario_actual(usuario_id)
                        
                        print(f"Fallback establecido: {admin_usuario.get('nombreCompleto')} (ID: {usuario_id})")
                        return
            
            # Last resort
            print("Último recurso: Usuario ID 1")
            self.current_user_id = 1
            models = [self.venta_model, self.compra_model, self.consulta_model, self.enfermeria_model]
            for model in models:
                if model:
                    model.set_usuario_actual(1)
                
        except Exception as e:
            print(f"Error en fallback: {e}")
    
    def _connect_models(self):
        try:
            # Basic connections
            if self.venta_model:
                self.venta_model.ventaCreada.connect(self._on_venta_creada)
                self.venta_model.operacionError.connect(self._on_model_error)
                self.venta_model.operacionExitosa.connect(self._on_model_success)
            
            if self.compra_model:
                self.compra_model.compraCreada.connect(self._on_compra_creada)
                self.compra_model.operacionError.connect(self._on_model_error)
                self.compra_model.operacionExitosa.connect(self._on_model_success)

            if self.inventario_model:
                self.inventario_model.operacionError.connect(self._on_model_error)
                self.inventario_model.operacionExitosa.connect(self._on_model_success)

            # Connect all other models
            models = [
                self.usuario_model, self.gasto_model, self.consulta_model, 
                self.paciente_model, self.laboratorio_model, self.trabajador_model,
                self.enfermeria_model, self.configuracion_model, self.confi_laboratorio_model,
                self.confi_enfermeria_model, self.confi_consulta_model, self.confi_trabajadores_model
            ]

            for model in models:
                if model:
                    if hasattr(model, 'errorOccurred'):
                        model.errorOccurred.connect(self._on_model_error)
                    if hasattr(model, 'successMessage'):
                        model.successMessage.connect(self._on_model_success)
                    if hasattr(model, 'operacionError'):
                        model.operacionError.connect(self._on_model_error)
                    if hasattr(model, 'operacionExitosa'):
                        model.operacionExitosa.connect(self._on_model_success)

            if self.reportes_model:
                self.reportes_model.reporteError.connect(self._on_model_error)
                self.reportes_model.reporteGenerado.connect(self._on_reporte_generado)
                self.reportes_model.set_app_controller(self)

        except Exception as e:
            print(f"Error conectando models: {e}")

    # Event Handlers
    @Slot(int, float)
    def _on_venta_creada(self, venta_id: int, total: float):
        print(f"Venta creada por {self.getCurrentUserName()} - ID: {venta_id}, Total: ${total}")
        if self.inventario_model:
            QTimer.singleShot(1000, self.inventario_model.refresh_productos)
    
    @Slot(int, float)
    def _on_compra_creada(self, compra_id: int, total: float):
        print(f"Compra creada por {self.getCurrentUserName()} - ID: {compra_id}, Total: ${total}")
        if self.inventario_model:
            QTimer.singleShot(1000, self.inventario_model.refresh_productos)
    
    @Slot(bool, str, int)
    def _on_reporte_generado(self, success: bool, message: str, total_registros: int):
        if success:
            print(f"Reporte generado exitosamente: {message} ({total_registros} registros)")
            self.showNotification("Reporte Generado", message)
        else:
            print(f"Error generando reporte: {message}")
            self.showNotification("Error en Reporte", message)
    
    @Slot(str)
    def _on_model_error(self, mensaje: str):
        print(f"Error Model: {mensaje}")
        self.showNotification("Error", mensaje)

    @Slot(str)
    def _on_model_success(self, mensaje: str):
        print(f"Éxito Model: {mensaje}")

    # Model Properties
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
    def dashboard_model_instance(self):
        return self.dashboard_model        

    @Property(QObject, notify=modelsReady)
    def reportes_model_instance(self):
        return self.reportes_model

    # Utility Methods
    @Slot(str)
    def navigateToModule(self, module_name):
        if module_name not in self._navigation_cache:
            self._navigation_cache[module_name] = True
            print(f"Navegando a: {module_name} (cacheado)")
        else:
            print(f"Navegando a: {module_name} (desde caché)")
    
    @Slot(str, str)
    def showNotification(self, title, message):
        QTimer.singleShot(0, lambda: self.notification_worker.process_notification(title, message))
    
    @Slot()
    def openNewPatientDialog(self):
        QTimer.singleShot(0, lambda: print("Abriendo diálogo de nuevo paciente"))
    
    @Slot()
    def openNewSaleDialog(self):
        QTimer.singleShot(0, lambda: print("Abriendo diálogo de nueva venta"))
    
    @Slot()
    def startPreloading(self):
        self.preload_timer.start(100)
    
    def _preload_components(self):
        print("Precargando componentes en segundo plano...")
        
    @Slot(str, result=bool)
    def validateUserInput(self, input_text):
        return len(input_text.strip()) > 0

    # PDF Generation
    @Slot(str, str, str, str, result=str)
    def generarReportePDF(self, datos_json, tipo_reporte, fecha_desde, fecha_hasta):
        try:
            print(f"Generando PDF: {tipo_reporte}, Período: {fecha_desde} - {fecha_hasta}")
            
            if not datos_json or datos_json.strip() == "":
                print("No hay datos para generar el reporte")
                return ""
            
            resultado = self.pdf_generator.generar_reporte_pdf(
                datos_json, tipo_reporte, fecha_desde, fecha_hasta
            )
            
            if resultado:
                print(f"PDF generado: {resultado}")
                return resultado
            else:
                print("Error en generación de PDF")
                return ""
                
        except Exception as e:
            print(f"Error en generación de PDF: {e}")
            return ""
    
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

    # Report Generation Methods
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
            
            datos_json = json.dumps(datos, default=str)
            return self.generarReportePDF(datos_json, tipo_reporte, "", "")
            
        except Exception as e:
            print(f"Error generando reporte inventario: {e}")
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
            
            if not datos:
                return ""
            
            datos_json = json.dumps(datos, default=str)
            return self.generarReportePDF(datos_json, f"trabajadores_{tipo_reporte}", "", "")
            
        except Exception as e:
            print(f"Error generando reporte de trabajadores: {e}")
            return ""

class PerformanceProfiler(QObject):
    def __init__(self):
        super().__init__()
        self._start_times = {}
        
    @Slot(str)
    def startTiming(self, operation):
        import time
        self._start_times[operation] = time.time()
        
    @Slot(str)
    def endTiming(self, operation):
        import time
        if operation in self._start_times:
            elapsed = (time.time() - self._start_times[operation]) * 1000
            print(f"Operación '{operation}': {elapsed:.2f}ms")
            del self._start_times[operation]

def register_qml_types():
    print("Registrando tipos QML...")
    
    try:
        register_inventario_model()
        register_venta_model() 
        register_compra_model()
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
        print("Tipos QML registrados correctamente")
        
    except Exception as e:
        print(f"Error registrando tipos QML: {e}")
        raise

def register_data_models():
    try: 
        register_trabajador_model()
        register_confi_laboratorio_model()
        register_confi_enfermeria_model()
        register_confi_consulta_model()
        register_confi_trabajadores_model()
        register_reportes_model()
        print("Modelos de datos registrados correctamente")
        
    except Exception as e:
        print(f"Error registrando modelos de datos: {e}")
        raise e

def setup_qml_context(engine, controller):
    print("Configurando contexto QML...")
    
    try:
        root_context = engine.rootContext()
        root_context.setContextProperty("appController", controller)
        QTimer.singleShot(100, controller.initialize_models)
        print("Contexto QML configurado")
        
    except Exception as e:
        print(f"Error configurando contexto QML: {e}")
        raise

def setup_performance_monitoring(engine):
    profiler = PerformanceProfiler()
    engine.rootContext().setContextProperty("profiler", profiler)
    print("Performance monitoring configurado")

def preload_qml_files():
    qml_files = [
        "Dashboard.qml", "Farmacia.qml", "Consultas.qml", "Laboratorio.qml",
        "Enfermeria.qml", "ServiciosBasicos.qml", "Usuario.qml", "Trabajadores.qml",
        "Reportes.qml", "Configuracion.qml"
    ]
    
    print("Precargando archivos QML...")
    loaded_count = 0
    
    for qml_file in qml_files:
        if os.path.exists(qml_file):
            print(f"  Encontrado: {qml_file}")
            loaded_count += 1
        else:
            print(f"  No encontrado: {qml_file}")
    
    print(f"Archivos QML disponibles: {loaded_count}/{len(qml_files)}")

def main():
    print("Iniciando Sistema de Gestión Médica...")
    
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Sistema de Gestión Médica")
    app.setApplicationVersion("2.0.0")
    app.setOrganizationName("Clínica María Inmaculada")
    
    # FASE 1: AUTENTICACIÓN
    print("\nFASE 1: AUTENTICACIÓN")
    print("=" * 40)
    
    login_manager = LoginManager()
    authenticated_user = None
    login_success = False
    
    def on_login_success(user_data):
        nonlocal authenticated_user, login_success
        authenticated_user = user_data
        login_success = True
        print(f"Login exitoso: {user_data}")
        print("Acceso autorizado")
    
    def on_login_cancelled():
        nonlocal login_success
        login_success = False
        print("Login cancelado")
        app.quit()
    
    login_manager.loginSuccess.connect(on_login_success)
    login_manager.loginCancelled.connect(on_login_cancelled)
    
    try:
        print("Iniciando autenticación...")
        
        login_manager.login_app = LoginApplication(existing_app=app)
        
        if login_manager.login_app.backend:
            login_manager.login_app.backend.userAuthenticated.connect(login_manager._on_user_authenticated)
            login_manager.login_app.backend.loginResult.connect(login_manager._on_login_result)
        
        result = login_manager.login_app.run(execute_app=False)
        
        if result != 0:
            print("Error cargando login")
            return result
        
        print("Login cargado, esperando autenticación...")
        
        # Esperar indefinidamente hasta login exitoso o cancelación
        while not login_success:
            app.processEvents()
            time.sleep(0.05)  # Pequeña pausa para no consumir CPU al 100%
            
            # Si se cerró la ventana de login, salir
            if not login_manager.login_app:
                break
                
    except Exception as e:
        print(f"Error en login: {e}")
        return 1
    
    if not login_success or not authenticated_user:
        print("Autenticación fallida")
        return 1
    
    print(f"Login exitoso: {authenticated_user.get('full_name')}")
    
    # FASE 2: APLICACIÓN PRINCIPAL
    print("\nFASE 2: APLICACIÓN PRINCIPAL")
    print("=" * 40)
    
    try:
        register_qml_types()
        
        engine = QQmlApplicationEngine()
        controller = AppController(authenticated_user)
        
        setup_qml_context(engine, controller)
        setup_performance_monitoring(engine)
        preload_qml_files()
        register_data_models()
        
        qml_file = os.path.join(os.path.dirname(__file__), "main.qml")
        if not os.path.exists(qml_file):
            print(f"Error: Archivo QML no encontrado: {qml_file}")
            return -1
        
        engine.load(QUrl.fromLocalFile(qml_file))
        
        if not engine.rootObjects():
            print("Error: No se pudo cargar el archivo QML")
            return -1
            
        print(f"Engine QML activo con {len(engine.rootObjects())} objetos")
        
        controller.startPreloading()
        
        print("Sistema iniciado correctamente")
        print("Clínica María Inmaculada - Sistema Operativo")
        print(f"Usuario: {authenticated_user.get('full_name')} ({authenticated_user.get('role')})")
        print(f"Email: {authenticated_user.get('email')}")
        
        print("Manteniendo aplicación activa...")
        return app.exec()
        
    except Exception as e:
        print(f"Error crítico: {e}")
        import traceback
        traceback.print_exc()
        return -1
    
if __name__ == "__main__":
    sys.exit(main())