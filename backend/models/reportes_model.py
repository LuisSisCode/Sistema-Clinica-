from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType
import json
from datetime import datetime 

from ..repositories.reportes_repository import ReportesRepository
from ..core.excepciones import ExceptionHandler, ValidationError, DatabaseQueryError

class ReportesModel(QObject):
    """
    Model QObject para generación de reportes con autenticación básica
    ACTUALIZADO: Incluye soporte para Reporte de Ingresos y Egresos mejorado
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
        
        print("📊 ReportesModel inicializado con soporte para Reporte de Ingresos y Egresos")
    
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
            print(f"❌ Error estableciendo usuario en ReportesModel: {e}")
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
        print(f"🔍 Verificando autenticación: usuario_id = {self._usuario_actual_id}")
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
        """Descripción del tipo de reporte actual - ACTUALIZADA"""
        tipos = {
            1: "Ventas de Farmacia",
            2: "Inventario de Productos", 
            3: "Compras de Farmacia",
            4: "Consultas Médicas",
            5: "Análisis de Laboratorio",
            6: "Procedimientos de Enfermería",
            7: "Gastos Operativos",
            8: "Reporte de Ingresos y Egresos"  # ✅ CAMBIO APLICADO
        }
        return tipos.get(self._tipo_reporte_actual, "Sin seleccionar")
    
    # ===============================
    # SLOTS - Métodos SIN CONTROL DE PERMISOS
    # ===============================
    
    @Slot(int, str, str, result=bool)
    def generarReporte(self, tipo_reporte: int, fecha_desde: str, fecha_hasta: str) -> bool:
        """
        Genera reporte - Solo verifica autenticación básica
        MEJORADO: Soporte especial para Reporte de Ingresos y Egresos
        """
        try:
            print(f"📊 INICIANDO generarReporte - Tipo: {tipo_reporte}, Usuario: {self._usuario_actual_id}")
            self._set_loading(True)
            self._set_progress(10)
            
            # ✅ VERIFICAR AUTENTICACIÓN BÁSICA
            if not self._verificar_autenticacion():
                print("❌ Verificación de autenticación falló")
                return False
            
            # ✅ MENSAJE ESPECIAL PARA REPORTE DE INGRESOS Y EGRESOS
            if tipo_reporte == 8:
                print(f"💰 Generando Reporte de Ingresos y Egresos - Usuario: {self._usuario_actual_id}")
            else:
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
                
                if tipo_reporte == 8:
                    mensaje = f"No se encontraron movimientos financieros para el período {fecha_desde} - {fecha_hasta}"
                else:
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
                
                # ✅ ESTADÍSTICAS ESPECIALES PARA REPORTE FINANCIERO
                if tipo_reporte == 8:
                    self._estadisticas = self._calcular_estadisticas_financieras(datos)
                
                self._emit_data_changed()
                
                # ✅ MENSAJE PERSONALIZADO PARA REPORTE FINANCIERO
                if tipo_reporte == 8:
                    mensaje_resultado = f"Reporte de Ingresos y Egresos generado: {len(datos)} movimientos financieros"
                else:
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
        """Obtiene datos según el tipo de reporte - CON VALIDACIÓN MEJORADA"""
        try:
            datos = None
            nombre_reporte = self._obtener_nombre_tipo_reporte(tipo_reporte)
            
            # ✅ LOG INICIAL
            print(f"📊 Obteniendo datos para: {nombre_reporte}")
            print(f"   Período: {fecha_desde} al {fecha_hasta}")
            
            if tipo_reporte == 1:
                datos = self.repository.get_reporte_ventas(fecha_desde, fecha_hasta)
            elif tipo_reporte == 2:
                datos = self.repository.get_reporte_inventario()
            elif tipo_reporte == 3:
                datos = self.repository.get_reporte_compras(fecha_desde, fecha_hasta)
            elif tipo_reporte == 4:
                datos = self.repository.get_reporte_consultas(fecha_desde, fecha_hasta)
            elif tipo_reporte == 5:
                datos = self.repository.get_reporte_laboratorio(fecha_desde, fecha_hasta)
            elif tipo_reporte == 6:
                datos = self.repository.get_reporte_enfermeria(fecha_desde, fecha_hasta)
            elif tipo_reporte == 7:
                datos = self.repository.get_reporte_gastos(fecha_desde, fecha_hasta)
            elif tipo_reporte == 8:
                print(f"💰 Obteniendo reporte de ingresos y egresos...")
                datos = self.repository.get_reporte_ingresos_egresos(fecha_desde, fecha_hasta)
            else:
                # ✅ ERROR EXPLÍCITO
                error_msg = f"Tipo de reporte inválido: {tipo_reporte}"
                print(f"❌ {error_msg}")
                self.operacionError.emit(error_msg)
                return []
            
            # ✅ VALIDACIÓN COMPLETA DEL TIPO DE RETORNO
            if datos is None:
                mensaje = f"⚠️ Repository retornó None para {nombre_reporte}"
                print(mensaje)
                self.operacionError.emit(f"Error: No se pudo obtener datos de {nombre_reporte}")
                return []
            
            if not isinstance(datos, list):
                mensaje = f"❌ Repository retornó tipo incorrecto: {type(datos)} (esperado: list)"
                print(mensaje)
                print(f"🔍 Contenido retornado: {datos}")
                self.operacionError.emit(f"Error interno: Tipo de datos incorrecto en {nombre_reporte}")
                return []
            
            if not datos:  # Lista vacía
                mensaje = f"ℹ️ Repository retornó lista vacía para {nombre_reporte}"
                print(mensaje)
                # ✅ NO ES ERROR - Es información válida
                return []
            
            # ✅ VALIDAR ESTRUCTURA DE DATOS (primer elemento)
            if not isinstance(datos[0], dict):
                mensaje = f"❌ Primer elemento no es dict: {type(datos[0])}"
                print(mensaje)
                self.operacionError.emit(f"Error interno: Estructura de datos incorrecta en {nombre_reporte}")
                return []
            
            # ✅ LOG DE ÉXITO CON DETALLES
            print(f"✅ Datos válidos obtenidos: {len(datos)} registros")
            print(f"   Campos disponibles: {list(datos[0].keys())[:5]}...")  # Mostrar solo 5 primeros
            
            return datos
                
        except DatabaseQueryError as db_error:
            # ✅ ERROR ESPECÍFICO DE BASE DE DATOS
            mensaje = f"Error de base de datos: {str(db_error)}"
            print(f"❌ {mensaje}")
            self.operacionError.emit(mensaje)
            return []
            
        except Exception as e:
            # ✅ ERROR GENÉRICO CON STACK TRACE
            mensaje = f"Error inesperado obteniendo datos: {str(e)}"
            print(f"❌ {mensaje}")
            import traceback
            traceback.print_exc()
            self.operacionError.emit(mensaje)
            return []

    def _obtener_nombre_tipo_reporte(self, tipo_reporte: int) -> str:
        """Obtiene el nombre legible del tipo de reporte"""
        nombres = {
            1: "Ventas de Farmacia",
            2: "Inventario de Productos",
            3: "Compras de Farmacia",
            4: "Consultas Médicas",
            5: "Análisis de Laboratorio",
            6: "Procedimientos de Enfermería",
            7: "Gastos Operativos",
            8: "Ingresos y Egresos"
        }
        return nombres.get(tipo_reporte, f"Reporte Tipo {tipo_reporte}")

    def _calcular_resumen(self, datos: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calcula resumen estadístico - CON VALIDACIÓN ROBUSTA DE TIPOS"""
        try:
            print(f"🔍 DEBUGGING _calcular_resumen MEJORADO")
            
            # ✅ VALIDACIÓN INICIAL ROBUSTA
            if datos is None:
                print("⚠️ datos es None")
                return self._resumen_vacio()
            
            if not isinstance(datos, list):
                print(f"❌ ERROR CRÍTICO: datos no es una lista, es: {type(datos)}")
                print(f"🔍 Contenido: {datos}")
                return self._resumen_vacio()
            
            if len(datos) == 0:
                print("ℹ️ Lista de datos vacía")
                return self._resumen_vacio()
            
            # ✅ VALIDAR PRIMER ELEMENTO
            if not isinstance(datos[0], dict):
                print(f"❌ Primer elemento no es dict: {type(datos[0])}")
                return self._resumen_vacio()
            
            print(f"✅ Datos válidos: {len(datos)} registros")
            
            total_registros = len(datos)
            total_valor = 0.0
            total_cantidad = 0
            
            # ✅ PROCESAMIENTO ESPECIAL PARA REPORTE FINANCIERO
            if self._tipo_reporte_actual == 8:
                return self._calcular_resumen_financiero(datos)
            
            # ✅ PROCESAR CADA REGISTRO CON VALIDACIONES
            for i, registro in enumerate(datos):
                try:
                    # Validar que cada registro sea dict
                    if not isinstance(registro, dict):
                        print(f"⚠️ Registro {i} no es diccionario, saltando")
                        continue
                    
                    # Obtener valor con múltiples intentos
                    valor = self._extraer_valor_seguro(registro)
                    total_valor += valor
                    
                    # Obtener cantidad con múltiples intentos
                    cantidad = self._extraer_cantidad_segura(registro)
                    total_cantidad += cantidad
                    
                    if i < 3:  # Solo log para los primeros 3
                        print(f"✅ Registro {i}: valor={valor}, cantidad={cantidad}")
                    
                except Exception as e:
                    print(f"⚠️ Error procesando registro {i}: {e}")
                    continue
            
            promedio_valor = total_valor / total_registros if total_registros > 0 else 0.0
            
            resumen_final = {
                'totalRegistros': total_registros,
                'totalValor': round(total_valor, 2),
                'totalCantidad': total_cantidad,
                'promedioValor': round(promedio_valor, 2),
                'fechaGeneracion': self._fecha_desde_actual or "",
                'fechaHasta': self._fecha_hasta_actual or "",
                'tipoReporte': self._tipo_reporte_actual or 0,
                'fechaCreacion': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
            
            print(f"✅ Resumen calculado exitosamente: {resumen_final}")
            return resumen_final
            
        except Exception as e:
            print(f"❌ Error crítico en _calcular_resumen mejorado: {e}")
            import traceback
            traceback.print_exc()
            return self._resumen_vacio()

    def _calcular_resumen_financiero(self, datos: List[Dict[str, Any]]) -> Dict[str, Any]:
        """✅ NUEVO: Calcula resumen específico para reporte de ingresos y egresos"""
        try:
            print("💰 Calculando resumen financiero...")
            
            total_registros = len(datos)
            total_ingresos = 0.0
            total_egresos = 0.0
            cantidad_ingresos = 0
            cantidad_egresos = 0
            
            for registro in datos:
                try:
                    tipo = registro.get('tipo', '')
                    valor = float(registro.get('valor', 0))
                    
                    if tipo == 'INGRESO':
                        total_ingresos += abs(valor)  # Asegurar valor positivo
                        cantidad_ingresos += 1
                    elif tipo == 'EGRESO':
                        total_egresos += abs(valor)   # Asegurar valor positivo
                        cantidad_egresos += 1
                        
                except Exception as e:
                    print(f"⚠️ Error procesando registro financiero: {e}")
                    continue
            
            saldo_neto = total_ingresos - total_egresos
            
            resumen_financiero = {
                'totalRegistros': total_registros,
                'totalIngresos': round(total_ingresos, 2),
                'totalEgresos': round(total_egresos, 2),
                'saldoNeto': round(saldo_neto, 2),
                'totalValor': round(saldo_neto, 2),  # Para compatibilidad
                'cantidadIngresos': cantidad_ingresos,
                'cantidadEgresos': cantidad_egresos,
                'promedioIngreso': round(total_ingresos / cantidad_ingresos, 2) if cantidad_ingresos > 0 else 0.0,
                'promedioEgreso': round(total_egresos / cantidad_egresos, 2) if cantidad_egresos > 0 else 0.0,
                'estadoFinanciero': 'SUPERÁVIT' if saldo_neto >= 0 else 'DÉFICIT',
                'porcentajeCobertura': round((total_ingresos / total_egresos * 100), 1) if total_egresos > 0 else 100.0,
                'fechaGeneracion': self._fecha_desde_actual or "",
                'fechaHasta': self._fecha_hasta_actual or "",
                'tipoReporte': self._tipo_reporte_actual or 0,
                'fechaCreacion': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
            
            print(f"💹 Resumen financiero calculado:")
            print(f"   📈 Ingresos: Bs {total_ingresos:,.2f}")
            print(f"   📉 Egresos: Bs {total_egresos:,.2f}")
            print(f"   💰 Saldo: Bs {saldo_neto:,.2f}")
            print(f"   📊 Estado: {resumen_financiero['estadoFinanciero']}")
            
            return resumen_financiero
            
        except Exception as e:
            print(f"❌ Error calculando resumen financiero: {e}")
            return self._resumen_vacio()

    def _calcular_estadisticas_financieras(self, datos: List[Dict[str, Any]]) -> Dict[str, Any]:
        """✅ NUEVO: Calcula estadísticas adicionales para reporte financiero"""
        try:
            categorias_ingresos = {}
            categorias_egresos = {}
            
            for registro in datos:
                tipo = registro.get('tipo', '')
                categoria = registro.get('categoria', 'Sin categoría')
                valor = abs(float(registro.get('valor', 0)))
                
                if tipo == 'INGRESO':
                    if categoria in categorias_ingresos:
                        categorias_ingresos[categoria] += valor
                    else:
                        categorias_ingresos[categoria] = valor
                elif tipo == 'EGRESO':
                    if categoria in categorias_egresos:
                        categorias_egresos[categoria] += valor
                    else:
                        categorias_egresos[categoria] = valor
            
            # Identificar categoría principal de ingresos
            principal_ingreso = max(categorias_ingresos.items(), key=lambda x: x[1]) if categorias_ingresos else ("Ninguna", 0)
            
            # Identificar categoría principal de egresos
            principal_egreso = max(categorias_egresos.items(), key=lambda x: x[1]) if categorias_egresos else ("Ninguna", 0)
            
            return {
                'categorias_ingresos': categorias_ingresos,
                'categorias_egresos': categorias_egresos,
                'principal_fuente_ingreso': principal_ingreso[0],
                'valor_principal_ingreso': principal_ingreso[1],
                'principal_categoria_gasto': principal_egreso[0],
                'valor_principal_gasto': principal_egreso[1],
                'total_categorias_ingresos': len(categorias_ingresos),
                'total_categorias_egresos': len(categorias_egresos),
                'fecha_analisis': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
            
        except Exception as e:
            print(f"⚠️ Error calculando estadísticas financieras: {e}")
            return {}

    def _resumen_vacio(self) -> Dict[str, Any]:
        """Retorna un resumen vacío válido"""
        return {
            'totalRegistros': 0,
            'totalValor': 0.0,
            'totalCantidad': 0,
            'promedioValor': 0.0,
            'fechaGeneracion': self._fecha_desde_actual or "",
            'fechaHasta': self._fecha_hasta_actual or "",
            'tipoReporte': self._tipo_reporte_actual or 0,
            'fechaCreacion': datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }

    def _extraer_valor_seguro(self, registro: dict) -> float:
        """Extrae valor de un registro con múltiples intentos"""
        campos_valor = ['valor', 'total', 'monto', 'precio', 'Total', 'Monto', 'Valor']
        
        for campo in campos_valor:
            if campo in registro:
                valor_raw = registro[campo]
                try:
                    if valor_raw is None:
                        continue
                    if isinstance(valor_raw, (int, float)):
                        return float(valor_raw)
                    if isinstance(valor_raw, str):
                        valor_clean = valor_raw.strip()
                        if valor_clean and valor_clean.replace('.', '').replace('-', '').replace(',', '').isdigit():
                            return float(valor_clean.replace(',', ''))
                except:
                    continue
        
        return 0.0

    def _extraer_cantidad_segura(self, registro: dict) -> int:
        """Extrae cantidad de un registro con múltiples intentos"""
        campos_cantidad = ['cantidad', 'stock', 'unidades', 'Cantidad', 'Stock', 'Unidades']
        
        for campo in campos_cantidad:
            if campo in registro:
                cantidad_raw = registro[campo]
                try:
                    if cantidad_raw is None:
                        continue
                    if isinstance(cantidad_raw, (int, float)):
                        return int(float(cantidad_raw))
                    if isinstance(cantidad_raw, str):
                        cantidad_clean = cantidad_raw.strip()
                        if cantidad_clean and cantidad_clean.replace('.', '').isdigit():
                            return int(float(cantidad_clean))
                except:
                    continue
        
        return 1  # Valor por defecto para evitar divisiones por cero
    
    # ===============================
    # EXPORTACIÓN A PDF SIN RESTRICCIONES
    # ===============================
    
    @Slot(result=str)
    def exportarPDF(self) -> str:
        """
        Exporta el reporte actual a PDF
        ✅ MODIFICADO: Ahora usa AppController que maneja el responsable
        """
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
            
            # ✅ LOG CON INFORMACIÓN DEL USUARIO
            print(f"\n{'='*60}")
            print(f"📄 EXPORTANDO PDF DESDE REPORTES_MODEL")
            print(f"{'='*60}")
            print(f"   👤 Usuario ID: {self._usuario_actual_id}")
            print(f"   📊 Tipo Reporte: {self._tipo_reporte_actual}")
            print(f"   📋 Registros: {len(self._datos_reporte)}")
            print(f"{'='*60}\n")
            
            # ✅ MENSAJE ESPECIAL PARA REPORTE FINANCIERO
            if self._tipo_reporte_actual == 8:
                print(f"💰 Iniciando exportación PDF de Reporte de Ingresos y Egresos")
                print(f"   Usuario: {self._usuario_actual_id}")
                print(f"   Movimientos: {len(self._datos_reporte)}")
            else:
                print(f"📄 Iniciando exportación PDF")
                print(f"   Usuario: {self._usuario_actual_id}")
                print(f"   Tipo: {self._tipo_reporte_actual}")
                print(f"   Registros: {len(self._datos_reporte)}")
            
            # Usar todos los datos sin filtros
            datos_json = json.dumps(self._datos_reporte, default=str)
            
            # ✅ USAR AppController QUE YA MANEJA EL RESPONSABLE
            # El AppController tomará automáticamente:
            # - self._usuario_autenticado_nombre
            # - self._usuario_autenticado_rol
            # Y los establecerá en el PDF generator
            
            ruta_pdf = self._app_controller.generarReportePDF(
                datos_json,
                str(self._tipo_reporte_actual),
                self._fecha_desde_actual,
                self._fecha_hasta_actual
            )
            
            if ruta_pdf:
                if self._tipo_reporte_actual == 8:
                    mensaje_exito = f"Reporte de Ingresos y Egresos exportado exitosamente"
                    self.operacionExitosa.emit("Reporte financiero generado correctamente")
                else:
                    mensaje_exito = f"PDF exportado exitosamente"
                    self.operacionExitosa.emit("PDF generado correctamente")
                
                print(f"✅ {mensaje_exito}: {ruta_pdf}")
                print(f"   👤 Responsable: Usuario {self._usuario_actual_id}\n")
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
        """Obtiene lista de tipos de reportes - TODOS DISPONIBLES - ACTUALIZADA"""
        return [
            {"id": 1, "nombre": "Ventas de Farmacia", "requiere_fechas": True},
            {"id": 2, "nombre": "Inventario de Productos", "requiere_fechas": False},
            {"id": 3, "nombre": "Compras de Farmacia", "requiere_fechas": True},
            {"id": 4, "nombre": "Consultas Médicas", "requiere_fechas": True},
            {"id": 5, "nombre": "Análisis de Laboratorio", "requiere_fechas": True},
            {"id": 6, "nombre": "Procedimientos de Enfermería", "requiere_fechas": True},
            {"id": 7, "nombre": "Gastos Operativos", "requiere_fechas": True},
            {"id": 8, "nombre": "Reporte de Ingresos y Egresos", "requiere_fechas": True}  # ✅ ACTUALIZADO
        ]
    
    # ===============================
    # ✅ NUEVOS MÉTODOS PARA REPORTE FINANCIERO
    # ===============================
    
    @Slot(result='QVariantMap')
    def obtenerAnalisisFinanciero(self) -> Dict[str, Any]:
        """✅ NUEVO: Obtiene análisis financiero detallado del período actual"""
        try:
            if not self._verificar_autenticacion():
                return {}
            
            if not self._fecha_desde_actual or not self._fecha_hasta_actual:
                return {}
            
            if self._tipo_reporte_actual != 8:
                return {}
            
            # Obtener análisis avanzado del repository
            if hasattr(self.repository, 'get_analisis_financiero_avanzado'):
                analisis = self.repository.get_analisis_financiero_avanzado(
                    self._fecha_desde_actual, 
                    self._fecha_hasta_actual
                )
                return analisis
            else:
                return {}
                
        except Exception as e:
            print(f"❌ Error obteniendo análisis financiero: {e}")
            return {}
    
    @Slot(result=bool)
    def esReporteFinanciero(self) -> bool:
        """✅ NUEVO: Indica si el reporte actual es el financiero"""
        return self._tipo_reporte_actual == 8
    
    @Slot(result=str)
    def obtenerEstadoFinanciero(self) -> str:
        """✅ NUEVO: Obtiene el estado financiero actual (SUPERÁVIT/DÉFICIT)"""
        try:
            if self._tipo_reporte_actual != 8 or not self._resumen_reporte:
                return "N/A"
            
            return self._resumen_reporte.get('estadoFinanciero', 'N/A')
            
        except Exception as e:
            print(f"❌ Error obteniendo estado financiero: {e}")
            return "N/A"
    
    # ===============================
    # UTILIDADES
    # ===============================
    
    @Slot()
    def limpiarReporte(self):
        """Limpia el reporte actual"""
        self._datos_reporte = []
        self._resumen_reporte = {}
        self._estadisticas = {}
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
        if self._estadisticas:
            self.estadisticasChanged.emit()

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
    print("📊 ReportesModel registrado para QML con soporte para Reporte de Ingresos y Egresos")

# Para facilitar la importación
__all__ = ['ReportesModel', 'register_reportes_model']