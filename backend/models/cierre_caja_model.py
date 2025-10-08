from ast import Str
from typing import List, Dict, Any, Optional, Tuple
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType
import json
import os
from datetime import datetime 
from PySide6.QtCore import QObject, Signal, Slot, QUrl, QTimer, Property, QSettings, QDateTime

from ..repositories.cierre_caja_repository import CierreCajaRepository
from ..core.excepciones import ExceptionHandler, ValidationError, DatabaseQueryError

class CierreCajaModel(QObject):
    """
    Model INDEPENDIENTE para operaciones de cierre de caja diario
    - Sin timers automáticos
    - Sin dependencias de otros modelos  
    - Consultas directas a BD bajo demanda
    - Gestiona arqueo, validaciones y generación de reportes
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    datosChanged = Signal()
    resumenChanged = Signal()
    validacionChanged = Signal()
    
    # Señales para operaciones
    cierreCompletado = Signal(bool, str)  # success, message
    pdfGenerado = Signal(str)  # ruta_archivo
    errorOccurred = Signal(str, str)  # title, message
    operacionExitosa = Signal(str)
    operacionError = Signal(str)
    cierreCompletadoChanged = Signal()
    
    # Señales para UI
    loadingChanged = Signal()
    efectivoRealChanged = Signal()
    horaInicioChanged = Signal()
    horaFinChanged = Signal()
    cierresDelDiaChanged = Signal()
    fechaActualChanged = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Repository INDEPENDIENTE
        self.repository = CierreCajaRepository()
        
        # Estado interno
        self._datos_cierre: Dict[str, Any] = {}
        self._loading: bool = False
        
        # Configuración del cierre
        self._fecha_actual: str = datetime.now().strftime("%d/%m/%Y")
        self._hora_inicio: str = "08:00"
        self._hora_fin: str = "18:00"
        self._efectivo_real: float = 0.0
        self._observaciones: str = ""

        self._resumen_estructurado: Dict[str, Any] = {}
        
        # Estado del cierre
        self._cierre_completado: bool = False
        self._cierres_del_dia: List[Dict[str, Any]] = []
        
        # Autenticación
        self._usuario_actual_id = 0
        self._usuario_actual_rol = ""
        
        # Referencia al AppController para PDFs
        self._app_controller = None
        
        print("💰 CierreCajaModel inicializado - Modo independiente")
    
    # ===============================
    # AUTENTICACIÓN
    # ===============================
    
    @Slot(int, str)
    def set_usuario_actual_con_rol(self, usuario_id: int, usuario_rol: str):
        """Establece el usuario autenticado"""
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                self._usuario_actual_rol = usuario_rol
                print(f"👤 Usuario establecido en CierreCaja: {usuario_id} ({usuario_rol})")
                self.operacionExitosa.emit(f"Usuario {usuario_id} autenticado en módulo de cierre")
            else:
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario: {e}")
            self.operacionError.emit(f"Error de autenticación: {str(e)}")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        return self._usuario_actual_id
    
    def set_app_controller(self, app_controller):
        """Establece referencia al AppController para generación de PDFs"""
        self._app_controller = app_controller
        print("🔗 AppController conectado para PDFs")
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica autenticación del usuario"""
        if self._usuario_actual_id <= 0:
            self.operacionError.emit("Usuario no autenticado")
            return False
        return True
    
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(str, notify=fechaActualChanged)
    def fechaActual(self) -> str:
        return self._fecha_actual
    
    @Property(str, notify=horaInicioChanged)
    def horaInicio(self) -> str:
        return self._hora_inicio
    
    @Property(str, notify=horaFinChanged) 
    def horaFin(self) -> str:
        return self._hora_fin
    
    @Property(float, notify=efectivoRealChanged)
    def efectivoReal(self) -> float:
        return self._efectivo_real
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        return self._loading
    
    @Property(bool, notify=cierreCompletadoChanged)
    def cierreCompletadoHoy(self) -> bool:
        return self._cierre_completado
    
    @Property(list, notify=cierresDelDiaChanged)
    def cierresDelDia(self) -> List[Dict[str, Any]]:
        return self._cierres_del_dia
    
    Property(float, notify=resumenChanged)  # Si da error, usa notify="resumenChanged"
    def totalIngresosExtras(self) -> float:
        return float(self._datos_cierre.get('resumen', {}).get('total_ingresos_extras', 0.0))

    @Property(int, notify=resumenChanged)  # Si da error, usa notify="resumenChanged"  
    def transaccionesIngresosExtras(self) -> int:
        return int(self._datos_cierre.get('resumen', {}).get('transacciones_ingresos_extras', 0))

    @Property(list, notify=datosChanged)  # Si da error, usa notify="datosChanged"
    def ingresosExtrasDetalle(self) -> List[Dict[str, Any]]:
        return self._datos_cierre.get('ingresos', {}).get('ingresos_extras', [])
    # Datos financieros calculados
    
    @Property(float, notify=resumenChanged)
    def totalIngresos(self) -> float:
        return float(self._datos_cierre.get('resumen', {}).get('total_ingresos', 0.0))
    
    @Property(float, notify=resumenChanged)
    def totalEgresos(self) -> float:
        return float(self._datos_cierre.get('resumen', {}).get('total_egresos', 0.0))
    
    @Property(float, notify=resumenChanged)
    def saldoTeorico(self) -> float:
        return float(self._datos_cierre.get('resumen', {}).get('saldo_teorico', 0.0))
    
    @Property(float, notify=resumenChanged)
    def totalFarmacia(self) -> float:
        return float(self._datos_cierre.get('resumen', {}).get('total_farmacia', 0.0))
    
    @Property(float, notify=resumenChanged)
    def totalConsultas(self) -> float:
        return float(self._datos_cierre.get('resumen', {}).get('total_consultas', 0.0))
    
    @Property(float, notify=resumenChanged)
    def totalLaboratorio(self) -> float:
        return float(self._datos_cierre.get('resumen', {}).get('total_laboratorio', 0.0))
    
    @Property(float, notify=resumenChanged)
    def totalEnfermeria(self) -> float:
        return float(self._datos_cierre.get('resumen', {}).get('total_enfermeria', 0.0))
    
    @Property(int, notify=resumenChanged)
    def transaccionesIngresos(self) -> int:
        return int(self._datos_cierre.get('resumen', {}).get('transacciones_ingresos', 0))
    
    @Property(int, notify=resumenChanged)
    def transaccionesEgresos(self) -> int:
        return int(self._datos_cierre.get('resumen', {}).get('transacciones_egresos', 0))
    
    # Validación de diferencias
    @Property(float, notify=validacionChanged)
    def diferencia(self) -> float:
        if self._efectivo_real > 0:
            return round(self._efectivo_real - self.saldoTeorico, 2)
        return 0.0
    
    @Property(str, notify=validacionChanged)
    def tipoDiferencia(self) -> str:
        diff = self.diferencia
        if abs(diff) <= 1.0:
            return "NEUTRO"
        elif diff > 0:
            return "SOBRANTE"
        else:
            return "FALTANTE"
    
    @Property(bool, notify=validacionChanged)
    def dentroDeLimite(self) -> bool:
        return abs(self.diferencia) <= 50.0
    
    @Property(bool, notify=validacionChanged)
    def requiereAutorizacion(self) -> bool:
        return abs(self.diferencia) > 50.0
    
    # Listas de movimientos
    @Property(list, notify=datosChanged)
    def ingresosDetalle(self) -> List[Dict[str, Any]]:
        return self._datos_cierre.get('ingresos', {}).get('todos', [])
    
    @Property(list, notify=datosChanged)
    def egresosDetalle(self) -> List[Dict[str, Any]]:
        return self._datos_cierre.get('egresos', {}).get('todos', [])
    
    # ===============================
    # SLOTS - Métodos principales
    # ===============================
    @Slot()
    def consultarDatos(self):
        """MÉTODO PRINCIPAL - Consulta datos de cierre según parámetros configurados"""
        if not self._verificar_autenticacion():
            return
        
        if not self._verificar_conexion():
            return
        
        try:
            self._set_loading(True)
            
            print(f"🔍 Consultando datos - Fecha: {self._fecha_actual}, Hora: {self._hora_inicio}-{self._hora_fin}")
            
            # Consultar datos directamente desde BD
            datos_cierre = self.repository.get_datos_cierre_completo(
                self._fecha_actual, 
                self._hora_inicio, 
                self._hora_fin
            )
            
            if datos_cierre:
                self._datos_cierre = datos_cierre
                
                # Generar resumen estructurado para QML
                self._resumen_estructurado = self.repository.get_resumen_por_categorias(
                    self._fecha_actual,
                    self._hora_inicio,
                    self._hora_fin
                )
                
                # Cargar también cierres de la semana
                self.cargarCierresSemana()
                
                print(f"✅ Datos obtenidos - Ingresos: Bs {self.totalIngresos:,.2f}, Egresos: Bs {self.totalEgresos:,.2f}")
                
                # Emitir señales de actualización
                self.datosChanged.emit()
                self.resumenChanged.emit()
                self._actualizar_validacion()
                
                # ✅ NUEVO: GENERAR PDF AUTOMÁTICAMENTE
                print("📄 Generando PDF del arqueo...")
                success, resultado = self._generar_pdf_arqueo_desde_datos(datos_cierre)
                
                if success:
                    print(f"✅ PDF generado exitosamente: {resultado}")
                    self.pdfGenerado.emit(resultado)
                    self.operacionExitosa.emit("Datos consultados y PDF generado correctamente")
                    
                    # Abrir PDF automáticamente
                    self._abrir_pdf_automaticamente(resultado)
                else:
                    print(f"⚠️ Error generando PDF: {resultado}")
                    self.operacionExitosa.emit("Datos consultados correctamente (PDF no generado)")
            else:
                self._datos_cierre = {}
                self._resumen_estructurado = {}
                self.operacionError.emit("No se encontraron datos para el rango especificado")
                
        except Exception as e:
            error_msg = f"Error consultando datos: {str(e)}"
            print(f"❌ {error_msg}")
            
            if "connection" in str(e).lower() or "database" in str(e).lower():
                self.emergency_disconnect()
            else:
                self.operacionError.emit(error_msg)
        finally:
            self._set_loading(False)
    ############# MÉTODOS AUXILIARES PARA PDF #############

    def _generar_pdf_arqueo_desde_datos(self, datos_cierre: Dict) -> Tuple[bool, str]:
        """Genera PDF del arqueo usando datos ya consultados"""
        try:
            # Preparar movimientos para el PDF
            movimientos_pdf = self._preparar_movimientos_para_pdf(datos_cierre)
            
            # Generar el PDF
            return self._generar_pdf_arqueo(movimientos_pdf, datos_cierre)
            
        except Exception as e:
            error_msg = f"Error en _generar_pdf_arqueo_desde_datos: {str(e)}"
            print(f"❌ {error_msg}")
            return False, error_msg

    def _preparar_movimientos_para_pdf(self, datos_cierre: Dict) -> List[Dict]:
        """Convierte datos del repository al formato que espera el PDF"""
        movimientos = []
        
        try:
            # PROCESAR INGRESOS POR CATEGORÍA
            if 'ingresos' in datos_cierre:
                for categoria, items in datos_cierre['ingresos'].items():
                    if categoria == 'todos':
                        continue
                    
                    for item in items:
                        movimiento = {
                            'id': item.get('id'),
                            'fecha': item.get('Fecha', ''),
                            'tipo': 'INGRESO',
                            'categoria': categoria.upper(),
                            'descripcion': item.get('Descripcion', item.get('TipoIngreso', '')),
                            'cantidad': item.get('Cantidad', 1),
                            'valor': float(item.get('Total', 0))
                        }
                        
                        # Campos específicos según categoría
                        if categoria == 'farmacia':
                            movimiento['id_venta'] = item.get('id')
                            movimiento['descripcion'] = item.get('Descripcion', 'Venta de medicamentos')
                        
                        elif categoria == 'consultas':
                            movimiento['id_consulta'] = item.get('id')
                            movimiento['especialidad'] = item.get('Descripcion', '').replace('Consulta - ', '')
                            movimiento['paciente_nombre'] = item.get('NombrePaciente', '')
                            movimiento['doctor_nombre'] = item.get('NombreUsuario', '')
                        
                        elif categoria == 'laboratorio':
                            movimiento['id_laboratorio'] = item.get('id')
                            movimiento['analisis'] = item.get('Descripcion', '').replace('Análisis - ', '')
                            movimiento['paciente_nombre'] = item.get('NombrePaciente', '')
                            movimiento['laboratorista'] = item.get('NombreUsuario', '')
                        
                        elif categoria == 'enfermeria':
                            movimiento['id_enfermeria'] = item.get('id')
                            movimiento['procedimiento'] = item.get('Descripcion', '').replace('Procedimiento - ', '')
                            movimiento['paciente_nombre'] = item.get('NombrePaciente', '')
                            movimiento['enfermero'] = item.get('NombreUsuario', '')
                        
                        elif categoria == 'ingresos_extras':
                            movimiento['descripcion'] = item.get('Descripcion', 'Ingreso extra')
                        
                        movimientos.append(movimiento)
            
            # PROCESAR EGRESOS
            if 'egresos' in datos_cierre and 'todos' in datos_cierre['egresos']:
                for item in datos_cierre['egresos']['todos']:
                    movimiento = {
                        'id': item.get('id'),
                        'fecha': item.get('Fecha', ''),
                        'tipo': 'EGRESO',
                        'categoria': 'GASTOS',
                        'descripcion': item.get('Descripcion', ''),
                        'cantidad': 1,
                        'valor': float(item.get('Total', 0)),
                        'tipo_gasto': item.get('TipoEgreso', 'Gasto'),
                        'proveedor': item.get('Proveedor', 'N/A')
                    }
                    movimientos.append(movimiento)
            
            print(f"✅ Movimientos preparados: {len(movimientos)} registros")
            return movimientos
            
        except Exception as e:
            print(f"❌ Error preparando movimientos: {e}")
            import traceback
            traceback.print_exc()
            return []

    def _generar_pdf_arqueo(self, movimientos: List[Dict], datos_cierre: Dict) -> Tuple[bool, str]:
        """Genera el PDF del arqueo de caja"""
        try:
            # ✅ IMPORTAR CORRECTAMENTE (ajustar path si es necesario)
            import sys
            import os
            
            # Agregar directorio raíz al path si no está
            root_dir = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
            if root_dir not in sys.path:
                sys.path.insert(0, root_dir)
            
            from generar_pdf import GeneradorReportesPDF
            import json
            
            print("✅ GeneradorReportesPDF importado correctamente")
            
            # Crear instancia del generador
            generador = GeneradorReportesPDF()
            
            # ✅ Calcular diferencia explícitamente
            saldo_teorico = datos_cierre.get('resumen', {}).get('saldo_teorico', 0)
            diferencia_calculada = round(self._efectivo_real - saldo_teorico, 2)
            
            # Preparar datos completos para el PDF (incluyendo resumen)
            datos_pdf = {
                'movimientos_completos': movimientos,
                'fecha': self._fecha_actual,
                'hora_inicio': self._hora_inicio,
                'hora_fin': self._hora_fin,
                'hora_generacion': datetime.now().strftime("%H:%M:%S"),
                'responsable': 'Sistema',
                'numero_arqueo': f"ARQ-{datetime.now().strftime('%Y%m%d-%H%M')}",
                'estado': 'COMPLETADO',
                
                # Resumen financiero
                'total_ingresos': datos_cierre.get('resumen', {}).get('total_ingresos', 0),
                'total_egresos': datos_cierre.get('resumen', {}).get('total_egresos', 0),
                'saldo_teorico': saldo_teorico,
                'efectivo_real': self._efectivo_real,
                'diferencia': diferencia_calculada
            }
            
            # Convertir a JSON
            datos_json = json.dumps(datos_pdf, ensure_ascii=False, default=str)
            
            print(f"📄 Llamando a generar_reporte_pdf con tipo 9 (Arqueo)")
            
            # ✅ LLAMAR AL MÉTODO CORRECTO CON PARÁMETROS CORRECTOS
            filepath = generador.generar_reporte_pdf(
                datos_json,
                "9",
                self._fecha_actual,
                self._fecha_actual
            )
            
            if filepath and os.path.exists(filepath):
                print(f"✅ PDF generado exitosamente: {filepath}")
                return True, filepath
            else:
                print("⚠️ PDF no generado o archivo no existe")
                return False, "No se pudo generar el archivo PDF"
                
        except ImportError as e:
            error_msg = f"Error importando generador PDF: {str(e)}"
            print(f"❌ {error_msg}")
            import traceback
            traceback.print_exc()
            return False, error_msg
            
        except Exception as e:
            error_msg = f"Error generando PDF: {str(e)}"
            print(f"❌ {error_msg}")
            import traceback
            traceback.print_exc()
            return False, error_msg
    def _abrir_pdf_automaticamente(self, filepath: str):
        """Abre el PDF generado automáticamente en el navegador"""
        try:
            import webbrowser
            import platform
            
            # Convertir ruta a formato URL
            if platform.system() == 'Windows':
                url = 'file:///' + filepath.replace('\\', '/')
            else:
                url = 'file://' + filepath
            
            webbrowser.open(url)
            print(f"🌐 PDF abierto en navegador: {url}")
            
        except Exception as e:
            print(f"⚠️ No se pudo abrir PDF automáticamente: {e}")
    
    @Slot(str, str, str)
    def generarPDFCierreEspecifico(self, fecha: str, hora_inicio: str, hora_fin: str):
        """Genera PDF de un cierre específico ya guardado (para botón Ver Cierre)"""
        try:
            print(f"📄 Generando PDF específico - Fecha: {fecha}, Horario: {hora_inicio}-{hora_fin}")
            
            self._set_loading(True)
            
            # Obtener datos del cierre específico
            datos_cierre = self.repository.get_datos_cierre_completo(
                fecha, hora_inicio, hora_fin
            )
            
            if not datos_cierre:
                self.operacionError.emit("No se encontraron datos para este cierre")
                return
            
            # Preparar y generar PDF
            movimientos = self._preparar_movimientos_para_pdf(datos_cierre)
            success, filepath = self._generar_pdf_arqueo(movimientos, datos_cierre)
            
            if success:
                print(f"✅ PDF generado: {filepath}")
                self.pdfGenerado.emit(filepath)
                self._abrir_pdf_automaticamente(filepath)
                self.operacionExitosa.emit("PDF generado correctamente")
            else:
                self.operacionError.emit(f"Error generando PDF: {filepath}")
                
        except Exception as e:
            error_msg = f"Error en generarPDFCierreEspecifico: {str(e)}"
            print(f"❌ {error_msg}")
            self.operacionError.emit(error_msg)
        finally:
            self._set_loading(False)
        
    @Slot(str)
    def cambiarFecha(self, nueva_fecha: str):
        """Cambia la fecha de consulta"""
        if self._validar_fecha(nueva_fecha):
            self._fecha_actual = nueva_fecha
            self.fechaActualChanged.emit()
            self._verificar_cierre_previo()
            print(f"📅 Fecha cambiada a: {nueva_fecha}")
        else:
            self.operacionError.emit("Formato de fecha inválido (DD/MM/YYYY)")
    
    @Slot(str)
    def establecerHoraInicio(self, hora: str):
        """Establece hora de inicio"""
        if self._validar_hora(hora):
            self._hora_inicio = hora
            self.horaInicioChanged.emit()
            print(f"🕐 Hora inicio: {hora}")
        else:
            self.operacionError.emit("Formato de hora inválido (HH:MM)")
    
    @Slot(str) 
    def establecerHoraFin(self, hora: str):
        """Establece hora de fin"""
        if self._validar_hora(hora):
            self._hora_fin = hora
            self.horaFinChanged.emit()
            print(f"🕐 Hora fin: {hora}")
        else:
            self.operacionError.emit("Formato de hora inválido (HH:MM)")
    
    @Slot(float)
    def establecerEfectivoReal(self, monto: float):
        """Establece el efectivo real contado"""
        try:
            if monto < 0:
                self.operacionError.emit("El monto no puede ser negativo")
                return
            
            self._efectivo_real = round(monto, 2)
            self.efectivoRealChanged.emit()
            self._actualizar_validacion()
            
            print(f"💵 Efectivo real: Bs {self._efectivo_real:,.2f}")
            
        except Exception as e:
            self.operacionError.emit(f"Error estableciendo efectivo: {str(e)}")
    
    @Slot()
    def cargarCierresDelDia(self):
        """Carga cierres realizados en el día actual"""
        try:
            if not self._verificar_autenticacion():
                return
            
            cierres = self.repository.get_cierres_por_fecha(self._fecha_actual)
            self._cierres_del_dia = cierres
            self.cierresDelDiaChanged.emit()
            
            print(f"📋 Cierres del día cargados: {len(cierres)}")
            
        except Exception as e:
            print(f"❌ Error cargando cierres del día: {e}")
    
    # ===============================
    # VALIDACIÓN Y CIERRE
    # ===============================
    
    @Slot(result=bool)
    def validarCierre(self) -> bool:
        """Valida si se puede realizar el cierre"""
        try:
            print(f"🔍 VALIDACIÓN - Usuario autenticado: {self._verificar_autenticacion()}")
            if not self._verificar_autenticacion():
                return False
            
            print(f"🔍 VALIDACIÓN - Efectivo real: {self._efectivo_real}")
            if self._efectivo_real <= 0:
                self.operacionError.emit("Debe ingresar el efectivo real contado")
                return False
            
            print(f"🔍 VALIDACIÓN - Datos cierre disponibles: {bool(self._datos_cierre)}")
            if not self._datos_cierre:
                self.operacionError.emit("Debe consultar los datos antes de cerrar")
                return False
            
            cierre_previo = self.repository.verificar_cierre_previo(self._fecha_actual, self._hora_inicio, self._hora_fin)
            print(f"🔍 VALIDACIÓN - Cierre previo existe para {self._hora_inicio}-{self._hora_fin}: {cierre_previo}")
            if cierre_previo:
                self.operacionError.emit(f"Ya existe un cierre para el horario {self._hora_inicio}-{self._hora_fin}")
                return False
            
            diferencia_abs = abs(self.diferencia)
            print(f"🔍 VALIDACIÓN - Diferencia absoluta: {diferencia_abs}")
            if diferencia_abs > 1000.0:
                self.operacionError.emit("Diferencia demasiado grande, verifique los datos")
                return False
            
            print("✅ VALIDACIÓN EXITOSA")
            return True
                
        except Exception as e:
            print(f"❌ Error en validación: {e}")
            self.operacionError.emit(f"Error validando cierre: {str(e)}")
            return False
    
    @Slot(str)
    def completarCierre(self, observaciones: str = ""):
        """Completa el cierre de caja"""
        try:
            if not self.validarCierre():
                return
                
            self._set_loading(True)
            
            # Preparar datos del cierre
            datos_cierre = {
                'Fecha': self._convertir_fecha_bd(self._fecha_actual),
                'HoraInicio': self._hora_inicio,
                'HoraFin': self._hora_fin,
                'EfectivoReal': self._efectivo_real,
                'SaldoTeorico': self.saldoTeorico,
                'Diferencia': self.diferencia,
                'IdUsuario': self._usuario_actual_id,
                'FechaCierre': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                'Observaciones': observaciones or self._generar_observaciones_automaticas()
            }
            
            # Guardar en BD
            if self.repository.guardar_cierre_caja(datos_cierre):
                self._cierre_completado = True
                self.cierreCompletadoChanged.emit()
                
                # Recargar cierres del día
                self.cargarCierresDelDia()
                
                mensaje = f"Cierre completado - {self._hora_inicio} a {self._hora_fin}"
                self.cierreCompletado.emit(True, mensaje)
                self.operacionExitosa.emit("Cierre guardado en base de datos")
                print(f"✅ Cierre completado - Usuario: {self._usuario_actual_id}")
            else:
                raise Exception("Error guardando cierre en base de datos")
                
        except Exception as e:
            error_msg = f"Error completando cierre: {str(e)}"
            self.cierreCompletado.emit(False, error_msg)
            self.operacionError.emit(error_msg)
            print(f"❌ {error_msg}")
        finally:
            self._set_loading(False)
    
    # ===============================
    # GENERACIÓN DE PDF
    # ===============================
    
    @Slot(result=str)
    def generarPDFArqueo(self) -> str:
        """Genera PDF del arqueo con datos detallados"""
        try:
            if not self._verificar_autenticacion():
                return ""
            
            if not self._datos_cierre:
                self.operacionError.emit("Debe consultar los datos antes de generar PDF")
                return ""
            
            if not self._app_controller:
                self.errorOccurred.emit("Error PDF", "Generador de PDF no disponible")
                return ""
            
            # Generar datos estructurados para PDF
            datos_pdf = self.repository.generar_datos_pdf_arqueo(
                self._fecha_actual,
                self._hora_inicio,
                self._hora_fin,
                self._efectivo_real,
                self._observaciones
            )
            
            if not datos_pdf:
                self.errorOccurred.emit("Error PDF", "No se pudieron estructurar los datos")
                return ""
            
            # Convertir a JSON y generar PDF
            datos_json = json.dumps(datos_pdf, default=str)
            
            ruta_pdf = self._app_controller.generarReportePDF(
                datos_json,
                "9",  # Tipo arqueo de caja
                self._fecha_actual,
                self._fecha_actual
            )
            
            if ruta_pdf:
                self.pdfGenerado.emit(ruta_pdf)
                self.operacionExitosa.emit("PDF del arqueo generado correctamente")
                print(f"📄 PDF generado: {ruta_pdf}")
                return ruta_pdf
            else:
                self.errorOccurred.emit("Error PDF", "No se pudo generar el archivo")
                return ""
                
        except Exception as e:
            error_msg = f"Error generando PDF: {str(e)}"
            self.errorOccurred.emit("Error PDF", error_msg)
            print(f"❌ {error_msg}")
            return ""
    
    # ===============================
    # MÉTODOS DE CONSULTA ADICIONALES
    # ===============================
    @Property(str, notify=fechaActualChanged)
    def fechaSeleccionada(self) -> str:
        """Alias para fechaActual - compatibilidad QML"""
        return self._fecha_actual

    @Property(float, notify=validacionChanged)
    def diferenciaCaja(self) -> float:
        """Alias para diferencia - compatibilidad QML"""
        return self.diferencia

    @Property(int, notify=resumenChanged)
    def totalTransacciones(self) -> int:
        """Total de transacciones (ingresos + egresos)"""
        return self.transaccionesIngresos + self.transaccionesEgresos

    @Property('QVariantMap', notify=datosChanged)
    def resumenRango(self) -> Dict[str, Any]:
        """Resumen estructurado para el QML"""
        return self._resumen_estructurado

    # NUEVOS MÉTODOS para compatibilidad con QML
    @Slot()
    def consultarMovimientosPorRango(self):
        """Alias para consultarDatos - compatibilidad QML"""
        self.consultarDatos()

    @Slot(str)
    def establecerFecha(self, fecha: str):
        """Alias para cambiarFecha - compatibilidad QML"""
        self.cambiarFecha(fecha)

    @Slot(result=str)
    def generarPDFCierre(self) -> str:
        """Alias para generarPDFArqueo - compatibilidad QML"""
        return self.generarPDFArqueo()

    @Slot(str)
    def realizarCierreCompleto(self, observaciones: str = ""):
        """Alias para completarCierre - compatibilidad QML"""
        self.completarCierre(observaciones)

    @Slot()
    def cargarCierresSemana(self):
        """Carga cierres de toda la semana actual"""
        try:
            if not self._verificar_autenticacion():
                return
            
            print("📅 Iniciando carga de cierres de semana...")
            
            cierres_semana = self.repository.get_cierres_semana_actual(self._fecha_actual)
            self._cierres_del_dia = cierres_semana
            self.cierresDelDiaChanged.emit()
            
            print(f"📅 Cierres de la semana cargados: {len(cierres_semana)}")
            
        except Exception as e:
            print(f"❌ ERROR CRÍTICO en cargarCierresSemana: {e}")
            print(f"❌ Tipo de error: {type(e).__name__}")
            # NO emitir señales si hay error
            self._cierres_del_dia = []  # Lista vacía por seguridad

    @Slot(result='QVariantMap')
    def obtenerEstadisticasDia(self) -> Dict[str, Any]:
        try:
            if not self._datos_cierre:
                return {}
            
            resumen = self._datos_cierre.get('resumen', {})
            
            return {
                'promedio_transaccion_ingreso': round(
                    self.totalIngresos / max(self.transaccionesIngresos, 1), 2
                ),
                'promedio_transaccion_egreso': round(
                    self.totalEgresos / max(self.transaccionesEgresos, 1), 2
                ),
                'porcentaje_farmacia': round(
                    (self.totalFarmacia / max(self.totalIngresos, 1)) * 100, 1
                ),
                'porcentaje_consultas': round(
                    (self.totalConsultas / max(self.totalIngresos, 1)) * 100, 1
                ),
                'porcentaje_laboratorio': round(
                    (self.totalLaboratorio / max(self.totalIngresos, 1)) * 100, 1
                ),
                'porcentaje_enfermeria': round(
                    (self.totalEnfermeria / max(self.totalIngresos, 1)) * 100, 1
                ),
                'porcentaje_ingresos_extras': round(  # NUEVO
                    (self.totalIngresosExtras / max(self.totalIngresos, 1)) * 100, 1
                ),
                'margin_operativo': round(
                    ((self.totalIngresos - self.totalEgresos) / max(self.totalIngresos, 1)) * 100, 1
                )
            }
            
        except Exception as e:
            print(f"❌ Error obteniendo estadísticas: {e}")
            return {}
        
    @Slot()
    def limpiarDatos(self):
        """Limpia todos los datos del cierre"""
        self._datos_cierre = {}
        self._efectivo_real = 0.0
        self._observaciones = ""
        
        self.datosChanged.emit()
        self.resumenChanged.emit()
        self.efectivoRealChanged.emit()
        self.validacionChanged.emit()
        
        print("🧹 Datos del cierre limpiados")
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _verificar_cierre_previo(self):
        """Verifica si ya hay un cierre para la fecha actual"""
        try:
            self._cierre_completado = self.repository.verificar_cierre_previo(self._fecha_actual)
            self.cierreCompletadoChanged.emit()
        except:
            self._cierre_completado = False
    
    def _actualizar_validacion(self):
        """Actualiza validación de diferencias"""
        if self._efectivo_real > 0:
            self.validacionChanged.emit()
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()
    
    def _validar_fecha(self, fecha: str) -> bool:
        """Valida formato DD/MM/YYYY"""
        try:
            datetime.strptime(fecha, "%d/%m/%Y")
            return True
        except:
            return False
    
    def _validar_hora(self, hora: str) -> bool:
        """Valida formato HH:MM"""
        try:
            datetime.strptime(hora, "%H:%M")
            return True
        except:
            return False
    
    def _convertir_fecha_bd(self, fecha: str) -> str:
        """Convierte DD/MM/YYYY a YYYY-MM-DD"""
        try:
            partes = fecha.split('/')
            return f"{partes[2]}-{partes[1]:0>2}-{partes[0]:0>2}"
        except:
            return datetime.now().strftime("%Y-%m-%d")
    
    def _generar_observaciones_automaticas(self) -> str:
        """Genera observaciones automáticas"""
        if self.tipoDiferencia == "NEUTRO":
            return "Arqueo balanceado correctamente"
        elif self.tipoDiferencia == "SOBRANTE":
            return f"Sobrante de Bs {abs(self.diferencia):.2f}"
        else:
            return f"Faltante de Bs {abs(self.diferencia):.2f}"
    
    # ===============================
    # CLEANUP PARA SHUTDOWN
    # ===============================
    
    def emergency_disconnect(self):
        """
        Desconexión segura SIN romper la interfaz QML
        """
        try:
            print("🚨 CierreCajaModel: Iniciando desconexión de emergencia SEGURA...")
            
            # ✅ IMPORTANTE: NO anular referencias críticas inmediatamente
            # Solo marcar como desconectado
            self._disconnected = True
            
            # Detener timer inmediatamente
            if hasattr(self, '_refresh_timer') and self._refresh_timer and self._refresh_timer.isActive():
                self._refresh_timer.stop()
                print("   ⏹️ Refresh timer detenido")
            
            # ✅ NUEVO: Emitir señal de desconexión en lugar de romper todo
            try:
                self.operacionError.emit("Módulo temporalmente desconectado - reconectando...")
            except:
                pass
            
            # ✅ IMPORTANTE: NO bloquear señales - esto rompe QML
            # self.blockSignals(True)  # ❌ COMENTAR ESTA LÍNEA
            
            # Limpiar datos internos pero mantener estructura
            self._datos_cierre = {}
            self._efectivo_real = 0.0
            self._observaciones = ""
            
            # ✅ NUEVO: Programar reconexión automática
            QTimer.singleShot(3000, self._intentar_reconexion)
            
            print("✅ CierreCajaModel: Desconexión SEGURA completada - reconexión programada")
            
        except Exception as e:
            print(f"❌ Error en desconexión segura: {e}")

    def _intentar_reconexion(self):
        """
        ✅ NUEVO: Intenta reconectar automáticamente
        """
        try:
            print("🔄 Intentando reconexión automática...")
            
            # Marcar como reconectado
            self._disconnected = False
            
            # Reinicializar repository si es necesario
            if not self.repository:
                from ..repositories.cierre_caja_repository import CierreCajaRepository
                self.repository = CierreCajaRepository()
            
            # Emitir señal de reconexión exitosa
            self.operacionExitosa.emit("Módulo reconectado correctamente")
            
            print("✅ Reconexión automática exitosa")
            
        except Exception as e:
            print(f"❌ Error en reconexión: {e}")
            # Programar otro intento en 10 segundos
            QTimer.singleShot(10000, self._intentar_reconexion)

    # ✅ NUEVO: Verificar estado antes de operaciones críticas
    def _verificar_conexion(self) -> bool:
        """
        Verifica si el modelo está conectado correctamente
        """
        try:
            if hasattr(self, '_disconnected') and self._disconnected:
                self.operacionError.emit("Módulo desconectado - reconectando...")
                self._intentar_reconexion()
                return False
            
            if not self.repository:
                print("⚠️ Repository no disponible")
                return False
            
            return True
        except:
            return False

    @Property(list, notify=datosChanged)
    def gastosDetallados(self) -> List[Dict[str, Any]]:
        """Lista detallada de gastos con tipos"""
        return self._datos_cierre.get('gastos_detallados', [])

    @Property(list, notify=datosChanged)
    def resumenGastosPorTipo(self) -> List[Dict[str, Any]]:
        """Resumen de gastos agrupados por tipo"""
        return self._datos_cierre.get('resumen_gastos_tipo', [])

    @Property(float, notify=resumenChanged)
    def totalServiciosBasicos(self) -> float:
        """Total de gastos en servicios básicos"""
        try:
            gastos_tipos = self._datos_cierre.get('resumen_gastos_tipo', [])
            servicios = ['SERVICIOS BÁSICOS', 'ELECTRICIDAD', 'AGUA', 'INTERNET', 'TELÉFONO']
            total = 0.0
            for gasto in gastos_tipos:
                if any(servicio in gasto.get('TipoGasto', '').upper() for servicio in servicios):
                    total += float(gasto.get('TotalGastos', 0))
            return round(total, 2)
        except:
            return 0.0

    @Slot()
    def cargarGastosDetallados(self):
        """Carga gastos detallados por tipo"""
        try:
            if not self._verificar_autenticacion():
                return
            
            # Obtener gastos detallados
            gastos_detallados = self.repository.get_gastos_detallados(
                self._convertir_fecha_bd(self._fecha_actual),
                self._convertir_fecha_bd(self._fecha_actual)
            )
            
            # Obtener resumen por tipo
            resumen_tipos = self.repository.get_resumen_gastos_por_tipo(
                self._convertir_fecha_bd(self._fecha_actual),
                self._convertir_fecha_bd(self._fecha_actual)
            )
            
            # Actualizar datos internos
            if 'gastos_detallados' not in self._datos_cierre:
                self._datos_cierre['gastos_detallados'] = []
            if 'resumen_gastos_tipo' not in self._datos_cierre:
                self._datos_cierre['resumen_gastos_tipo'] = []
                
            self._datos_cierre['gastos_detallados'] = gastos_detallados
            self._datos_cierre['resumen_gastos_tipo'] = resumen_tipos
            
            self.datosChanged.emit()
            self.resumenChanged.emit()
            
            print(f"✅ Gastos detallados cargados: {len(gastos_detallados)} gastos, {len(resumen_tipos)} tipos")
            
        except Exception as e:
            print(f"❌ Error cargando gastos detallados: {e}")
            self.operacionError.emit(f"Error cargando gastos: {str(e)}")

    @Slot(result='QVariantMap')
    def obtenerEstadisticasGastos(self) -> Dict[str, Any]:
        """Obtiene estadísticas de gastos del día"""
        try:
            resumen_tipos = self._datos_cierre.get('resumen_gastos_tipo', [])
            
            if not resumen_tipos:
                return {
                    'tipo_mayor_gasto': 'Ninguno',
                    'cantidad_tipos_gasto': 0,
                    'promedio_por_tipo': 0.0,
                    'servicios_basicos': 0.0
                }
            
            # Encontrar tipo con mayor gasto
            tipo_mayor = max(resumen_tipos, key=lambda x: float(x.get('TotalGastos', 0)))
            
            # Calcular promedio por tipo
            total_gastos = sum(float(item.get('TotalGastos', 0)) for item in resumen_tipos)
            promedio = total_gastos / len(resumen_tipos) if len(resumen_tipos) > 0 else 0
            
            return {
                'tipo_mayor_gasto': tipo_mayor.get('TipoGasto', 'Desconocido'),
                'monto_mayor_gasto': float(tipo_mayor.get('TotalGastos', 0)),
                'cantidad_tipos_gasto': len(resumen_tipos),
                'promedio_por_tipo': round(promedio, 2),
                'servicios_basicos': self.totalServiciosBasicos
            }
            
        except Exception as e:
            print(f"❌ Error calculando estadísticas de gastos: {e}")
            return {}
# ===============================
# REGISTRO PARA QML
# ===============================

def register_cierre_caja_model():
    """Registra el CierreCajaModel para uso en QML"""
    qmlRegisterType(CierreCajaModel, "ClinicaModels", 1, 0, "CierreCajaModel")
    print("💰 CierreCajaModel registrado para QML")

__all__ = ['CierreCajaModel', 'register_cierre_caja_model']