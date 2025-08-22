import sys
import os
import asyncio
from concurrent.futures import ThreadPoolExecutor
from PySide6.QtCore import QObject, Slot, QUrl, Property, Signal, QTimer, QThread, QThreadPool
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
from PySide6.QtQuick import QQuickItem

# IMPORTAR NUESTRO MÓDULO DE PDF
from generar_pdf import GeneradorReportesPDF

# IMPORTAR MODELS QOBJECT
from backend.models.inventario_model import InventarioModel, register_inventario_model
from backend.models.venta_model import VentaModel, register_venta_model
from backend.models.compra_model import CompraModel, register_compra_model
from backend.models.usuario_model import UsuarioModel, register_usuario_model
from backend.models.consulta_model import ConsultaModel, register_consulta_model
from backend.models.gasto_model import GastoModel, register_gasto_model
from backend.models.paciente_model import PacienteModel, register_paciente_model
from backend.models.laboratorio_model import LaboratorioModel, register_laboratorio_model
from backend.models.trabajador_model import TrabajadorModel, register_trabajador_model


class NotificationWorker(QObject):
    finished = Signal(str, str)
    
    def __init__(self):
        super().__init__()
    
    @Slot(str, str)
    def process_notification(self, title, message):
        print(f"Notificación - {title}: {message}")
        self.finished.emit(title, message)

