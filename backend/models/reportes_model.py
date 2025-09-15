from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType
import json

from ..repositories.reportes_repository import ReportesRepository
from ..core.excepciones import ExceptionHandler, ValidationError, DatabaseQueryError

class ReportesModel(QObject):
    """
    Model QObject para generación de reportes en QML
    Conecta la interfaz QML con el ReportesRepository
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    datosReporteChanged = Signal()
    resumenChanged = Signal()
    estadisticasChanged = Signal()
    
    # Señales para operaciones
    reporteGenerado = Signal(bool, str, int)  # success, message, total_registros
    reporteError = Signal(str, str)  # title, message
    
    # Señales para UI
    loadingChanged = Signal()
    progressChanged = Signal(int)  # Progreso 0-100
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Referencias a repositories
        self.repository = ReportesRepository()
        
        # Estado interno
        self._datos_reporte: List[Dict[str, Any]] = []
        self._resumen_reporte: Dict[str, Any] = {}
        self._estadisticas: Dict[str, Any] = {}
        self._loading: bool = False
        self._progress: int = 0
        
        # Configuración del reporte actual
        self._tipo_reporte_actual: int = 0
        self._fecha_desde_actual: str = ""
        self._fecha_hasta_actual: str = ""
        
        # ✅ NUEVA: Referencia al AppController (se establecerá desde main.py)
        self._app_controller = None
        
        print("📊 ReportesModel inicializado")
    
    # ✅ NUEVO: Método para establecer la referencia al AppController
    def set_app_controller(self, app_controller):
        """Establece la referencia al AppController para acceso al PDF generator"""
        self._app_controller = app_controller
        print("🔗 AppController conectado al ReportesModel")
    
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(list, notify=datosReporteChanged)
    def datosReporte(self) -> List[Dict[str, Any]]:
        """Datos del reporte actual para mostrar en QML"""
        return self._datos_reporte
    
    @Property('QVariantMap', notify=resumenChanged)
    def resumenReporte(self) -> Dict[str, Any]:
        """Resumen del reporte actual"""
        return self._resumen_reporte
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas generales del sistema"""
        return self._estadisticas
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=progressChanged)
    def progress(self) -> int:
        """Progreso de la operación (0-100)"""
        return self._progress
    
    @Property(int, notify=datosReporteChanged)
    def totalRegistros(self) -> int:
        """Total de registros en el reporte actual"""
        return len(self._datos_reporte)
    
    @Property(float, notify=resumenChanged)
    def totalValor(self) -> float:
        """Valor total del reporte actual"""
        return float(self._resumen_reporte.get('totalValor', 0.0))
    
    @Property(str)
    def tipoReporteActual(self) -> str:
        """Descripción del tipo de reporte actual"""
        tipos = {
            1: "Ventas de Farmacia",
            2: "Inventario de Productos", 
            3: "Compras de Farmacia",
            4: "Consultas Médicas",
            5: "Análisis de Laboratorio",
            6: "Procedimientos de Enfermería",
            7: "Gastos Operativos",
            8: "Reporte Financiero Consolidado"
        }
        return tipos.get(self._tipo_reporte_actual, "Sin seleccionar")
    
    # ===============================
    # SLOTS - Métodos llamables desde QML
    # ===============================
    
    # --- GENERACIÓN DE REPORTES ---
    
    @Slot(int, str, str, result=bool)
    def generarReporte(self, tipo_reporte: int, fecha_desde: str, fecha_hasta: str) -> bool:
        """
        Genera reporte según tipo y fechas especificadas
        
        Args:
            tipo_reporte: Tipo de reporte (1-8)
            fecha_desde: Fecha inicio en formato DD/MM/YYYY
            fecha_hasta: Fecha fin en formato DD/MM/YYYY
            
        Returns:
            True si se generó exitosamente
        """
        try:
            self._set_loading(True)
            self._set_progress(10)
            
            # Validar parámetros
            if tipo_reporte < 1 or tipo_reporte > 8:
                raise ValidationError("tipo_reporte", tipo_reporte, "Tipo de reporte inválido")
            
            if not fecha_desde or not fecha_hasta:
                raise ValidationError("fechas", "", "Fechas requeridas")
            
            # Guardar configuración actual
            self._tipo_reporte_actual = tipo_reporte
            self._fecha_desde_actual = fecha_desde
            self._fecha_hasta_actual = fecha_hasta
            
            self._set_progress(30)
            
            # Verificar si hay datos disponibles
            if not self.repository.verificar_datos_disponibles(tipo_reporte, fecha_desde, fecha_hasta):
                self._datos_reporte = []
                self._resumen_reporte = {}
                self._emit_data_changed()
                
                mensaje = f"No se encontraron datos para el período {fecha_desde} - {fecha_hasta}"
                self.reporteGenerado.emit(True, mensaje, 0)
                return True
            
            self._set_progress(50)
            
            # Generar reporte según tipo
            datos = self._obtener_datos_reporte(tipo_reporte, fecha_desde, fecha_hasta)
            
            self._set_progress(80)
            
            # Procesar y almacenar datos
            if datos:
                self._datos_reporte = datos
                self._resumen_reporte = self._calcular_resumen(datos)
                self._emit_data_changed()
                
                mensaje = f"Reporte generado: {len(datos)} registros"
                self.reporteGenerado.emit(True, mensaje, len(datos))
                
                print(f"✅ Reporte generado - Tipo: {tipo_reporte}, Registros: {len(datos)}")
                return True
            else:
                self._datos_reporte = []
                self._resumen_reporte = {}
                self._emit_data_changed()
                
                self.reporteGenerado.emit(True, "No se encontraron datos", 0)
                return True
                
        except (ValidationError, DatabaseQueryError) as e:
            error_msg = str(e)
            self.reporteError.emit("Error de Validación", error_msg)
            print(f"❌ Error generando reporte: {error_msg}")
            return False
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.reporteError.emit("Error Crítico", error_msg)
            print(f"❌ Error crítico: {error_msg}")
            return False
        finally:
            self._set_progress(100)
            self._set_loading(False)
    
    def _obtener_datos_reporte(self, tipo_reporte: int, fecha_desde: str, fecha_hasta: str) -> List[Dict[str, Any]]:
        """Obtiene datos según el tipo de reporte"""
        try:
            if tipo_reporte == 1:
                return self.repository.get_reporte_ventas(fecha_desde, fecha_hasta)
            elif tipo_reporte == 2:
                return self.repository.get_reporte_inventario()
            elif tipo_reporte == 3:
                return self.repository.get_reporte_compras(fecha_desde, fecha_hasta)
            elif tipo_reporte == 4:
                return self.repository.get_reporte_consultas(fecha_desde, fecha_hasta)
            elif tipo_reporte == 5:
                return self.repository.get_reporte_laboratorio(fecha_desde, fecha_hasta)
            elif tipo_reporte == 6:
                return self.repository.get_reporte_enfermeria(fecha_desde, fecha_hasta)
            elif tipo_reporte == 7:
                return self.repository.get_reporte_gastos(fecha_desde, fecha_hasta)
            elif tipo_reporte == 8:
                return self.repository.get_reporte_consolidado(fecha_desde, fecha_hasta)
            else:
                return []
                
        except Exception as e:
            print(f"❌ Error obteniendo datos del reporte: {e}")
            raise DatabaseQueryError(f"Error consultando datos: {str(e)}")
    
    def _calcular_resumen(self, datos: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calcula resumen estadístico de los datos"""
        try:
            if not datos:
                return {}
            
            total_registros = len(datos)
            total_valor = 0.0
            total_cantidad = 0
            
            for registro in datos:
                # Obtener valor (puede estar en diferentes campos)
                valor = 0.0
                if 'valor' in registro and registro['valor'] is not None:
                    valor = float(registro['valor'])
                
                total_valor += valor
                
                # Obtener cantidad
                cantidad = 0
                if 'cantidad' in registro and registro['cantidad'] is not None:
                    cantidad = int(float(registro['cantidad']))
                
                total_cantidad += cantidad
            
            promedio_valor = total_valor / total_registros if total_registros > 0 else 0.0
            
            return {
                'totalRegistros': total_registros,
                'totalValor': total_valor,
                'totalCantidad': total_cantidad,
                'promedioValor': promedio_valor,
                'fechaGeneracion': self._fecha_desde_actual,
                'fechaHasta': self._fecha_hasta_actual,
                'tipoReporte': self._tipo_reporte_actual
            }
            
        except Exception as e:
            print(f"⚠️ Error calculando resumen: {e}")
            return {}
    
    # --- EXPORTACIÓN A PDF (CORREGIDO) ---
    
    @Slot(result=str)
    def exportarPDF(self) -> str:
        """
        Exporta el reporte actual a PDF
        
        Returns:
            Ruta del archivo PDF generado o vacío si hay error
        """
        try:
            if not self._datos_reporte:
                self.reporteError.emit("Sin Datos", "No hay datos para exportar")
                return ""
            
            # ✅ VERIFICAR que tenemos AppController disponible
            if not self._app_controller:
                self.reporteError.emit("Error PDF", "AppController no disponible")
                print("❌ AppController no está disponible para exportar PDF")
                return ""
            
            # ✅ VERIFICAR que el AppController tiene el generador de PDF
            if not hasattr(self._app_controller, 'generarReportePDF'):
                self.reporteError.emit("Error PDF", "Generador de PDF no disponible")
                print("❌ Método generarReportePDF no encontrado en AppController")
                return ""
            
            # Convertir datos a JSON para el generador de PDF
            datos_json = json.dumps(self._datos_reporte, default=str)
            
            print(f"📄 Iniciando exportación PDF - Tipo: {self._tipo_reporte_actual}, Registros: {len(self._datos_reporte)}")
            
            # ✅ USAR AppController directamente (sin importar desde main)
            ruta_pdf = self._app_controller.generarReportePDF(
                datos_json,
                str(self._tipo_reporte_actual),
                self._fecha_desde_actual,
                self._fecha_hasta_actual
            )
            
            if ruta_pdf:
                print(f"📄 PDF exportado exitosamente: {ruta_pdf}")
                return ruta_pdf
            else:
                self.reporteError.emit("Error PDF", "No se pudo generar el PDF")
                print("❌ El generador de PDF retornó una ruta vacía")
                return ""
                
        except Exception as e:
            error_msg = f"Error exportando PDF: {str(e)}"
            self.reporteError.emit("Error PDF", error_msg)
            print(f"❌ {error_msg}")
            import traceback
            traceback.print_exc()
            return ""
    
    # --- CONSULTAS ESPECIALES ---
    
    @Slot(result='QVariantMap')
    def obtenerResumenPeriodo(self) -> Dict[str, Any]:
        """Obtiene resumen financiero del período actual"""
        try:
            if not self._fecha_desde_actual or not self._fecha_hasta_actual:
                return {}
            
            return self.repository.get_resumen_periodo(
                self._fecha_desde_actual, 
                self._fecha_hasta_actual
            )
            
        except Exception as e:
            print(f"❌ Error obteniendo resumen del período: {e}")
            return {}
    
    @Slot(int, str, str, result=bool)
    def verificarDatosDisponibles(self, tipo_reporte: int, fecha_desde: str, fecha_hasta: str) -> bool:
        """Verifica si hay datos disponibles para el reporte"""
        try:
            return self.repository.verificar_datos_disponibles(tipo_reporte, fecha_desde, fecha_hasta)
        except Exception as e:
            print(f"❌ Error verificando datos: {e}")
            return False
    
    @Slot(result=str)
    def obtenerDatosJSON(self) -> str:
        """Obtiene los datos del reporte actual en formato JSON"""
        try:
            return json.dumps(self._datos_reporte, default=str, ensure_ascii=False)
        except Exception as e:
            print(f"❌ Error convirtiendo a JSON: {e}")
            return "[]"
    
    # --- UTILIDADES ---
    
    @Slot()
    def limpiarReporte(self):
        """Limpia el reporte actual"""
        self._datos_reporte = []
        self._resumen_reporte = {}
        self._tipo_reporte_actual = 0
        self._fecha_desde_actual = ""
        self._fecha_hasta_actual = ""
        self._emit_data_changed()
        print("🧹 Reporte limpiado")
    
    @Slot()
    def refrescarCache(self):
        """Refresca el caché del sistema"""
        try:
            self.repository.refresh_cache()
            print("🔄 Caché de reportes refrescado")
        except Exception as e:
            print(f"❌ Error refrescando caché: {e}")
    
    @Slot(str, result=bool)
    def validarFecha(self, fecha: str) -> bool:
        """Valida formato de fecha DD/MM/YYYY"""
        try:
            if not fecha or len(fecha) != 10:
                return False
            
            parts = fecha.split('/')
            if len(parts) != 3:
                return False
            
            dia, mes, anio = int(parts[0]), int(parts[1]), int(parts[2])
            
            return (1 <= dia <= 31 and 
                    1 <= mes <= 12 and 
                    2020 <= anio <= 2030)
        except:
            return False
    
    @Slot(str, str, result=bool)
    def validarRangoFechas(self, fecha_desde: str, fecha_hasta: str) -> bool:
        """Valida que el rango de fechas sea correcto"""
        try:
            if not self.validarFecha(fecha_desde) or not self.validarFecha(fecha_hasta):
                return False
            
            # Convertir a objetos datetime para comparar
            from datetime import datetime
            
            fecha_desde_dt = datetime.strptime(fecha_desde, "%d/%m/%Y")
            fecha_hasta_dt = datetime.strptime(fecha_hasta, "%d/%m/%Y")
            
            return fecha_desde_dt <= fecha_hasta_dt
            
        except:
            return False
    
    @Slot(result=list)
    def obtenerTiposReportes(self) -> List[Dict[str, Any]]:
        """Obtiene lista de tipos de reportes disponibles"""
        return [
            {"id": 1, "nombre": "Ventas de Farmacia", "requiere_fechas": True},
            {"id": 2, "nombre": "Inventario de Productos", "requiere_fechas": False},
            {"id": 3, "nombre": "Compras de Farmacia", "requiere_fechas": True},
            {"id": 4, "nombre": "Consultas Médicas", "requiere_fechas": True},
            {"id": 5, "nombre": "Análisis de Laboratorio", "requiere_fechas": True},
            {"id": 6, "nombre": "Procedimientos de Enfermería", "requiere_fechas": True},
            {"id": 7, "nombre": "Gastos Operativos", "requiere_fechas": True},
            {"id": 8, "nombre": "Reporte Financiero Consolidado", "requiere_fechas": True}
        ]
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()
    
    def _set_progress(self, progress: int):
        """Actualiza progreso"""
        if self._progress != progress:
            self._progress = max(0, min(100, progress))
            self.progressChanged.emit(self._progress)
    
    def _emit_data_changed(self):
        """Emite señales de cambio de datos"""
        self.datosReporteChanged.emit()
        self.resumenChanged.emit()

    def generic_emergency_disconnect(self, model_name: str):
        """Desconexión genérica para modelos sin timers complejos"""
        try:
            print(f"🚨 {model_name}: Iniciando desconexión de emergencia...")
            
            # Buscar y detener cualquier timer
            for attr_name in dir(self):
                if 'timer' in attr_name.lower() and not attr_name.startswith('__'):
                    try:
                        timer = getattr(self, attr_name)
                        if hasattr(timer, 'isActive') and hasattr(timer, 'stop') and timer.isActive():
                            timer.stop()
                            print(f"   ⏹️ {attr_name} detenido")
                    except:
                        pass
            
            # Establecer estado shutdown si existe
            if hasattr(self, '_loading'):
                self._loading = False
            if hasattr(self, '_estadoActual'):
                self._estadoActual = "shutdown"
            
            # Desconectar todas las señales posibles
            for attr_name in dir(self):
                if (not attr_name.startswith('__') and 
                    hasattr(getattr(self, attr_name), 'disconnect')):
                    try:
                        getattr(self, attr_name).disconnect()
                    except:
                        pass
            
            # Limpiar listas y diccionarios de datos
            for attr_name in dir(self):
                if not attr_name.startswith('__'):
                    try:
                        attr_value = getattr(self, attr_name)
                        if isinstance(attr_value, list) and attr_name.startswith('_'):
                            setattr(self, attr_name, [])
                        elif isinstance(attr_value, dict) and attr_name.startswith('_'):
                            setattr(self, attr_name, {})
                    except:
                        pass
            
            print(f"✅ {model_name}: Desconexión de emergencia completada")
        
        except Exception as e:
            print(f"❌ Error en desconexión {model_name}: {e}")

    def emergency_disconnect(self):
        """Desconexión de emergencia para ReportesModel"""
        try:
            print("🚨 ReportesModel: Iniciando desconexión de emergencia...")
            
            # Limpiar referencia al AppController
            self._app_controller = None
            
            # Usar desconexión genérica
            generic_emergency_disconnect(self, "ReportesModel")
            
        except Exception as e:
            print(f"❌ Error en desconexión ReportesModel: {e}")

# ===============================
# REGISTRO PARA QML
# ===============================

def register_reportes_model():
    """Registra el ReportesModel para uso en QML"""
    qmlRegisterType(ReportesModel, "ClinicaModels", 1, 0, "ReportesModel")
    print("🔗 ReportesModel registrado para QML")

# Para facilitar la importación
__all__ = ['ReportesModel', 'register_reportes_model']