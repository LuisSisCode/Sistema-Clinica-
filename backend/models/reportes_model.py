from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType
import json

from ..repositories.reportes_repository import ReportesRepository
from ..core.excepciones import ExceptionHandler, ValidationError, DatabaseQueryError

class ReportesModel(QObject):
    """
    Model QObject para generación de reportes con autenticación básica
    Acceso libre para todos los usuarios autenticados
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
    operacionExitosa = Signal(str)
    operacionError = Signal(str)
    
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
        
        # ✅ AUTENTICACIÓN BÁSICA - Solo para saber qué usuario accede
        self._usuario_actual_id = 0  # Dinámico, no hardcoded
        print("📊 ReportesModel inicializado - Esperando autenticación")
        
        # Referencia al AppController (se establecerá desde main.py)
        self._app_controller = None
        
        print("📊 ReportesModel inicializado con acceso libre para usuarios autenticados")
    
    # ===============================
    # ✅ MÉTODOS REQUERIDOS PARA APPCONTROLLER
    # ===============================
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """
        Establece el usuario actual para las operaciones - MÉTODO REQUERIDO por AppController
        """
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario autenticado establecido en ReportesModel: {usuario_id}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de reportes")
            else:
                print(f"⚠️ ID de usuario inválido en ReportesModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"⌚ Error estableciendo usuario en ReportesModel: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        """Property para obtener el usuario actual"""
        return self._usuario_actual_id
    
    # MÉTODO para establecer AppController
    def set_app_controller(self, app_controller):
        """Establece la referencia al AppController para acceso al PDF generator"""
        self._app_controller = app_controller
        print("🔗 AppController conectado al ReportesModel")
    
    # ===============================
    # VERIFICACIÓN DE AUTENTICACIÓN BÁSICA
    # ===============================
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica si el usuario está autenticado"""
        print(f"🔐 Verificando autenticación: usuario_id = {self._usuario_actual_id}")
        if self._usuario_actual_id <= 0:
            print("❌ Autenticación fallida: usuario no establecido")
            self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
            return False
        print(f"✅ Autenticación exitosa: usuario {self._usuario_actual_id}")
        return True
    
    # ===============================
    # PROPERTIES - Datos para QML SIN RESTRICCIONES
    # ===============================
    
    @Property(list, notify=datosReporteChanged)
    def datosReporte(self) -> List[Dict[str, Any]]:
        """Datos del reporte actual - SIN FILTROS"""
        return self._datos_reporte
    
    @Property('QVariantMap', notify=resumenChanged)
    def resumenReporte(self) -> Dict[str, Any]:
        """Resumen del reporte - SIN FILTROS"""
        return self._resumen_reporte
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas generales - SIN FILTROS"""
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
        """Valor total del reporte"""
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
    # SLOTS - Métodos SIN CONTROL DE PERMISOS
    # ===============================
    
    @Slot(int, str, str, result=bool)
    def generarReporte(self, tipo_reporte: int, fecha_desde: str, fecha_hasta: str) -> bool:
        """
        Genera reporte - Solo verifica autenticación básica
        """
        try:
            print(f"📊 INICIANDO generarReporte - Tipo: {tipo_reporte}, Usuario: {self._usuario_actual_id}")
            self._set_loading(True)
            self._set_progress(10)
            
            # ✅ VERIFICAR AUTENTICACIÓN BÁSICA
            if not self._verificar_autenticacion():
                print("❌ Verificación de autenticación falló")
                return False
            
            print(f"📊 Generando reporte tipo {tipo_reporte} - Usuario: {self._usuario_actual_id}")
            
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
                
                mensaje_resultado = f"Reporte generado: {len(datos)} registros"
                self.reporteGenerado.emit(True, mensaje_resultado, len(datos))
                
                print(f"✅ Reporte generado - Tipo: {tipo_reporte}, Registros: {len(datos)}, Usuario: {self._usuario_actual_id}")
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
        """Calcula resumen estadístico - CON VALIDACIÓN DE TIPOS"""
        try:
            print(f"🔍 DEBUGGING _calcular_resumen - Datos recibidos: {len(datos) if datos else 0}")
            
            if not datos:
                print("⚠️ No hay datos para calcular resumen")
                return {}
            
            total_registros = len(datos)
            total_valor = 0.0
            total_cantidad = 0
            
            print(f"📊 Procesando {total_registros} registros...")
            
            # Calcular todos los valores con validación de tipos
            for i, registro in enumerate(datos):
                try:
                    print(f"🔍 Registro {i}: {type(registro)} = {registro}")
                    
                    # ✅ VALIDAR QUE registro SEA UN DICCIONARIO
                    if not isinstance(registro, dict):
                        print(f"⚠️ Registro {i} no es diccionario: {type(registro)}")
                        continue
                    
                    # Obtener valor (puede estar en diferentes campos) - CON VALIDACIÓN
                    valor = 0.0
                    valor_raw = registro.get('valor', 0)
                    
                    print(f"🔍 valor_raw: {type(valor_raw)} = {valor_raw}")
                    
                    # ✅ VALIDAR TIPO DE VALOR ANTES DE PROCESAR
                    if valor_raw is not None:
                        try:
                            # Convertir a string primero si es necesario, luego a float
                            if isinstance(valor_raw, (int, float)):
                                valor = float(valor_raw)
                            elif isinstance(valor_raw, str):
                                # ✅ AQUÍ PODRÍA ESTAR EL PROBLEMA - verificar len() en string
                                valor_clean = str(valor_raw).strip()
                                if len(valor_clean) > 0 and valor_clean.replace('.', '').replace('-', '').isdigit():
                                    valor = float(valor_clean)
                                else:
                                    valor = 0.0
                            else:
                                print(f"⚠️ Tipo de valor no reconocido: {type(valor_raw)}")
                                valor = 0.0
                        except (ValueError, TypeError) as e:
                            print(f"⚠️ Error convirtiendo valor: {e}")
                            valor = 0.0
                    
                    total_valor += valor
                    print(f"✅ Valor procesado: {valor}, Total acumulado: {total_valor}")
                    
                    # Obtener cantidad - CON VALIDACIÓN
                    cantidad = 0
                    cantidad_raw = registro.get('cantidad', 0)
                    
                    print(f"🔍 cantidad_raw: {type(cantidad_raw)} = {cantidad_raw}")
                    
                    # ✅ VALIDAR TIPO DE CANTIDAD
                    if cantidad_raw is not None:
                        try:
                            if isinstance(cantidad_raw, (int, float)):
                                cantidad = int(float(cantidad_raw))
                            elif isinstance(cantidad_raw, str):
                                # ✅ VALIDAR ANTES DE USAR len()
                                cantidad_clean = str(cantidad_raw).strip()
                                if len(cantidad_clean) > 0 and cantidad_clean.replace('.', '').isdigit():
                                    cantidad = int(float(cantidad_clean))
                                else:
                                    cantidad = 0
                            else:
                                print(f"⚠️ Tipo de cantidad no reconocido: {type(cantidad_raw)}")
                                cantidad = 0
                        except (ValueError, TypeError) as e:
                            print(f"⚠️ Error convirtiendo cantidad: {e}")
                            cantidad = 0
                    
                    total_cantidad += cantidad
                    print(f"✅ Cantidad procesada: {cantidad}, Total acumulado: {total_cantidad}")
                    
                except Exception as e:
                    print(f"⚠️ Error procesando registro {i}: {e}")
                    continue
            
            promedio_valor = total_valor / total_registros if total_registros > 0 else 0.0
            
            resumen_final = {
                'totalRegistros': total_registros,
                'totalValor': total_valor,
                'totalCantidad': total_cantidad,
                'promedioValor': promedio_valor,
                'fechaGeneracion': self._fecha_desde_actual,
                'fechaHasta': self._fecha_hasta_actual,
                'tipoReporte': self._tipo_reporte_actual
            }
            
            print(f"✅ Resumen calculado: {resumen_final}")
            return resumen_final
            
        except Exception as e:
            print(f"❌ Error crítico en _calcular_resumen: {e}")
            print(f"🔍 Tipo de datos recibidos: {type(datos)}")
            if datos:
                print(f"🔍 Primer elemento: {type(datos[0]) if len(datos) > 0 else 'Sin elementos'}")
                if len(datos) > 0:
                    print(f"🔍 Contenido primer elemento: {datos[0]}")
            
            # Traceback completo para debugging
            import traceback
            traceback.print_exc()
            
            # Retornar resumen básico en caso de error
            return {
                'totalRegistros': len(datos) if datos else 0,
                'totalValor': 0.0,
                'totalCantidad': 0,
                'promedioValor': 0.0,
                'fechaGeneracion': self._fecha_desde_actual or "",
                'fechaHasta': self._fecha_hasta_actual or "",
                'tipoReporte': self._tipo_reporte_actual or 0
            }
            
        except Exception as e:
            print(f"⚠️ Error calculando resumen: {e}")
            return {}
    
    # ===============================
    # EXPORTACIÓN A PDF SIN RESTRICCIONES
    # ===============================
    
    @Slot(result=str)
    def exportarPDF(self) -> str:
        """Exporta el reporte actual a PDF - Solo verifica autenticación básica"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN BÁSICA
            if not self._verificar_autenticacion():
                return ""
            
            if not self._datos_reporte:
                self.reporteError.emit("Sin Datos", "No hay datos para exportar")
                return ""
            
            # Verificar que tenemos AppController disponible
            if not self._app_controller:
                self.reporteError.emit("Error PDF", "AppController no disponible")
                print("❌ AppController no está disponible para exportar PDF")
                return ""
            
            # Verificar que el AppController tiene el generador de PDF
            if not hasattr(self._app_controller, 'generarReportePDF'):
                self.reporteError.emit("Error PDF", "Generador de PDF no disponible")
                print("❌ Método generarReportePDF no encontrado en AppController")
                return ""
            
            print(f"📄 Iniciando exportación PDF - Usuario: {self._usuario_actual_id}")
            print(f"📄 Tipo: {self._tipo_reporte_actual}, Registros: {len(self._datos_reporte)}")
            
            # Usar todos los datos sin filtros
            datos_json = json.dumps(self._datos_reporte, default=str)
            
            # Usar AppController para generar PDF
            ruta_pdf = self._app_controller.generarReportePDF(
                datos_json,
                str(self._tipo_reporte_actual),
                self._fecha_desde_actual,
                self._fecha_hasta_actual
            )
            
            if ruta_pdf:
                mensaje_exito = f"PDF exportado exitosamente: {ruta_pdf}"
                self.operacionExitosa.emit("PDF generado correctamente")
                print(f"📄 {mensaje_exito}")
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
    
    # ===============================
    # CONSULTAS ESPECIALES SIN RESTRICCIONES
    # ===============================
    
    @Slot(result='QVariantMap')
    def obtenerResumenPeriodo(self) -> Dict[str, Any]:
        """Obtiene resumen financiero - Para cualquier usuario autenticado"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN BÁSICA
            if not self._verificar_autenticacion():
                return {}
            
            if not self._fecha_desde_actual or not self._fecha_hasta_actual:
                return {}
            
            resumen = self.repository.get_resumen_periodo(
                self._fecha_desde_actual, 
                self._fecha_hasta_actual
            )
            
            return resumen
            
        except Exception as e:
            print(f"❌ Error obteniendo resumen del período: {e}")
            return {}
    
    @Slot(int, str, str, result=bool)
    def verificarDatosDisponibles(self, tipo_reporte: int, fecha_desde: str, fecha_hasta: str) -> bool:
        """Verifica si hay datos disponibles para el reporte"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN BÁSICA
            if not self._verificar_autenticacion():
                return False
            
            return self.repository.verificar_datos_disponibles(tipo_reporte, fecha_desde, fecha_hasta)
        except Exception as e:
            print(f"❌ Error verificando datos: {e}")
            return False
    
    @Slot(result=str)
    def obtenerDatosJSON(self) -> str:
        """Obtiene los datos del reporte actual en formato JSON - SIN FILTROS"""
        try:
            return json.dumps(self._datos_reporte, default=str, ensure_ascii=False)
        except Exception as e:
            print(f"❌ Error convirtiendo a JSON: {e}")
            return "[]"
    
    @Slot(result=list)
    def obtenerTiposReportes(self) -> List[Dict[str, Any]]:
        """Obtiene lista de tipos de reportes - TODOS DISPONIBLES"""
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
    # UTILIDADES
    # ===============================
    
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
            # ✅ VERIFICAR AUTENTICACIÓN BÁSICA
            if not self._verificar_autenticacion():
                return
            
            self.repository.refresh_cache()
            self.operacionExitosa.emit("Caché refrescado correctamente")
            print("🔄 Caché de reportes refrescado")
        except Exception as e:
            print(f"❌ Error refrescando caché: {e}")
            self.operacionError.emit(f"Error refrescando caché: {str(e)}")
    
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

    def emergency_disconnect(self):
        """Desconexión de emergencia para ReportesModel"""
        try:
            print("🚨 ReportesModel: Iniciando desconexión de emergencia...")
            
            # Limpiar referencia al AppController
            self._app_controller = None
            
            # Establecer estado shutdown
            self._loading = False
            
            # Desconectar señales
            signals_to_disconnect = [
                'datosReporteChanged', 'resumenChanged', 'estadisticasChanged',
                'reporteGenerado', 'reporteError', 'operacionExitosa', 'operacionError',
                'loadingChanged', 'progressChanged'
            ]
            
            for signal_name in signals_to_disconnect:
                if hasattr(self, signal_name):
                    try:
                        getattr(self, signal_name).disconnect()
                    except:
                        pass
            
            # Limpiar datos
            self._datos_reporte = []
            self._resumen_reporte = {}
            self._estadisticas = {}
            self._tipo_reporte_actual = 0
            self._fecha_desde_actual = ""
            self._fecha_hasta_actual = ""
            self._usuario_actual_id = 0  # ✅ RESETEAR USUARIO
            
            # Anular repository
            self.repository = None
            
            print("✅ ReportesModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión ReportesModel: {e}")

# ===============================
# REGISTRO PARA QML
# ===============================

def register_reportes_model():
    """Registra el ReportesModel para uso en QML"""
    qmlRegisterType(ReportesModel, "ClinicaModels", 1, 0, "ReportesModel")
    print("📊 ReportesModel registrado para QML con acceso libre")

# Para facilitar la importación
__all__ = ['ReportesModel', 'register_reportes_model']