class AppController(QObject):
    notificationProcessed = Signal(str, str)
    modelsReady = Signal()
    
    def __init__(self):
        super().__init__()
        self.thread_pool = QThreadPool()
        self.thread_pool.setMaxThreadCount(4)
        
        self.notification_worker = NotificationWorker()
        self.notification_worker.finished.connect(self.notificationProcessed)
        
        self.preload_timer = QTimer()
        self.preload_timer.setSingleShot(True)
        self.preload_timer.timeout.connect(self._preload_components)
        
        self._navigation_cache = {}
        
        # INICIALIZAR GENERADOR DE PDF
        self.pdf_generator = GeneradorReportesPDF()
        print("📄 Generador de PDF inicializado")
        
        # MODELS QOBJECT - Se inicializarán después
        self.inventario_model = None
        self.venta_model = None
        self.compra_model = None
        self.consulta_model = None
        self.paciente_model = None
        self.usuario_model = None
        self.laboratorio_model = None
        self.gasto_model = None
        self.trabajador_model = None  # ✅ AGREGAR TRABAJADOR MODEL

        
    # ===============================
    # INICIALIZACIÓN DE MODELS
    # ===============================
    
    @Slot()
    def initialize_models(self):
        """Inicializa todos los models QObject"""
        try:
            print("🚀 Inicializando Models QObject...")
            
            # Crear instancias de models
            self.inventario_model = InventarioModel()
            self.venta_model = VentaModel()
            self.compra_model = CompraModel()
            self.consulta_model = ConsultaModel()
            self.paciente_model = PacienteModel()
            self.usuario_model = UsuarioModel()
            self.gasto_model = GastoModel()

            self.laboratorio_model = LaboratorioModel()

            self.trabajador_model = TrabajadorModel()  # ✅ INICIALIZAR TRABAJADOR MODEL
            

            # Conectar signals entre models
            self._connect_models()
            
            print("✅ Models QObject inicializados correctamente")
            self.modelsReady.emit()
            
        except Exception as e:
            print(f"❌ Error inicializando models: {e}")
            import traceback
            traceback.print_exc()
    
    def _connect_models(self):
        """Conecta signals entre models para sincronización"""
        try:
            # Cuando se procesa una venta, actualizar inventario
            self.venta_model.ventaCreada.connect(self._on_venta_creada)
            
            # Cuando se procesa una compra, actualizar inventario
            self.compra_model.compraCreada.connect(self._on_compra_creada)
            
            self._establecer_usuario_por_defecto()

            # Conectar errores para mostrar en UI
            self.inventario_model.operacionError.connect(self._on_model_error)
            self.venta_model.operacionError.connect(self._on_model_error)
            self.compra_model.operacionError.connect(self._on_model_error)
            self.usuario_model.errorOccurred.connect(self._on_model_error)
            self.gasto_model.errorOccurred.connect(self._on_model_error)

            if self.consulta_model:
                self.consulta_model.operacionError.connect(self._on_model_error)
                self.consulta_model.operacionExitosa.connect(self._on_model_success)
            
            if self.paciente_model:
                self.paciente_model.errorOccurred.connect(self._on_model_error)
                self.paciente_model.successMessage.connect(self._on_model_success)
            
            if self.laboratorio_model:
                self.laboratorio_model.errorOcurrido.connect(self._on_model_error)
                self.laboratorio_model.operacionExitosa.connect(self._on_model_success)


            # ✅ CONECTAR TRABAJADOR MODEL
            if self.trabajador_model:
                self.trabajador_model.errorOccurred.connect(self._on_model_error)
                self.trabajador_model.successMessage.connect(self._on_model_success)
                
                # Conectar señales específicas del TrabajadorModel
                self.trabajador_model.trabajadorCreado.connect(self._on_trabajador_creado)
                self.trabajador_model.trabajadorActualizado.connect(self._on_trabajador_actualizado)
                self.trabajador_model.trabajadorEliminado.connect(self._on_trabajador_eliminado)
                print("🔗 TrabajadorModel conectado correctamente")
            
            # Conectar operaciones exitosas
            self.inventario_model.operacionExitosa.connect(self._on_model_success)
            self.venta_model.operacionExitosa.connect(self._on_model_success)
            self.compra_model.operacionExitosa.connect(self._on_model_success)
            self.usuario_model.successMessage.connect(self._on_model_success)
            self.gasto_model.successMessage.connect(self._on_model_success)

             # Conectar errores del GastoModel
            if self.gasto_model:
                self.gasto_model.errorOccurred.connect(self._on_model_error)
                self.gasto_model.successMessage.connect(self._on_model_success)
                
                # Conectar señales específicas del GastoModel
                self.gasto_model.gastoCreado.connect(self._on_gasto_creado)
                self.gasto_model.gastoActualizado.connect(self._on_gasto_actualizado)
                self.gasto_model.gastoEliminado.connect(self._on_gasto_eliminado)
                print("🔗 GastoModel conectado correctamente")
            
            
        except Exception as e:
            print(f"❌ Error conectando models: {e}")

    def _establecer_usuario_por_defecto(self):
        """Establece automáticamente un usuario administrador como usuario actual"""
        try:
            if not self.usuario_model:
                print("⚠️ UsuarioModel no disponible para establecer usuario por defecto")
                return
            
            # Obtener administradores disponibles
            administradores = self.usuario_model.obtenerAdministradores()
            
            if administradores and len(administradores) > 0:
                # Usar el primer administrador disponible
                admin_usuario = administradores[0]
                usuario_id = int(admin_usuario.get('usuarioId', 0))
                
                if usuario_id > 0:
                    # Establecer en VentaModel
                    if self.venta_model:
                        self.venta_model.set_usuario_actual(usuario_id)
                        print(f"👤 Usuario establecido en VentaModel: {admin_usuario.get('nombreCompleto')} (ID: {usuario_id})")
                    
                    # Establecer en CompraModel  
                    if self.compra_model:
                        self.compra_model.set_usuario_actual(usuario_id)
                        print(f"👤 Usuario establecido en CompraModel: {admin_usuario.get('nombreCompleto')} (ID: {usuario_id})")
                    if self.gasto_model:
                        # El GastoModel no tiene set_usuario_actual, pero podemos notificar que está listo
                        print(f"💰 GastoModel listo para usuario: {admin_usuario.get('nombreCompleto')} (ID: {usuario_id})")
                        
                    # AGREGAR PARA CONSULTAMODEL:
                    if self.consulta_model:
                        self.consulta_model.set_usuario_actual(usuario_id)
                        print(f"👤 Usuario establecido en ConsultaModel: {admin_usuario.get('nombreCompleto')} (ID: {usuario_id})")
                    
                    # ✅ ESTABLECER PARA TRABAJADORMODEL (si lo necesita en el futuro)
                    if self.trabajador_model:
                        print(f"👷‍♂️ TrabajadorModel listo para usuario: {admin_usuario.get('nombreCompleto')} (ID: {usuario_id})")
                else:
                    print("⚠️ Usuario administrador no tiene ID válido")
            else:
                print("⚠️ No se encontraron administradores disponibles")
                # Fallback: usar usuario ID 10 como antes
                self._establecer_usuario_fallback()
                
        except Exception as e:
            print(f"❌ Error estableciendo usuario por defecto: {e}")
            # Fallback en caso de error
            self._establecer_usuario_fallback()

    def _establecer_usuario_fallback(self):
        """Fallback: establecer usuario ID 10 como antes"""
        print("🔄 Usando fallback: Usuario ID 10")
        if self.venta_model:
            self.venta_model.set_usuario_actual(10)
        if self.compra_model:
            self.compra_model.set_usuario_actual(10)
        # AGREGAR:
        if self.consulta_model:
            self.consulta_model.set_usuario_actual(10)
    
    @Slot(int, float)
    def _on_venta_creada(self, venta_id: int, total: float):
        """Handler cuando se crea una venta"""
        print(f"💰 Venta creada - ID: {venta_id}, Total: ${total}")
        # Actualizar inventario después de venta
        if self.inventario_model:
            QTimer.singleShot(1000, self.inventario_model.refresh_productos)
    
    @Slot(int, float)
    def _on_compra_creada(self, compra_id: int, total: float):
        """Handler cuando se crea una compra"""
        print(f"📦 Compra creada - ID: {compra_id}, Total: ${total}")
        # Actualizar inventario después de compra
        if self.inventario_model:
            QTimer.singleShot(1000, self.inventario_model.refresh_productos)
    
    @Slot(bool, str)
    def _on_gasto_creado(self, success: bool, message: str):
        """Handler cuando se crea un gasto"""
        if success:
            print(f"💸 Gasto creado exitosamente: {message}")
            self.showNotification("Gasto Creado", message)
        else:
            print(f"❌ Error creando gasto: {message}")
            self.showNotification("Error", f"Error creando gasto: {message}")
    
    @Slot(bool, str)
    def _on_gasto_actualizado(self, success: bool, message: str):
        """Handler cuando se actualiza un gasto"""
        if success:
            print(f"✏️ Gasto actualizado exitosamente: {message}")
            self.showNotification("Gasto Actualizado", message)
        else:
            print(f"❌ Error actualizando gasto: {message}")
            self.showNotification("Error", f"Error actualizando gasto: {message}")
    
    @Slot(bool, str)
    def _on_gasto_eliminado(self, success: bool, message: str):
        """Handler cuando se elimina un gasto"""
        if success:
            print(f"🗑️ Gasto eliminado exitosamente: {message}")
            self.showNotification("Gasto Eliminado", message)
        else:
            print(f"❌ Error eliminando gasto: {message}")
            self.showNotification("Error", f"Error eliminando gasto: {message}")
    
    # ✅ HANDLERS PARA TRABAJADOR MODEL
    @Slot(bool, str)
    def _on_trabajador_creado(self, success: bool, message: str):
        """Handler cuando se crea un trabajador"""
        if success:
            print(f"👷‍♂️ Trabajador creado exitosamente: {message}")
            self.showNotification("Trabajador Creado", message)
        else:
            print(f"❌ Error creando trabajador: {message}")
            self.showNotification("Error", f"Error creando trabajador: {message}")
    
    @Slot(bool, str)
    def _on_trabajador_actualizado(self, success: bool, message: str):
        """Handler cuando se actualiza un trabajador"""
        if success:
            print(f"✏️ Trabajador actualizado exitosamente: {message}")
            self.showNotification("Trabajador Actualizado", message)
        else:
            print(f"❌ Error actualizando trabajador: {message}")
            self.showNotification("Error", f"Error actualizando trabajador: {message}")
    
    @Slot(bool, str)
    def _on_trabajador_eliminado(self, success: bool, message: str):
        """Handler cuando se elimina un trabajador"""
        if success:
            print(f"🗑️ Trabajador eliminado exitosamente: {message}")
            self.showNotification("Trabajador Eliminado", message)
        else:
            print(f"❌ Error eliminando trabajador: {message}")
            self.showNotification("Error", f"Error eliminando trabajador: {message}")
    
    @Slot(str)
    def _on_model_error(self, mensaje: str):
        """Handler para errores de models"""
        print(f"❌ Error Model: {mensaje}")
        self.showNotification("Error", mensaje)
    
    @Slot(str)
    def _on_model_success(self, mensaje: str):
        """Handler para operaciones exitosas"""
        print(f"✅ Éxito Model: {mensaje}")
        # Opcional: mostrar notificación de éxito
    
    # ===============================
    # GETTERS PARA MODELS (ACCESO DESDE QML)
    # ===============================
    
    @Property(QObject, notify=modelsReady)
    def inventario_model_instance(self):
        """Propiedad para acceder al InventarioModel desde QML"""
        return self.inventario_model
    
    @Property(QObject, notify=modelsReady)
    def venta_model_instance(self):
        """Propiedad para acceder al VentaModel desde QML"""
        return self.venta_model
    
    @Property(QObject, notify=modelsReady)
    def compra_model_instance(self):
        """Propiedad para acceder al CompraModel desde QML"""
        return self.compra_model
    
    @Property(QObject, notify=modelsReady)
    def consulta_model_instance(self):
        """Propiedad para acceder al ConsultaModel desde QML"""
        return self.consulta_model

    @Property(QObject, notify=modelsReady)
    def paciente_model_instance(self):
        return self.paciente_model
    
    @Property(QObject, notify=modelsReady)
    def usuario_model_instance(self):
        """Propiedad para acceder al UsuarioModel desde QML"""
        return self.usuario_model
    
    @Property(QObject, notify=modelsReady)
    def gasto_model_instance(self):
        """Propiedad para acceder al GastoModel desde QML"""
        return self.gasto_model
    

    @Property(QObject, notify=modelsReady)
    def laboratorio_model_instance(self):
        """Propiedad para acceder al LaboratorioModel desde QML"""
        return self.laboratorio_model

    # ✅ GETTER PARA TRABAJADOR MODEL
    @Property(QObject, notify=modelsReady)
    def trabajador_model_instance(self):
        """Propiedad para acceder al TrabajadorModel desde QML"""
        return self.trabajador_model

    
    # ===============================
    # MÉTODOS DE INTEGRACIÓN MODELS-PDF
    # ===============================
    
    @Slot(str, result=str)
    def generar_reporte_inventario(self, tipo_reporte: str):
        """Genera reporte PDF de inventario usando el model"""
        try:
            if not self.inventario_model:
                return ""
            
            # Obtener datos según tipo de reporte
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
            
            # Convertir a JSON y generar PDF
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json, 
                tipo_reporte, 
                "",  # fecha_desde 
                ""   # fecha_hasta
            )
            
        except Exception as e:
            print(f"❌ Error generando reporte inventario: {e}")
            return ""
    
    @Slot(str, result=str)
    def generar_reporte_ventas(self, periodo: str):
        """Genera reporte PDF de ventas usando el model"""
        try:
            if not self.venta_model:
                return ""
            
            # Obtener datos de ventas
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
            
            # Convertir a JSON y generar PDF
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json,
                f"ventas_{periodo}",
                "",  # fecha_desde
                ""   # fecha_hasta
            )
            
        except Exception as e:
            print(f"❌ Error generando reporte ventas: {e}")
            return ""
    
    @Slot(str, result=str)
    def generar_reporte_usuarios(self, tipo_reporte: str):
        """Genera reporte PDF de usuarios usando el model"""
        try:
            if not self.usuario_model:
                return ""
            
            # Obtener datos según tipo de reporte
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
            
            # Convertir a JSON y generar PDF
            import json
            datos_json = json.dumps(datos, default=str)
            
            return self.generarReportePDF(
                datos_json,
                f"usuarios_{tipo_reporte}",
                "",  # fecha_desde
                ""   # fecha_hasta
            )
            
        except Exception as e:
            print(f"❌ Error generando reporte usuarios: {e}")
            return ""
    
    # ✅ GENERAR REPORTE DE TRABAJADORES
    @Slot(str, result=str)
    def generar_reporte_trabajadores(self, tipo_reporte: str):
        """Genera reporte PDF de trabajadores usando el model"""
        try:
            if not self.trabajador_model:
                print("❌ TrabajadorModel no disponible")
                return ""
            
            # Obtener datos según tipo de reporte
            datos = []
            
            if tipo_reporte == "todos":
                # Obtener todos los trabajadores
                datos = self.trabajador_model.trabajadores
            elif tipo_reporte == "estadisticas":
                # Obtener estadísticas de trabajadores
                datos = self.trabajador_model.estadisticas
            elif tipo_reporte == "tipos":
                # Obtener tipos de trabajadores
                datos = self.trabajador_model.tiposTrabajador
            elif tipo_reporte == "laboratorio":
                # Obtener trabajadores de laboratorio
                datos = self.trabajador_model.obtenerTrabajadoresLaboratorio()
            elif tipo_reporte == "enfermeria":
                # Obtener trabajadores de enfermería
                datos = self.trabajador_model.obtenerTrabajadoresEnfermeria()
            elif tipo_reporte == "administrativos":
                # Obtener trabajadores administrativos
                datos = self.trabajador_model.obtenerTrabajadoresAdministrativos()
            elif tipo_reporte == "sin_asignaciones":
                # Obtener trabajadores sin asignaciones
                datos = self.trabajador_model.obtenerTrabajadoresSinAsignaciones()
            elif tipo_reporte == "carga_trabajo":
                # Obtener distribución de carga de trabajo
                datos = self.trabajador_model.obtenerDistribucionCarga()
            else:
                print(f"⚠️ Tipo de reporte no reconocido: {tipo_reporte}")
                return ""
            
            if not datos:
                print("⚠️ No hay datos para generar el reporte de trabajadores")
                return ""
            
            # Convertir a JSON y generar PDF
            import json
            datos_json = json.dumps(datos, default=str)
            
            # Generar PDF con el tipo específico
            pdf_path = self.generarReportePDF(
                datos_json,
                f"trabajadores_{tipo_reporte}",
                "",  # fecha_desde
                ""   # fecha_hasta
            )
            
            if pdf_path:
                print(f"✅ Reporte de trabajadores generado: {pdf_path}")
            
            return pdf_path
            
        except Exception as e:
            print(f"❌ Error generando reporte de trabajadores: {e}")
            import traceback
            traceback.print_exc()
            return ""
        
    @Slot(str, str, str, result=str)
    def generar_reporte_gastos(self, tipo_reporte: str, fecha_desde: str = "", fecha_hasta: str = ""):
        """Genera reporte PDF de gastos usando el model"""
        try:
            if not self.gasto_model:
                print("❌ GastoModel no disponible")
                return ""
            
            # Obtener datos según tipo de reporte
            datos = []
            
            if tipo_reporte == "todos":
                # Obtener todos los gastos
                datos = self.gasto_model.gastos
            elif tipo_reporte == "estadisticas":
                # Obtener estadísticas de gastos
                datos = self.gasto_model.estadisticas
            elif tipo_reporte == "tipos":
                # Obtener tipos de gastos
                datos = self.gasto_model.tiposGastos
            elif tipo_reporte == "periodo":
                # Generar reporte por período específico
                if fecha_desde and fecha_hasta:
                    # El método generarReporte del modelo actualizará internamente
                    self.gasto_model.generarReporte(fecha_desde, fecha_hasta)
                    # Usar los gastos actuales como datos
                    datos = self.gasto_model.gastos
                else:
                    print("⚠️ Fechas no proporcionadas para reporte de período")
                    return ""
            elif tipo_reporte == "dashboard":
                # Obtener datos para dashboard
                datos = self.gasto_model.obtenerDashboard()
            else:
                print(f"⚠️ Tipo de reporte no reconocido: {tipo_reporte}")
                return ""
            
            if not datos:
                print("⚠️ No hay datos para generar el reporte de gastos")
                return ""
            
            # Convertir a JSON y generar PDF
            import json
            datos_json = json.dumps(datos, default=str)
            
            # Generar PDF con el tipo específico
            pdf_path = self.generarReportePDF(
                datos_json,
                f"gastos_{tipo_reporte}",
                fecha_desde,
                fecha_hasta
            )
            
            if pdf_path:
                print(f"✅ Reporte de gastos generado: {pdf_path}")
            
            return pdf_path
            
        except Exception as e:
            print(f"❌ Error generando reporte de gastos: {e}")
            import traceback
            traceback.print_exc()
            return ""
    # ===============================
    # MÉTODOS EXISTENTES (MANTENER COMPATIBILIDAD)
    # ===============================
    
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

    # ===== GENERACIÓN DE PDF - SIMPLIFICADO =====
    @Slot(str, str, str, str, result=str)
    def generarReportePDF(self, datos_json, tipo_reporte, fecha_desde, fecha_hasta):
        """
        Genera un PDF del reporte usando el módulo dedicado generar_pdf
        
        Args:
            datos_json (str): Datos del reporte en formato JSON
            tipo_reporte (str): Tipo de reporte (1-8)
            fecha_desde (str): Fecha inicio
            fecha_hasta (str): Fecha fin
            
        Returns:
            str: Ruta del archivo PDF generado o vacío si hay error
        """
        try:
            print(f"📄 Delegando generación de PDF al módulo especializado...")
            print(f"📊 Tipo: {tipo_reporte}, Período: {fecha_desde} - {fecha_hasta}")
            
            # Validar datos antes de enviar
            if not datos_json or datos_json.strip() == "":
                print("❌ No hay datos para generar el reporte")
                return ""
            
            # Delegar al módulo especializado
            resultado = self.pdf_generator.generar_reporte_pdf(
                datos_json,
                tipo_reporte, 
                fecha_desde,
                fecha_hasta
            )
            
            if resultado:
                print(f"✅ PDF generado por módulo especializado: {resultado}")
                return resultado
            else:
                print("❌ El módulo de PDF reportó un error")
                return ""
                
        except Exception as e:
            print(f"❌ Error en AppController.generarReportePDF: {e}")
            import traceback
            traceback.print_exc()
            return ""
    
    # ===== MÉTODOS AUXILIARES PARA PDFs (OPCIONAL) =====
    @Slot(result=str)
    def obtenerDirectorioReportes(self):
        """Retorna el directorio donde se guardan los reportes"""
        return self.pdf_generator.pdf_dir
    
    @Slot(result=bool)
    def verificarDirectorioReportes(self):
        """Verifica que el directorio de reportes esté disponible"""
        try:
            return os.path.exists(self.pdf_generator.pdf_dir)
        except:
            return False
    
    @Slot(str, result=bool)
    def abrirCarpetaReportes(self, archivo_path=""):
        """Abre la carpeta de reportes en el explorador"""
        try:
            if archivo_path:
                # Abrir carpeta que contiene el archivo específico
                carpeta = os.path.dirname(archivo_path)
            else:
                # Abrir carpeta general de reportes
                carpeta = self.pdf_generator.pdf_dir
            
            # Abrir según el sistema operativo
            import platform
            if platform.system() == "Windows":
                os.startfile(carpeta)
            elif platform.system() == "Darwin":  # macOS
                os.system(f"open '{carpeta}'")
            else:  # Linux
                os.system(f"xdg-open '{carpeta}'")
            
            return True
        except Exception as e:
            print(f"❌ Error abriendo carpeta: {e}")
            return False

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
    """Registra todos los tipos QML personalizados"""
    print("📝 Registrando tipos QML...")
    
    try:
        # Registrar Models QObject
        register_inventario_model()
        register_venta_model() 
        register_compra_model()
        register_usuario_model()
        register_consulta_model()
        register_gasto_model()
        register_paciente_model()

        register_laboratorio_model()

        register_trabajador_model()  # ✅ AGREGAR TRABAJADOR MODEL
        

        print("✅ Tipos QML registrados correctamente")
        
    except Exception as e:
        print(f"❌ Error registrando tipos QML: {e}")
        raise

