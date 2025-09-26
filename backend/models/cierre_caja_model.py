from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType
import json
from datetime import datetime 

from ..repositories.cierre_caja_repository import CierreCajaRepository
from ..core.excepciones import ExceptionHandler, ValidationError, DatabaseQueryError

class CierreCajaModel(QObject):
    """
    Model QObject para operaciones de cierre de caja diario
    Gestiona arqueo, validaciones y generación de reportes
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
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Repository
        self.repository = CierreCajaRepository()
        
        # Estado interno
        self._datos_dia: Dict[str, Any] = {}
        self._resumen_financiero: Dict[str, Any] = {}
        self._validacion_diferencia: Dict[str, Any] = {}
        self._loading: bool = False
        
        # Configuración actual
        self._fecha_actual: str = datetime.now().strftime("%d/%m/%Y")
        self._efectivo_real: float = 0.0
        self._observaciones: str = ""
        self._cierre_completado: bool = False
        # Verificar estado inicial
        if self._fecha_actual == datetime.now().strftime("%d/%m/%Y"):
            self._cierre_completado = self.repository.verificar_cierre_previo(self._fecha_actual)
            self.cierreCompletadoChanged.emit()
        
        # ✅ AUTENTICACIÓN BÁSICA
        self._usuario_actual_id = 0
        print("💰 CierreCajaModel inicializado - Esperando autenticación")
        
        # Referencia al AppController (se establecerá desde main.py)
        self._app_controller = None

        # ✅ TIMER PARA AUTO-REFRESH
        self._auto_refresh_timer = None
        self._setup_auto_refresh()
        
        # Inicialización automática
        self._inicializar_datos()
    
    # ===============================
    # ✅ MÉTODOS REQUERIDOS PARA APPCONTROLLER
    # ===============================
    
    @Slot(int, str)
    def set_usuario_actual_con_rol(self, usuario_id: int, usuario_rol: str):
        """Establece el usuario actual con rol - MÉTODO REQUERIDO por AppController"""
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario autenticado establecido en CierreCajaModel: {usuario_id} ({usuario_rol})")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de cierre")
                
                # Recargar datos con nuevo usuario
                self._cargar_datos_dia()
            else:
                print(f"⚠️ ID de usuario inválido en CierreCajaModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en CierreCajaModel: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        """Property para obtener el usuario actual"""
        return self._usuario_actual_id
    
    def set_app_controller(self, app_controller):
        """Establece la referencia al AppController para acceso al PDF generator"""
        self._app_controller = app_controller
        print("🔗 AppController conectado al CierreCajaModel")
    
    # ===============================
    # VERIFICACIÓN DE AUTENTICACIÓN BÁSICA
    # ===============================
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica si el usuario está autenticado"""
        if self._usuario_actual_id <= 0:
            self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
            return False
        return True
    
    # ===============================
    # 🔥 MÉTODOS DE NOTIFICACIÓN PARA TRANSACCIONES
    # ===============================
    
    @Slot(int, float)
    def notificar_nueva_venta(self, venta_id: int, monto: float):
        """
        Método SIMPLIFICADO para notificar nueva venta
        ✅ FIX: Usar refresh directo en lugar de polling complejo
        """
        try:
            print(f"💰 Nueva venta notificada: ID {venta_id}, Monto: Bs {monto:,.2f}")
            
            # ✅ MÉTODO SIMPLIFICADO: Usar refresh directo (el que funciona)
            self._refresh_cierre_directo("venta", venta_id, monto)
            
        except Exception as e:
            print(f"❌ Error notificando venta en cierre: {e}")
            self.operacionError.emit(f"Error actualizando cierre por venta: {str(e)}")

    # ✅ MÉTODO ADICIONAL PARA DIAGNÓSTICO
    def _debug_estado_cierre_antes_despues(self, venta_id: int, monto: float):
        """Método de diagnóstico para comparar estado antes/después"""
        try:
            print("=" * 50)
            print(f"🔍 DEBUG ESTADO CIERRE - VENTA {venta_id}")
            print("=" * 50)
            
            # Estado actual
            datos_actuales = self.repository.get_datos_dia_actual(self._fecha_actual)
            
            total_ingresos = datos_actuales['resumen'].get('total_ingresos', 0)
            transacciones = datos_actuales['resumen'].get('transacciones_ingresos', 0)
            
            print(f"📊 ESTADO ACTUAL:")
            print(f"   Total ingresos: Bs {total_ingresos:,.2f}")
            print(f"   Transacciones: {transacciones}")
            
            # Estado esperado
            total_esperado = total_ingresos + monto
            transacciones_esperadas = transacciones + 1
            
            print(f"📈 ESTADO ESPERADO DESPUÉS DE VENTA:")
            print(f"   Total esperado: Bs {total_esperado:,.2f}")
            print(f"   Transacciones esperadas: {transacciones_esperadas}")
            
            print("=" * 50)
            
        except Exception as e:
            print(f"❌ Error en debug estado: {e}")

    @Slot(int, float)  
    def notificar_nueva_compra(self, compra_id: int, monto: float):
        """
        Método SIMPLIFICADO para notificar nueva compra
        """
        try:
            print(f"💸 Nueva compra notificada: ID {compra_id}, Monto: Bs {monto:,.2f}")
            
            self._refresh_cierre_directo("compra", compra_id, monto)
            
        except Exception as e:
            print(f"❌ Error notificando compra en cierre: {e}")
            self.operacionError.emit(f"Error actualizando cierre por compra: {str(e)}")

    @Slot(int, float)
    def notificar_nuevo_gasto(self, gasto_id: int, monto: float):
        """
        Método SIMPLIFICADO para notificar nuevo gasto
        """
        try:
            print(f"💳 Nuevo gasto notificado: ID {gasto_id}, Monto: Bs {monto:,.2f}")
            
            self._refresh_cierre_directo("gasto", gasto_id, monto)
            
        except Exception as e:
            print(f"❌ Error notificando gasto en cierre: {e}")
            self.operacionError.emit(f"Error actualizando cierre por gasto: {str(e)}")


    @Slot(int, float)
    def notificar_nueva_consulta(self, consulta_id: int, monto: float):
        """
        Método SIMPLIFICADO para notificar nueva consulta
        """
        try:
            print(f"🩺 Nueva consulta notificada: ID {consulta_id}, Monto: Bs {monto:,.2f}")
            
            self._refresh_cierre_directo("consulta", consulta_id, monto)
            
        except Exception as e:
            print(f"❌ Error notificando consulta en cierre: {e}")
            self.operacionError.emit(f"Error actualizando cierre por consulta: {str(e)}")

    @Slot(int, float)
    def notificar_nuevo_laboratorio(self, lab_id: int, monto: float):
        """
        Método SIMPLIFICADO para notificar nuevo análisis de laboratorio
        """
        try:
            print(f"🔬 Nuevo análisis notificado: ID {lab_id}, Monto: Bs {monto:,.2f}")
            
            self._refresh_cierre_directo("laboratorio", lab_id, monto)
            
        except Exception as e:
            print(f"❌ Error notificando análisis en cierre: {e}")
            self.operacionError.emit(f"Error actualizando cierre por análisis: {str(e)}")

    @Slot(int, float)
    def notificar_nueva_enfermeria(self, enf_id: int, monto: float):
        """
        Método SIMPLIFICADO para notificar nuevo procedimiento de enfermería
        ✅ FIX: Corregir parámetros para recibir (int, float)
        """
        try:
            print(f"💉 Nuevo procedimiento notificado: ID {enf_id}, Monto: Bs {monto:,.2f}")
            
            self._refresh_cierre_directo("enfermeria", enf_id, monto)
            
        except Exception as e:
            print(f"❌ Error notificando procedimiento en cierre: {e}")
            self.operacionError.emit(f"Error actualizando cierre por procedimiento: {str(e)}")
    
    def _refresh_cierre_directo(self, tipo_transaccion: str, transaccion_id: int, monto: float):
        """REFRESH DIRECTO CON VERIFICACIÓN - VERSIÓN CORREGIDA"""
        try:
            print(f"🔄 REFRESH DIRECTO CORREGIDO: {tipo_transaccion} {transaccion_id} - Bs {monto}")
            
            # 1. FORZAR COMMIT EN BD PRIMERO
            self.repository.forzar_commit_bd()
            
            # 2. Invalidar inmediatamente
            self.repository.invalidar_cache_transaccion()
            
            # 3. AGREGAR DELAY más largo para BD
            from PySide6.QtCore import QTimer
            
            def delayed_refresh_with_verification():
                try:
                    print(f"🔍 VERIFICANDO venta {transaccion_id} en BD...")
                    
                    # Verificar que la venta existe en BD
                    fecha_actual = datetime.now().strftime("%d/%m/%Y")
                    venta_existe = self.repository.verificar_venta_incluida_en_cierre(transaccion_id, fecha_actual)
                    
                    if venta_existe:
                        print(f"✅ Venta {transaccion_id} CONFIRMADA en BD")
                    else:
                        print(f"❌ Venta {transaccion_id} NO ENCONTRADA en BD - Esperando más...")
                        # Reintentar después de 1 segundo más
                        QTimer.singleShot(1000, delayed_refresh_with_verification)
                        return
                    
                    # Re-invalidar después del delay
                    self.repository.invalidar_cache_transaccion()
                    
                    # Forzar refresh
                    self.repository.refresh_cache_immediately()
                    
                    # Recargar datos
                    self._cargar_datos_dia()
                    
                    print(f"✅ REFRESH DIRECTO COMPLETADO CON VERIFICACIÓN: {tipo_transaccion} {transaccion_id}")
                    
                except Exception as e:
                    print(f"❌ Error en refresh verificado: {e}")
            
            # Ejecutar después de 1 segundo (más tiempo para BD)
            QTimer.singleShot(1000, delayed_refresh_with_verification)
            
        except Exception as e:
            print(f"❌ Error en refresh directo corregido: {e}")
    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
    
    @Property(str)
    def fechaActual(self) -> str:
        """Fecha actual del cierre"""
        return self._fecha_actual
    
    @Property(float, notify=efectivoRealChanged)
    def efectivoReal(self) -> float:
        """Efectivo real contado"""
        return self._efectivo_real
    
    @Property(float, notify=resumenChanged)
    def totalIngresos(self) -> float:
        """Total de ingresos del día"""
        return float(self._resumen_financiero.get('total_ingresos', 0.0))
    
    @Property(float, notify=resumenChanged)
    def totalEgresos(self) -> float:
        """Total de egresos del día"""
        return float(self._resumen_financiero.get('total_egresos', 0.0))
    
    @Property(float, notify=resumenChanged)
    def saldoTeorico(self) -> float:
        """Saldo teórico calculado"""
        return float(self._resumen_financiero.get('saldo_teorico', 0.0))
    
    @Property(float, notify=validacionChanged)
    def diferencia(self) -> float:
        """Diferencia entre efectivo real y saldo teórico"""
        return float(self._validacion_diferencia.get('diferencia', 0.0))
    
    @Property(str, notify=validacionChanged)
    def tipoDiferencia(self) -> str:
        """Tipo de diferencia: SOBRANTE, FALTANTE, NEUTRO"""
        return self._validacion_diferencia.get('tipo', 'NEUTRO')
    
    @Property(bool, notify=validacionChanged)
    def dentroDeLimite(self) -> bool:
        """Si la diferencia está dentro del límite permitido"""
        return self._validacion_diferencia.get('dentro_limite', True)
    
    @Property(bool, notify=validacionChanged)
    def requiereAutorizacion(self) -> bool:
        """Si la diferencia requiere autorización especial"""
        return self._validacion_diferencia.get('requiere_autorizacion', False)
    
    @Property(list, notify=datosChanged)
    def ingresosDetalle(self) -> List[Dict[str, Any]]:
        """Lista detallada de ingresos"""
        return self._datos_dia.get('ingresos', [])
    
    @Property(list, notify=datosChanged)
    def egresosDetalle(self) -> List[Dict[str, Any]]:
        """Lista detallada de egresos"""
        return self._datos_dia.get('egresos', [])
    
    @Property(int, notify=resumenChanged)
    def transaccionesIngresos(self) -> int:
        """Número de transacciones de ingresos"""
        return int(self._resumen_financiero.get('transacciones_ingresos', 0))
    
    @Property(int, notify=resumenChanged)
    def transaccionesEgresos(self) -> int:
        """Número de transacciones de egresos"""
        return int(self._resumen_financiero.get('transacciones_egresos', 0))
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(bool, notify=cierreCompletadoChanged)
    def cierreCompletadoHoy(self) -> bool:
        """Si el cierre ya fue completado hoy"""
        return self._cierre_completado
    
    @Property(str)
    def estadoFinanciero(self) -> str:
        """Estado financiero del día"""
        if self.saldoTeorico >= 0:
            return "POSITIVO"
        else:
            return "DÉFICIT"
    
    # ===============================
    # SLOTS - Métodos principales
    # ===============================
    
    @Slot()
    def cargarDatosDia(self):
        """Carga los datos financieros del día actual"""
        if not self._verificar_autenticacion():
            return
        
        self._cargar_datos_dia()
    
    @Slot(str)
    def cambiarFecha(self, nueva_fecha: str):
        """Cambia la fecha del cierre"""
        try:
            if not self._verificar_autenticacion():
                return
            
            if self._validar_fecha(nueva_fecha):
                self._fecha_actual = nueva_fecha
                self._cargar_datos_dia()
                print(f"📅 Fecha cambiada a: {nueva_fecha}")
            else:
                self.operacionError.emit("Formato de fecha inválido. Use DD/MM/YYYY")
        except Exception as e:
            self.operacionError.emit(f"Error cambiando fecha: {str(e)}")
    
    @Slot(float)
    def establecerEfectivoReal(self, monto: float):
        """Establece el efectivo real contado"""
        try:
            if monto < 0:
                self.operacionError.emit("El monto no puede ser negativo")
                return
            
            self._efectivo_real = round(monto, 2)
            self.efectivoRealChanged.emit()
            
            # Recalcular validación
            self._validar_diferencia()
            
            print(f"💵 Efectivo real establecido: Bs {self._efectivo_real:,.2f}")
            
        except Exception as e:
            self.operacionError.emit(f"Error estableciendo efectivo: {str(e)}")
    
    @Slot(result=bool)
    def validarCierre(self) -> bool:
        """Valida si se puede realizar el cierre"""
        try:
            if not self._verificar_autenticacion():
                return False
            
            # Verificar que hay efectivo ingresado
            if self._efectivo_real <= 0:
                self.operacionError.emit("Debe ingresar el efectivo real contado")
                return False
            
            # Verificar cierre previo
            if self.repository.verificar_cierre_previo(self._fecha_actual):
                self.operacionError.emit("Ya existe un cierre para esta fecha")
                return False
            
            # Validar diferencia
            self._validar_diferencia()
            
            return True
            
        except Exception as e:
            self.operacionError.emit(f"Error validando cierre: {str(e)}")
            return False
    

    @Slot(result=str)
    def generarPDFArqueoCorregido(self) -> str:
        """Genera PDF del arqueo de caja con datos CORREGIDOS (movimientos individuales)"""
        try:
            if not self._verificar_autenticacion():
                return ""
            
            if not self.validarCierre():
                return ""
            
            # Verificar AppController
            if not self._app_controller:
                self.errorOccurred.emit("Error PDF", "AppController no disponible")
                return ""
            
            # 🔥 CAMBIO CLAVE: Usar método corregido del repository
            datos_pdf = self.repository.generar_datos_pdf_arqueo_corregido(
                self._fecha_actual,
                self._efectivo_real,
                self._observaciones
            )
            
            if not datos_pdf:
                self.errorOccurred.emit("Error PDF", "No se pudieron generar los datos corregidos")
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
                self.operacionExitosa.emit("PDF de arqueo corregido generado correctamente")
                print(f"📄 PDF arqueo CORREGIDO generado: {ruta_pdf}")
                return ruta_pdf
            else:
                self.errorOccurred.emit("Error PDF", "No se pudo generar el PDF corregido")
                return ""
                
        except Exception as e:
            error_msg = f"Error generando PDF corregido: {str(e)}"
            self.errorOccurred.emit("Error PDF", error_msg)
            print(f"❌ {error_msg}")
            return ""
    
    @Slot(str)
    def completarCierre(self, observaciones: str = ""):
        """Completa el cierre de caja"""
        try:
            if not self._verificar_autenticacion():
                return
                
            if not self.validarCierre():
                return
                
            self._set_loading(True)
            
            # Establecer observaciones
            self._observaciones = observaciones
            
            # Por ahora solo marcamos como completado (sin BD)
            self._cierre_completado = True
            self.cierreCompletadoChanged.emit()
            
            # Mensaje de éxito sin PDF
            mensaje = "Cierre de caja completado exitosamente"
            self.cierreCompletado.emit(True, mensaje)
            self.operacionExitosa.emit("Cierre completado con éxito")
            print(f"✅ Cierre completado - Usuario: {self._usuario_actual_id}")
                
        except Exception as e:
            error_msg = f"Error completando cierre: {str(e)}"
            self.cierreCompletado.emit(False, error_msg)
            self.operacionError.emit(error_msg)
            print(f"❌ {error_msg}")
        finally:
            self._set_loading(False)
    @Slot(result=str)
    def diagnosticar_estado_actual(self):
        """Diagnóstico simplificado del estado actual"""
        try:
            if not self._verificar_autenticacion():
                return "❌ Usuario no autenticado"
            
            # Obtener datos actuales
            datos_actuales = self.repository.get_datos_dia_actual(self._fecha_actual)
            
            # Obtener datos sin cache para comparar
            datos_sin_cache = self.repository.get_datos_dia_actual_sin_cache(self._fecha_actual)
            
            total_con_cache = datos_actuales['resumen'].get('total_ingresos', 0)
            total_sin_cache = datos_sin_cache['resumen'].get('total_ingresos', 0)
            
            diferencia = abs(total_con_cache - total_sin_cache)
            
            diagnostico = f"""
                🔍 DIAGNÓSTICO CIERRE DE CAJA - {self._fecha_actual}
                ════════════════════════════════════════════
                💰 Total con caché: Bs {total_con_cache:,.2f}
                💰 Total sin caché: Bs {total_sin_cache:,.2f}
                🔄 Diferencia: Bs {diferencia:,.2f}
                ✅ Estado: {'CONSISTENTE' if diferencia < 0.01 else 'INCONSISTENTE'}
                📊 Transacciones con caché: {datos_actuales['resumen'].get('transacciones_ingresos', 0)}
                📊 Transacciones sin caché: {datos_sin_cache['resumen'].get('transacciones_ingresos', 0)}
                🕒 Timestamp: {datetime.now().strftime('%H:%M:%S')}
                ════════════════════════════════════════════
                """
            
            print(diagnostico)
            return diagnostico
            
        except Exception as e:
            error_msg = f"❌ Error en diagnóstico: {str(e)}"
            print(error_msg)
            return error_msg
    @Slot()
    def actualizarDatos(self):
        """Actualiza los datos del cierre - USAR MÉTODO DIRECTO"""
        if not self._verificar_autenticacion():
            return
        
        try:
            # Usar refresh directo sin delays
            self.repository.invalidar_cache_transaccion()
            self._cargar_datos_dia()
            self.operacionExitosa.emit("Datos actualizados correctamente")
            
        except Exception as e:
            self.operacionError.emit(f"Error actualizando datos: {str(e)}")
    
    @Slot()
    def limpiarCierre(self):
        """Limpia los datos del cierre"""
        self._efectivo_real = 0.0
        self._observaciones = ""
        self._cierre_completado = False
        self._validacion_diferencia = {}
        
        self.efectivoRealChanged.emit()
        self.validacionChanged.emit()
        
        print("🧹 Cierre limpiado")
    
    # ===============================
    # MÉTODOS DE CONSULTA
    # ===============================
    
    @Slot(result='QVariantMap')
    def obtenerEstadisticasDia(self) -> Dict[str, Any]:
        """Obtiene estadísticas adicionales del día"""
        try:
            if not self._datos_dia:
                return {}
            
            ingresos = self._datos_dia.get('ingresos', [])
            egresos = self._datos_dia.get('egresos', [])
            
            # Calcular estadísticas
            total_conceptos_ingresos = len([i for i in ingresos if i.get('importe', 0) > 0])
            total_conceptos_egresos = len([e for e in egresos if e.get('importe', 0) > 0])
            
            concepto_mayor_ingreso = max(ingresos, key=lambda x: x.get('importe', 0)) if ingresos else {}
            concepto_mayor_egreso = max(egresos, key=lambda x: x.get('importe', 0)) if egresos else {}
            
            return {
                'conceptos_activos_ingresos': total_conceptos_ingresos,
                'conceptos_activos_egresos': total_conceptos_egresos,
                'mayor_fuente_ingreso': concepto_mayor_ingreso.get('concepto', 'N/A'),
                'valor_mayor_ingreso': concepto_mayor_ingreso.get('importe', 0.0),
                'mayor_concepto_egreso': concepto_mayor_egreso.get('concepto', 'N/A'),
                'valor_mayor_egreso': concepto_mayor_egreso.get('importe', 0.0),
                'promedio_por_transaccion_ingreso': round(
                    self.totalIngresos / max(self.transaccionesIngresos, 1), 2
                ),
                'promedio_por_transaccion_egreso': round(
                    self.totalEgresos / max(self.transaccionesEgresos, 1), 2
                )
            }
            
        except Exception as e:
            print(f"❌ Error obteniendo estadísticas: {e}")
            return {}
    
    @Slot(result=str)
    def obtenerRecomendaciones(self) -> str:
        """Obtiene recomendaciones basadas en el estado del cierre"""
        try:
            recomendaciones = []
            
            # Recomendaciones por diferencia
            if self.requiereAutorizacion:
                recomendaciones.append("⚠️ La diferencia requiere autorización del supervisor")
                recomendaciones.append("📋 Revisar detalladamente todas las transacciones del día")
                
            if self.tipoDiferencia == "FALTANTE":
                recomendaciones.append("🔍 Verificar si hay transacciones no registradas")
                recomendaciones.append("💳 Revisar pagos con tarjeta o transferencias")
                
            elif self.tipoDiferencia == "SOBRANTE":
                recomendaciones.append("🧾 Verificar si hay ingresos duplicados")
                recomendaciones.append("📝 Documentar el origen del sobrante")
                
            # Recomendaciones por estado financiero
            if self.estadoFinanciero == "DÉFICIT":
                recomendaciones.append("📈 Evaluar estrategias para incrementar ingresos")
                recomendaciones.append("💰 Revisar gastos operativos del día")
                
            # Recomendación general
            if not recomendaciones:
                recomendaciones.append("✅ El arqueo está balanceado correctamente")
                
            recomendaciones.append("📄 Generar PDF del arqueo para respaldo")
            
            return "\n".join(recomendaciones)
            
        except Exception as e:
            return "Error generando recomendaciones"
    
    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _inicializar_datos(self):
        try:
            print("🔄 Inicializando datos de cierre...")
            # Cargar datos iniciales si hay usuario autenticado
            if self._usuario_actual_id > 0:
                self._cargar_datos_dia()
        except Exception as e:
            print(f"⚠️ Error en inicialización: {e}")
    
    def _cargar_datos_dia(self):
        """Carga los datos financieros del día"""
        try:
            self._set_loading(True)
            
            print(f"💰 Cargando datos de cierre para: {self._fecha_actual}")
            
            # Obtener datos del repositorio
            self._datos_dia = self.repository.get_datos_dia_actual(self._fecha_actual)
            self._resumen_financiero = self._datos_dia.get('resumen', {})
            
            # Emitir señales
            self.datosChanged.emit()
            self.resumenChanged.emit()
            
            # Recalcular validación si hay efectivo
            if self._efectivo_real > 0:
                self._validar_diferencia()
            
            print(f"✅ Datos cargados - Ingresos: Bs {self.totalIngresos:,.2f}, Egresos: Bs {self.totalEgresos:,.2f}")
            
        except Exception as e:
            print(f"❌ Error cargando datos del día: {e}")
            self.operacionError.emit(f"Error cargando datos: {str(e)}")
        finally:
            self._set_loading(False)
    
    def _validar_diferencia(self):
        """Valida la diferencia entre efectivo y saldo teórico"""
        try:
            if self._efectivo_real <= 0:
                return
            
            self._validacion_diferencia = self.repository.validar_diferencia_permitida(
                self._efectivo_real,
                self.saldoTeorico,
                100.0  # Límite de Bs 100
            )
            
            self.validacionChanged.emit()
            
            print(f"🔍 Validación: {self._validacion_diferencia.get('tipo', 'N/A')} "
                  f"Bs {self._validacion_diferencia.get('diferencia_absoluta', 0):,.2f}")
            
        except Exception as e:
            print(f"❌ Error validando diferencia: {e}")
    
    def _validar_fecha(self, fecha: str) -> bool:
        """Valida formato de fecha DD/MM/YYYY"""
        try:
            datetime.strptime(fecha, "%d/%m/%Y")
            return True
        except:
            return False
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()

    def emergency_disconnect(self):
        """Desconexión de emergencia para CierreCajaModel"""
        try:
            print("🚨 CierreCajaModel: Iniciando desconexión de emergencia...")
            # Detener auto-refresh timer
            if self._auto_refresh_timer:
                self._auto_refresh_timer.stop()
                self._auto_refresh_timer.deleteLater()
                self._auto_refresh_timer = None
            # Limpiar referencia al AppController
            self._app_controller = None
            
            # Establecer estado shutdown
            self._loading = False
            self._cierre_completado = False
            
            # Desconectar señales
            signals_to_disconnect = [
                'datosChanged', 'resumenChanged', 'validacionChanged',
                'cierreCompletado', 'pdfGenerado', 'errorOccurred', 
                'operacionExitosa', 'operacionError', 'loadingChanged', 
                'efectivoRealChanged'
            ]
            
            for signal_name in signals_to_disconnect:
                if hasattr(self, signal_name):
                    try:
                        getattr(self, signal_name).disconnect()
                    except:
                        pass
            
            # Limpiar datos
            self._datos_dia = {}
            self._resumen_financiero = {}
            self._validacion_diferencia = {}
            self._efectivo_real = 0.0
            self._observaciones = ""
            self._usuario_actual_id = 0  # ✅ RESETEAR USUARIO
            
            # Anular repository
            self.repository = None
            
            print("✅ CierreCajaModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión CierreCajaModel: {e}")

    def _setup_auto_refresh(self):
        """Configura timer para auto-refresh cada 30 segundos"""
        from PySide6.QtCore import QTimer
        
        self._auto_refresh_timer = QTimer()
        self._auto_refresh_timer.timeout.connect(self._auto_refresh_data)
        self._auto_refresh_timer.setInterval(30000)  # 30 segundos
        print("⏰ Auto-refresh configurado para Cierre de Caja")

    def _auto_refresh_data(self):
        """Auto-refresh silencioso de datos"""
        try:
            if self._usuario_actual_id > 0 and not self._loading:
                print("🔄 Auto-refresh silencioso de datos de caja...")
                self._cargar_datos_dia()
        except Exception as e:
            print(f"❌ Error en auto-refresh: {e}")

    @Slot()
    def iniciarAutoRefresh(self):
        """Inicia el auto-refresh (llamar desde QML)"""
        if self._auto_refresh_timer and not self._auto_refresh_timer.isActive():
            self._auto_refresh_timer.start()
            print("▶️ Auto-refresh iniciado")

    @Slot()  
    def detenerAutoRefresh(self):
        """Detiene el auto-refresh"""
        if self._auto_refresh_timer and self._auto_refresh_timer.isActive():
            self._auto_refresh_timer.stop()
            print("⏸️ Auto-refresh detenido")

    @Slot()
    def forzarActualizacion(self):
        """Fuerza actualización inmediata desde QML - MÉTODO SIMPLIFICADO"""
        try:
            print("🔄 Forzando actualización de datos...")
            
            # Usar el método directo que funciona
            self.repository.invalidar_cache_completo()
            self.repository.refresh_cache_immediately()
            self._cargar_datos_dia()
            
            print("✅ Actualización forzada completada")
            
        except Exception as e:
            print(f"❌ Error en actualización forzada: {e}")
            self.operacionError.emit(f"Error actualizando datos: {str(e)}")

    def _debug_datos_arqueo(self, datos_organizados):
        """Método de debug para inspeccionar la estructura real de datos - TEMPORAL"""
        try:
            print("=" * 50)
            print("🔍 DEBUG: ESTRUCTURA DE DATOS ARQUEO")
            print("=" * 50)
            
            for categoria, items in datos_organizados.items():
                print(f"\n📊 CATEGORÍA: {categoria.upper()}")
                print(f"📈 Total items: {len(items)}")
                
                if items and len(items) > 0:
                    print("🗂️  Primer elemento:")
                    primer_item = items[0]
                    for key, value in primer_item.items():
                        print(f"   {key}: {value} ({type(value).__name__})")
                    
                    if len(items) > 1:
                        print(f"🗂️  Campos únicos en todos los elementos:")
                        all_keys = set()
                        for item in items:
                            all_keys.update(item.keys())
                        print(f"   {sorted(all_keys)}")
                else:
                    print("   ❌ Sin datos")
            
            print("=" * 50)
            return True
            
        except Exception as e:
            print(f"Error en debug: {e}")
            return False
        


# ===============================
# REGISTRO PARA QML
# ===============================

def register_cierre_caja_model():
    """Registra el CierreCajaModel para uso en QML"""
    qmlRegisterType(CierreCajaModel, "ClinicaModels", 1, 0, "CierreCajaModel")
    print("💰 CierreCajaModel registrado para QML")

# Para facilitar la importación
__all__ = ['CierreCajaModel', 'register_cierre_caja_model']