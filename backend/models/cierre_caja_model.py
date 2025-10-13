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
    - Sin timers automÃ¡ticos
    - Sin dependencias de otros modelos  
    - Consultas directas a BD bajo demanda
    - Gestiona arqueo, validaciones y generaciÃ³n de reportes
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # SeÃ±ales para cambios en datos
    datosChanged = Signal()
    resumenChanged = Signal()
    validacionChanged = Signal()
    
    # SeÃ±ales para operaciones
    cierreCompletado = Signal(bool, str)  # success, message
    pdfGenerado = Signal(str)  # ruta_archivo
    errorOccurred = Signal(str, str)  # title, message
    operacionExitosa = Signal(str)
    operacionError = Signal(str)
    cierreCompletadoChanged = Signal()
    
    # SeÃ±ales para UI
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
        
        # ConfiguraciÃ³n del cierre
        self._fecha_actual: str = datetime.now().strftime("%d/%m/%Y")
        self._hora_inicio: str = "08:00"
        self._hora_fin: str = "18:00"
        self._efectivo_real: float = 0.0
        self._observaciones: str = ""

        self._resumen_estructurado: Dict[str, Any] = {}
        
        # Estado del cierre
        self._cierre_completado: bool = False
        self._cierres_del_dia: List[Dict[str, Any]] = []
        
        # AutenticaciÃ³n
        self._usuario_actual_id = 0
        self._usuario_actual_rol = ""
        
        # Referencia al AppController para PDFs
        self._app_controller = None

        self._operation_lock = False
        self._pending_operations = 0

        
        
        print("ðŸ’° CierreCajaModel inicializado - Modo independiente")
    
    # ===============================
    # AUTENTICACIÃ“N
    # ===============================

    def _safe_operation(self, operation_name: str = "OperaciÃ³n"):
        """Protege contra operaciones concurrentes - VERSIÃ“N MEJORADA"""
        if self._operation_lock:
            print(f"â³ {operation_name} en curso, ignorando solicitud duplicada")
            return False
        
        if self._pending_operations > 2:
            print(f"ðŸš¨ Demasiadas operaciones pendientes ({self._pending_operations}), ignorando {operation_name}")
            return False
        
        self._operation_lock = True
        self._pending_operations += 1
        print(f"ðŸ”’ OPERATION LOCK: {operation_name} - Pendientes: {self._pending_operations}")
        return True

    def _release_operation(self):
        """Libera el lock de operaciÃ³n - VERSIÃ“N MEJORADA CON PROTECCIÃ“N"""
        try:
            if self._operation_lock:
                self._operation_lock = False
                self._pending_operations = max(0, self._pending_operations - 1)
                print(f"ðŸ”“ OPERATION UNLOCK - Pendientes: {self._pending_operations}")
            else:
                print("âš ï¸ Intento de liberar lock no activo")
        except Exception as e:
            print(f"âŒ Error liberando lock: {e}")
            # Forzar reset en caso de error
            self._operation_lock = False
            self._pending_operations = 0
    
    @Slot(int, str)
    def set_usuario_actual_con_rol(self, usuario_id: int, usuario_rol: str):
        """Establece el usuario autenticado"""
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                self._usuario_actual_rol = usuario_rol
                print(f"ðŸ‘¤ Usuario establecido en CierreCaja: {usuario_id} ({usuario_rol})")
                self.operacionExitosa.emit(f"Usuario {usuario_id} autenticado en mÃ³dulo de cierre")
            else:
                self.operacionError.emit("ID de usuario invÃ¡lido")
        except Exception as e:
            print(f"âŒ Error estableciendo usuario: {e}")
            self.operacionError.emit(f"Error de autenticaciÃ³n: {str(e)}")

    @Slot()
    def resetOperationLock(self):
        """MÃ©todo de emergencia para resetear el sistema de bloqueo"""
        print("ðŸ†˜ RESETEO DE EMERGENCIA DEL SISTEMA DE BLOQUEO")
        self._operation_lock = False
        self._pending_operations = 0
        self._set_loading(False)
        print("âœ… Sistema de bloqueo reseteado")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        return self._usuario_actual_id
    
    def set_app_controller(self, app_controller):
        """Establece referencia al AppController para generaciÃ³n de PDFs"""
        self._app_controller = app_controller
        print("ðŸ”— AppController conectado para PDFs")

    @Slot()
    def inicializarCamposAutomaticamente(self):
        """
        âœ… FUNCIONALIDAD #1: Auto-gestiÃ³n inteligente de horarios
        Inicializa fecha y horas automÃ¡ticamente al abrir el mÃ³dulo
        """
        try:
            print("ðŸ• Inicializando campos automÃ¡ticamente...")
            
            # 1. FECHA ACTUAL (siempre HOY)
            fecha_hoy = datetime.now().strftime("%d/%m/%Y")
            self._fecha_actual = fecha_hoy
            self.fechaActualChanged.emit()
            print(f"   ðŸ“… Fecha establecida: {fecha_hoy}")
            
            # 2. HORA FIN (hora actual del sistema)
            hora_actual = datetime.now().strftime("%H:%M")
            self._hora_fin = hora_actual
            self.horaFinChanged.emit()
            print(f"   ðŸ• Hora fin establecida: {hora_actual}")
            
            # 3. HORA INICIO (inteligente: buscar Ãºltimo cierre del dÃ­a)
            ultimo_cierre = self.repository.get_ultimo_cierre_del_dia(fecha_hoy)
            
            if ultimo_cierre and ultimo_cierre.get('HoraFin'):
                # Usar la hora fin del Ãºltimo cierre como hora inicio del nuevo
                hora_inicio_auto = self._formatear_hora_limpia(ultimo_cierre['HoraFin'])
                self._hora_inicio = hora_inicio_auto
                print(f"   âœ… Hora inicio auto-detectada del Ãºltimo cierre: {hora_inicio_auto}")
            else:
                # No hay cierre previo hoy, usar hora por defecto
                self._hora_inicio = "08:00"
                print(f"   â„¹ï¸ Hora inicio por defecto (sin cierre previo): 08:00")
            
            self.horaInicioChanged.emit()
            
            # Emitir seÃ±al de Ã©xito
            self.operacionExitosa.emit("Campos inicializados automÃ¡ticamente")
            print("âœ… InicializaciÃ³n automÃ¡tica completada")
            
        except Exception as e:
            error_msg = f"Error inicializando campos: {str(e)}"
            print(f"âŒ {error_msg}")
            self.operacionError.emit(error_msg)
            
            # Establecer valores por defecto en caso de error
            self._fecha_actual = datetime.now().strftime("%d/%m/%Y")
            self._hora_inicio = "08:00"
            self._hora_fin = datetime.now().strftime("%H:%M")
            
            self.fechaActualChanged.emit()
            self.horaInicioChanged.emit()
            self.horaFinChanged.emit()

    def _formatear_hora_limpia(self, hora_raw) -> str:
        """
        âœ… HELPER: Limpia y formatea hora a formato HH:MM
        Maneja mÃºltiples formatos de entrada
        """
        try:
            if not hora_raw:
                return "08:00"
            
            hora_str = str(hora_raw).strip()
            
            # Si ya estÃ¡ en formato HH:MM, devolverla
            if ':' in hora_str and len(hora_str.split(':')[0]) <= 2:
                partes = hora_str.split(':')
                hh = int(partes[0])
                mm = int(partes[1][:2])  # Tomar solo primeros 2 dÃ­gitos de minutos
                return f"{hh:02d}:{mm:02d}"
            
            # Si tiene timestamp completo, extraer solo hora
            if ' ' in hora_str:
                hora_parte = hora_str.split(' ')[-1]
                return self._formatear_hora_limpia(hora_parte)
            
            # Fallback
            return "08:00"
            
        except Exception as e:
            print(f"âš ï¸ Error formateando hora: {e}")
            return "08:00"

    @Slot()
    def actualizarHoraFin(self):
        """
        âœ… FUNCIONALIDAD #1: Actualiza hora fin a la hora actual
        Llamar cuando el campo recibe focus
        """
        try:
            hora_actual = datetime.now().strftime("%H:%M")
            self._hora_fin = hora_actual
            self.horaFinChanged.emit()
            print(f"ðŸ• Hora fin actualizada: {hora_actual}")
        except Exception as e:
            print(f"âŒ Error actualizando hora fin: {e}")
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica autenticaciÃ³n del usuario"""
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
    
    # ValidaciÃ³n de diferencias
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
    # SLOTS - MÃ©todos principales
    # ===============================
    @Slot()
    def consultarDatos(self):
        """MÃ‰TODO PRINCIPAL - Consulta datos de cierre - VERSIÃ“N CORREGIDA"""
        
        # âœ… PROTECCIÃ“N MEJORADA
        if not self._safe_operation("Consulta de datos"):
            self.operacionError.emit("El sistema estÃ¡ ocupado. Espere un momento...")
            return

        try:
            # Validar autenticaciÃ³n
            if not self._verificar_autenticacion():
                return
            
            # Validar conexiÃ³n
            if not self._verificar_conexion():
                return
            
            self._set_loading(True)
            
            print(f"ðŸ” Consultando datos - Fecha: {self._fecha_actual}, Hora: {self._hora_inicio}-{self._hora_fin}")
            
            # âœ… CONSULTAR DATOS CON VALIDACIÃ“N
            datos_cierre = self.repository.get_datos_cierre_completo(
                self._fecha_actual, 
                self._hora_inicio, 
                self._hora_fin
            )
            
            # âœ… VALIDAR ESTRUCTURA DE DATOS ANTES DE USAR
            if datos_cierre and self._validar_estructura_datos(datos_cierre):
                self._datos_cierre = datos_cierre
                
                # Generar resumen estructurado
                self._resumen_estructurado = self.repository.get_resumen_por_categorias(
                    self._fecha_actual,
                    self._hora_inicio,
                    self._hora_fin
                )
                
                # âœ… CARGAR CIERRES CON MANEJO DE ERRORES
                try:
                    self.cargarCierresSemana()
                except Exception as e:
                    print(f"âš ï¸ Error cargando cierres de semana (no crÃ­tico): {e}")
                    # NO romper la operaciÃ³n principal
                
                print(f"âœ… Datos obtenidos - Ingresos: Bs {self.totalIngresos:,.2f}, Egresos: Bs {self.totalEgresos:,.2f}")
                
                # Emitir seÃ±ales de actualizaciÃ³n
                self.datosChanged.emit()
                self.resumenChanged.emit()
                self._actualizar_validacion()
                self.operacionExitosa.emit("Datos consultados correctamente")
            
            else:
                self._datos_cierre = {}
                self._resumen_estructurado = {}
                self.operacionError.emit("No se encontraron datos para el rango especificado")
                
        except Exception as e:
            error_msg = f"Error consultando datos: {str(e)}"
            print(f"âŒ {error_msg}")
            
            if "connection" in str(e).lower() or "database" in str(e).lower():
                self.operacionError.emit("Error de conexiÃ³n a la base de datos")
            else:
                self.operacionError.emit(error_msg)
                
        finally:
            # âœ… GARANTIZAR LIBERACIÃ“N DEL LOCK
            self._set_loading(False)
            self._release_operation()
            print("ðŸ”“ Lock liberado en consultarDatos")

    
    def _validar_estructura_datos(self, datos: Dict) -> bool:
        """âœ… NUEVO: Valida que los datos tengan la estructura correcta"""
        try:
            # Validar que existan las claves principales
            if not isinstance(datos, dict):
                print("âŒ Datos no son un diccionario")
                return False
            
            # Validar que tenga 'ingresos', 'egresos', 'resumen'
            claves_requeridas = ['ingresos', 'egresos', 'resumen']
            for clave in claves_requeridas:
                if clave not in datos:
                    print(f"âŒ Falta clave requerida: {clave}")
                    return False
            
            # Validar que 'ingresos' sea un diccionario
            if not isinstance(datos['ingresos'], dict):
                print("âŒ 'ingresos' no es un diccionario")
                return False
            
            # Validar que 'egresos' sea un diccionario
            if not isinstance(datos['egresos'], dict):
                print("âŒ 'egresos' no es un diccionario")
                return False
            
            # Validar que 'resumen' sea un diccionario
            if not isinstance(datos['resumen'], dict):
                print("âŒ 'resumen' no es un diccionario")
                return False
            
            print("âœ… Estructura de datos validada correctamente")
            return True
            
        except Exception as e:
            print(f"âŒ Error validando estructura de datos: {e}")
            return False
    ############# MÃ‰TODOS AUXILIARES PARA PDF #############

    def _generar_pdf_arqueo_desde_datos(self, datos_cierre: Dict) -> Tuple[bool, str]:
        """Genera PDF del arqueo usando datos ya consultados"""
        try:
            # Preparar movimientos para el PDF
            movimientos_pdf = self._preparar_movimientos_para_pdf(datos_cierre)
            
            # Generar el PDF
            return self._generar_pdf_arqueo(movimientos_pdf, datos_cierre)
            
        except Exception as e:
            error_msg = f"Error en _generar_pdf_arqueo_desde_datos: {str(e)}"
            print(f"âŒ {error_msg}")
            return False, error_msg

    def _preparar_movimientos_para_pdf(self, datos_cierre: Dict) -> List[Dict]:
        """Convierte datos del repository al formato PDF - VERSIÃ“N VALIDADA"""
        movimientos = []
        
        try:
            # âœ… VALIDAR ESTRUCTURA PRIMERO
            if not isinstance(datos_cierre, dict):
                print("âŒ datos_cierre no es un diccionario")
                return []
            
            if 'ingresos' not in datos_cierre:
                print("âŒ Falta clave 'ingresos' en datos_cierre")
                return []
            
            # âœ… PROCESAR INGRESOS CON VALIDACIÃ“N
            ingresos = datos_cierre.get('ingresos', {})
            
            if not isinstance(ingresos, dict):
                print("âŒ 'ingresos' no es un diccionario")
                return []
            
            for categoria, items in ingresos.items():
                if categoria == 'todos':
                    continue
                
                # âœ… VALIDAR QUE items SEA UNA LISTA
                if not isinstance(items, list):
                    print(f"âš ï¸ items de categorÃ­a '{categoria}' no es lista, omitiendo")
                    continue
                
                for item in items:
                    # âœ… VALIDAR QUE item SEA UN DICT
                    if not isinstance(item, dict):
                        print(f"âš ï¸ item en '{categoria}' no es dict, omitiendo")
                        continue
                    
                    movimiento = {
                        'id': item.get('id'),
                        'fecha': item.get('Fecha', ''),
                        'tipo': 'INGRESO',
                        'categoria': categoria.upper(),
                        'descripcion': item.get('Descripcion', item.get('TipoIngreso', '')),
                        'cantidad': item.get('Cantidad', 1),
                        'valor': float(item.get('Total', 0))
                    }
                    
                    # Campos especÃ­ficos segÃºn categorÃ­a
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
                        movimiento['analisis'] = item.get('Descripcion', '').replace('AnÃ¡lisis - ', '')
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
            
            # âœ… PROCESAR EGRESOS CON VALIDACIÃ“N
            egresos = datos_cierre.get('egresos', {})
            
            if isinstance(egresos, dict) and 'todos' in egresos:
                egresos_todos = egresos.get('todos', [])
                
                if isinstance(egresos_todos, list):
                    for item in egresos_todos:
                        if not isinstance(item, dict):
                            continue
                        
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
            
            print(f"âœ… Movimientos preparados: {len(movimientos)} registros")
            return movimientos
            
        except Exception as e:
            print(f"âŒ Error preparando movimientos: {e}")
            import traceback
            traceback.print_exc()
            return []
    @Slot()
    def generarPDFConsulta(self):
        """Genera PDF de la consulta actual - VERSIÃ“N SIMPLIFICADA"""
        
        # âœ… VALIDACIÃ“N TEMPRANA
        if not self._datos_cierre:
            self.operacionError.emit("Debe consultar datos primero antes de generar PDF")
            print("âŒ No hay datos consultados para generar PDF")
            return
        
        # âœ… PROTECCIÃ“N CONTRA CONCURRENCIA
        if not self._safe_operation("GeneraciÃ³n de PDF"):
            self.operacionError.emit("El sistema estÃ¡ ocupado. Espere un momento...")
            return
            
        try:
            print("ðŸ”„ Generando PDF desde datos existentes...")
            
            # âœ… PREPARAR MOVIMIENTOS VALIDANDO ESTRUCTURA
            movimientos = self._preparar_movimientos_para_pdf(self._datos_cierre)
            
            if not movimientos or len(movimientos) == 0:
                self.operacionError.emit("No hay movimientos para generar el PDF")
                return
            
            # Generar PDF
            success, resultado = self._generar_pdf_arqueo(movimientos, self._datos_cierre)
            
            if success:
                print(f"âœ… PDF generado exitosamente: {resultado}")
                self.pdfGenerado.emit(resultado)
                self.operacionExitosa.emit("PDF generado correctamente")
            else:
                error_msg = f"Error generando PDF: {resultado}"
                print(f"âŒ {error_msg}")
                self.operacionError.emit(error_msg)
                
        except Exception as e:
            error_msg = f"Error durante generaciÃ³n de PDF: {str(e)}"
            print(f"âŒ {error_msg}")
            self.operacionError.emit(error_msg)
            import traceback
            traceback.print_exc()
            
        finally:
            # âœ… GARANTIZAR LIBERACIÃ“N DEL LOCK
            self._release_operation()
            print("ðŸ”“ Lock liberado en generarPDFConsulta")

    def _safe_operation_with_timeout(self, operation_name: str = "OperaciÃ³n", timeout_ms: int = 3000):
        """Protege contra operaciones concurrentes CON TIMEOUT"""
        import time
        
        start_time = time.time()
        
        while self._operation_lock and (time.time() - start_time) * 1000 < timeout_ms:
            print(f"â³ Esperando {operation_name}... {int((time.time() - start_time) * 1000)}ms")
            QGuiApplication.processEvents()  # Permitir que la UI responde
            time.sleep(0.1)  # PequeÃ±a pausa
        
        if self._operation_lock:
            print(f"ðŸš¨ TIMEOUT en {operation_name} despuÃ©s de {timeout_ms}ms")
            return False
        
        if self._pending_operations > 2:
            print(f"ðŸš¨ Demasiadas operaciones pendientes ({self._pending_operations}), ignorando {operation_name}")
            return False
        
        self._operation_lock = True
        self._pending_operations += 1
        print(f"ðŸ”’ OPERATION LOCK CON TIMEOUT: {operation_name} - Pendientes: {self._pending_operations}")
        return True

    def _generar_pdf_arqueo(self, movimientos: List[Dict], datos_cierre: Dict) -> Tuple[bool, str]:
        """Genera el PDF del arqueo de caja - VERSIÃ“N CORREGIDA SIN sys.path"""
        try:
            # âœ… IMPORT CORRECTO SIN MODIFICAR sys.path
            try:
                from generar_pdf import GeneradorReportesPDF
            except ImportError:
                # âœ… Si falla, intentar ruta relativa
                try:
                    from ..generar_pdf import GeneradorReportesPDF
                except ImportError:
                    error_msg = "No se pudo importar GeneradorReportesPDF"
                    print(f"âŒ {error_msg}")
                    return False, error_msg
            
            import json
            
            print("âœ… GeneradorReportesPDF importado correctamente")
            
            # Crear instancia del generador
            generador = GeneradorReportesPDF()
            
            # âœ… Validar que movimientos no estÃ© vacÃ­o
            if not movimientos or len(movimientos) == 0:
                print("âš ï¸ No hay movimientos para generar PDF")
                return False, "No hay datos de movimientos para generar el PDF"
            
            # âœ… Calcular diferencia explÃ­citamente
            saldo_teorico = datos_cierre.get('resumen', {}).get('saldo_teorico', 0)
            diferencia_calculada = round(self._efectivo_real - saldo_teorico, 2)
            
            # Preparar datos completos para el PDF
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
            
            print(f"ðŸ“„ Llamando a generar_reporte_pdf con tipo 9 (Arqueo)")
            
            # âœ… LLAMAR AL GENERADOR
            filepath = generador.generar_reporte_pdf(
                datos_json,
                "9",
                self._fecha_actual,
                self._fecha_actual
            )
            
            # âœ… VALIDAR RESULTADO
            if filepath and os.path.exists(filepath):
                print(f"âœ… PDF generado exitosamente: {filepath}")
                return True, filepath
            else:
                print("âš ï¸ PDF no generado o archivo no existe")
                return False, "No se pudo generar el archivo PDF"
                
        except ImportError as e:
            error_msg = f"Error importando generador PDF: {str(e)}"
            print(f"âŒ {error_msg}")
            import traceback
            traceback.print_exc()
            return False, error_msg
            
        except Exception as e:
            error_msg = f"Error generando PDF: {str(e)}"
            print(f"âŒ {error_msg}")
            import traceback
            traceback.print_exc()
            return False, error_msg
        
    def _abrir_pdf_automaticamente(self, filepath: str):
        """Abre el PDF generado automÃ¡ticamente en el navegador"""
        try:
            import webbrowser
            import platform
            
            # Convertir ruta a formato URL
            if platform.system() == 'Windows':
                url = 'file:///' + filepath.replace('\\', '/')
            else:
                url = 'file://' + filepath
            
            webbrowser.open(url)
            print(f"ðŸŒ PDF abierto en navegador: {url}")
            
        except Exception as e:
            print(f"âš ï¸ No se pudo abrir PDF automÃ¡ticamente: {e}")
    
    @Slot(str, str, str)
    def generarPDFCierreEspecifico(self, fecha: str, hora_inicio: str, hora_fin: str):
        """Genera PDF de un cierre especÃ­fico ya guardado (para botÃ³n Ver Cierre)"""
        try:
            print(f"ðŸ“„ Generando PDF especÃ­fico - Fecha: {fecha}, Horario: {hora_inicio}-{hora_fin}")
            
            self._set_loading(True)
            
            # Obtener datos del cierre especÃ­fico
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
                print(f"âœ… PDF generado: {filepath}")
                self.pdfGenerado.emit(filepath)
                #self._abrir_pdf_automaticamente(filepath)
                self.operacionExitosa.emit("PDF generado correctamente")
            else:
                self.operacionError.emit(f"Error generando PDF: {filepath}")
                
        except Exception as e:
            error_msg = f"Error en generarPDFCierreEspecifico: {str(e)}"
            print(f"âŒ {error_msg}")
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
            print(f"ðŸ“… Fecha cambiada a: {nueva_fecha}")
        else:
            self.operacionError.emit("Formato de fecha invÃ¡lido (DD/MM/YYYY)")
    
    @Slot(str)
    def establecerHoraInicio(self, hora: str):
        """Establece hora de inicio"""
        if self._validar_hora(hora):
            self._hora_inicio = hora
            self.horaInicioChanged.emit()
            print(f"ðŸ• Hora inicio: {hora}")
        else:
            self.operacionError.emit("Formato de hora invÃ¡lido (HH:MM)")
    
    @Slot(str) 
    def establecerHoraFin(self, hora: str):
        """Establece hora de fin"""
        if self._validar_hora(hora):
            self._hora_fin = hora
            self.horaFinChanged.emit()
            print(f"ðŸ• Hora fin: {hora}")
        else:
            self.operacionError.emit("Formato de hora invÃ¡lido (HH:MM)")
    
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
            
            print(f"ðŸ’µ Efectivo real: Bs {self._efectivo_real:,.2f}")
            
        except Exception as e:
            self.operacionError.emit(f"Error estableciendo efectivo: {str(e)}")
    
    @Slot()
    def cargarCierresDelDia(self):
        """Carga cierres realizados en el dÃ­a actual"""
        try:
            if not self._verificar_autenticacion():
                return
            
            cierres = self.repository.get_cierres_por_fecha(self._fecha_actual)
            self._cierres_del_dia = cierres
            self.cierresDelDiaChanged.emit()
            
            print(f"ðŸ“‹ Cierres del dÃ­a cargados: {len(cierres)}")
            
        except Exception as e:
            print(f"âŒ Error cargando cierres del dÃ­a: {e}")
    
    # ===============================
    # VALIDACIÃ“N Y CIERRE
    # ===============================
    
    @Slot(result=bool)
    def validarCierre(self) -> bool:
        """Valida si se puede realizar el cierre"""
        try:
            print(f"ðŸ” VALIDACIÃ“N - Usuario autenticado: {self._verificar_autenticacion()}")
            if not self._verificar_autenticacion():
                return False
            
            print(f"ðŸ” VALIDACIÃ“N - Efectivo real: {self._efectivo_real}")
            if self._efectivo_real <= 0:
                self.operacionError.emit("Debe ingresar el efectivo real contado")
                return False
            
            print(f"ðŸ” VALIDACIÃ“N - Datos cierre disponibles: {bool(self._datos_cierre)}")
            if not self._datos_cierre:
                self.operacionError.emit("Debe consultar los datos antes de cerrar")
                return False
            
            cierre_previo = self.repository.verificar_cierre_previo(self._fecha_actual, self._hora_inicio, self._hora_fin)
            print(f"ðŸ” VALIDACIÃ“N - Cierre previo existe para {self._hora_inicio}-{self._hora_fin}: {cierre_previo}")
            if cierre_previo:
                self.operacionError.emit(f"Ya existe un cierre para el horario {self._hora_inicio}-{self._hora_fin}")
                return False
            
            diferencia_abs = abs(self.diferencia)
            print(f"ðŸ” VALIDACIÃ“N - Diferencia absoluta: {diferencia_abs}")
            if diferencia_abs > 1000.0:
                self.operacionError.emit("Diferencia demasiado grande, verifique los datos")
                return False
            
            print("âœ… VALIDACIÃ“N EXITOSA")
            return True
                
        except Exception as e:
            print(f"âŒ Error en validaciÃ³n: {e}")
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
                
                # Recargar cierres del dÃ­a
                self.cargarCierresDelDia()
                
                mensaje = f"Cierre completado - {self._hora_inicio} a {self._hora_fin}"
                self.cierreCompletado.emit(True, mensaje)
                self.operacionExitosa.emit("Cierre guardado en base de datos")
                print(f"âœ… Cierre completado - Usuario: {self._usuario_actual_id}")
            else:
                raise Exception("Error guardando cierre en base de datos")
                
        except Exception as e:
            error_msg = f"Error completando cierre: {str(e)}"
            self.cierreCompletado.emit(False, error_msg)
            self.operacionError.emit(error_msg)
            print(f"âŒ {error_msg}")
        finally:
            self._set_loading(False)
    
    # ===============================
    # GENERACIÃ“N DE PDF
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
                print(f"ðŸ“„ PDF generado: {ruta_pdf}")
                return ruta_pdf
            else:
                self.errorOccurred.emit("Error PDF", "No se pudo generar el archivo")
                return ""
                
        except Exception as e:
            error_msg = f"Error generando PDF: {str(e)}"
            self.errorOccurred.emit("Error PDF", error_msg)
            print(f"âŒ {error_msg}")
            return ""
    
    # ===============================
    # MÃ‰TODOS DE CONSULTA ADICIONALES
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

    # NUEVOS MÃ‰TODOS para compatibilidad con QML
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
        """Carga cierres de toda la semana actual - VERSIÃ“N MEJORADA"""
        try:
            if not self._verificar_autenticacion():
                return
            
            print("ðŸ“… Iniciando carga de cierres de semana...")
            
            cierres_semana = self.repository.get_cierres_semana_actual(self._fecha_actual)
            
            # âœ… VALIDAR RESULTADO
            if cierres_semana is not None:
                self._cierres_del_dia = cierres_semana
                self.cierresDelDiaChanged.emit()
                print(f"ðŸ“… Cierres de la semana cargados: {len(cierres_semana)}")
            else:
                # âœ… SI FALLA, LISTA VACÃA (NO ROMPER)
                self._cierres_del_dia = []
                self.cierresDelDiaChanged.emit()
                print("âš ï¸ No se pudieron cargar cierres de semana")
            
        except Exception as e:
            print(f"âŒ ERROR en cargarCierresSemana: {e}")
            # âœ… EMITIR SEÃ‘AL PERO NO ROMPER LA APLICACIÃ“N
            self._cierres_del_dia = []
            self.cierresDelDiaChanged.emit()
            # NO emitir operacionError aquÃ­ porque es secundario

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
            print(f"âŒ Error obteniendo estadÃ­sticas: {e}")
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
        
        print("ðŸ§¹ Datos del cierre limpiados")
    
    # ===============================
    # MÃ‰TODOS PRIVADOS
    # ===============================
    
    def _verificar_cierre_previo(self):
        """Verifica si ya hay un cierre para la fecha actual"""
        try:
            self._cierre_completado = self.repository.verificar_cierre_previo(self._fecha_actual)
            self.cierreCompletadoChanged.emit()
        except:
            self._cierre_completado = False
    
    def _actualizar_validacion(self):
        """Actualiza validaciÃ³n de diferencias"""
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
        """Genera observaciones automÃ¡ticas"""
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
        DesconexiÃ³n segura SIN romper la interfaz QML
        """
        try:
            print("ðŸš¨ CierreCajaModel: Iniciando desconexiÃ³n de emergencia SEGURA...")
            
            # âœ… IMPORTANTE: NO anular referencias crÃ­ticas inmediatamente
            # Solo marcar como desconectado
            self._disconnected = True
            
            # Detener timer inmediatamente
            if hasattr(self, '_refresh_timer') and self._refresh_timer and self._refresh_timer.isActive():
                self._refresh_timer.stop()
                print("   â¹ï¸ Refresh timer detenido")
            
            # âœ… NUEVO: Emitir seÃ±al de desconexiÃ³n en lugar de romper todo
            try:
                self.operacionError.emit("MÃ³dulo temporalmente desconectado - reconectando...")
            except:
                pass
            
            # âœ… IMPORTANTE: NO bloquear seÃ±ales - esto rompe QML
            # self.blockSignals(True)  # âŒ COMENTAR ESTA LÃNEA
            
            # Limpiar datos internos pero mantener estructura
            self._datos_cierre = {}
            self._efectivo_real = 0.0
            self._observaciones = ""
            
            # âœ… NUEVO: Programar reconexiÃ³n automÃ¡tica
            QTimer.singleShot(3000, self._intentar_reconexion)
            
            print("âœ… CierreCajaModel: DesconexiÃ³n SEGURA completada - reconexiÃ³n programada")
            
        except Exception as e:
            print(f"âŒ Error en desconexiÃ³n segura: {e}")

    def _intentar_reconexion(self):
        """
        âœ… NUEVO: Intenta reconectar automÃ¡ticamente
        """
        try:
            print("ðŸ”„ Intentando reconexiÃ³n automÃ¡tica...")
            
            # Marcar como reconectado
            self._disconnected = False
            
            # Reinicializar repository si es necesario
            if not self.repository:
                from ..repositories.cierre_caja_repository import CierreCajaRepository
                self.repository = CierreCajaRepository()
            
            # Emitir seÃ±al de reconexiÃ³n exitosa
            self.operacionExitosa.emit("MÃ³dulo reconectado correctamente")
            
            print("âœ… ReconexiÃ³n automÃ¡tica exitosa")
            
        except Exception as e:
            print(f"âŒ Error en reconexiÃ³n: {e}")
            # Programar otro intento en 10 segundos
            QTimer.singleShot(10000, self._intentar_reconexion)

    # âœ… NUEVO: Verificar estado antes de operaciones crÃ­ticas
    def _verificar_conexion(self) -> bool:
        """
        Verifica si el modelo estÃ¡ conectado correctamente
        """
        try:
            if hasattr(self, '_disconnected') and self._disconnected:
                self.operacionError.emit("MÃ³dulo desconectado - reconectando...")
                self._intentar_reconexion()
                return False
            
            if not self.repository:
                print("âš ï¸ Repository no disponible")
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
        """Total de gastos en servicios bÃ¡sicos"""
        try:
            gastos_tipos = self._datos_cierre.get('resumen_gastos_tipo', [])
            servicios = ['SERVICIOS BÃSICOS', 'ELECTRICIDAD', 'AGUA', 'INTERNET', 'TELÃ‰FONO']
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
            
            print(f"âœ… Gastos detallados cargados: {len(gastos_detallados)} gastos, {len(resumen_tipos)} tipos")
            
        except Exception as e:
            print(f"âŒ Error cargando gastos detallados: {e}")
            self.operacionError.emit(f"Error cargando gastos: {str(e)}")

    @Slot(result='QVariantMap')
    def obtenerEstadisticasGastos(self) -> Dict[str, Any]:
        """Obtiene estadÃ­sticas de gastos del dÃ­a"""
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
            print(f"âŒ Error calculando estadÃ­sticas de gastos: {e}")
            return {}
# ===============================
# REGISTRO PARA QML
# ===============================

def register_cierre_caja_model():
    """Registra el CierreCajaModel para uso en QML"""
    qmlRegisterType(CierreCajaModel, "ClinicaModels", 1, 0, "CierreCajaModel")
    print("ðŸ’° CierreCajaModel registrado para QML")

__all__ = ['CierreCajaModel', 'register_cierre_caja_model']