def register_data_models():
    """Registra todos los modelos de datos para QML"""
    try:
        print("📊 Registrando modelos de datos...")
        
        # Registrar modelos específicos
        register_trabajador_model()
        
        # Aquí puedes agregar otros modelos en el futuro:
        # register_doctor_model()
        # register_especialidad_model()
        # etc.
        
        print("✅ Modelos de datos registrados correctamente")
        
    except Exception as e:
        print(f"❌ Error registrando modelos de datos: {e}")
        raise e

def setup_qml_context(engine, controller):
    """Configura el contexto QML con controllers y models"""
    print("🔧 Configurando contexto QML...")
    
    try:
        root_context = engine.rootContext()
        
        # Registrar AppController
        root_context.setContextProperty("appController", controller)
        
        # Inicializar models después de un delay para asegurar que QML esté listo
        QTimer.singleShot(100, controller.initialize_models)
        
        print("✅ Contexto QML configurado")
        
    except Exception as e:
        print(f"❌ Error configurando contexto QML: {e}")
        raise

def setup_performance_monitoring(engine):
    """Configura monitoreo de performance para QML"""
    profiler = PerformanceProfiler()
    engine.rootContext().setContextProperty("profiler", profiler)
    print("⚡ Performance monitoring configurado")

def preload_qml_files():
    """Precarga archivos QML comunes"""
    qml_files = [
        "Dashboard.qml",
        "Farmacia.qml", 
        "Consultas.qml",
        "Laboratorio.qml",
        "Enfermeria.qml",
        "ServiciosBasicos.qml",
        "Usuario.qml",
        "Trabajadores.qml",
        "Reportes.qml",
        "Configuracion.qml"
    ]
    
    print("🔄 Precargando archivos QML...")
    loaded_count = 0
    
    for qml_file in qml_files:
        if os.path.exists(qml_file):
            print(f"  ✅ Encontrado: {qml_file}")
            loaded_count += 1
        else:
            print(f"  ⚠️ No encontrado: {qml_file}")
    
    print(f"📂 Archivos QML disponibles: {loaded_count}/{len(qml_files)}")

def main():
    print("🚀 Iniciando Sistema de Gestión Médica...")
    
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Sistema de Gestión Médica")
    app.setApplicationVersion("1.0.0")
    app.setOrganizationName("Clínica Maria Inmaculada")
    
    try:
        # 1. Registrar tipos QML personalizados
        register_qml_types()
        
        # 2. Crear engine QML
        engine = QQmlApplicationEngine()
        
        # 3. Crear controller principal
        controller = AppController()
        
        # 4. Configurar contexto QML
        setup_qml_context(engine, controller)
        
        # 5. Configurar monitoreo de performance
        setup_performance_monitoring(engine)
        
        # 6. Precargar archivos QML
        preload_qml_files()
        
        # ✅ 7. Registrar modelos de datos específicos
        register_data_models()
        
        # 8. Cargar archivo QML principal
        qml_file = os.path.join(os.path.dirname(__file__), "main.qml")
        if not os.path.exists(qml_file):
            print(f"❌ Error: Archivo QML no encontrado: {qml_file}")
            return -1
        
        engine.load(QUrl.fromLocalFile(qml_file))
        
        # 9. Verificar que se cargó correctamente
        if not engine.rootObjects():
            print("❌ Error: No se pudo cargar el archivo QML")
            return -1
        
        # 10. Iniciar precarga de componentes
        controller.startPreloading()
        
        print("✅ Sistema iniciado correctamente")
        print("🏥 Clínica Maria Inmaculada - Sistema Operativo")
        
        # 11. Ejecutar aplicación
        return app.exec()
        
    except Exception as e:
        print(f"❌ Error crítico iniciando aplicación: {e}")
        import traceback
        traceback.print_exc()
        return -1

if __name__ == "__main__":
    sys.exit(main())