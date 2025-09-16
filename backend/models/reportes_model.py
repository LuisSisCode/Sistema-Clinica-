from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import qmlRegisterType
import json

from ..repositories.reportes_repository import ReportesRepository
from ..core.excepciones import ExceptionHandler, ValidationError, DatabaseQueryError

class ReportesModel(QObject):
    """
    Model QObject para generación de reportes con autenticación estandarizada y control ultra-estricto
    Información financiera detallada solo para Administradores
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
        
        # ✅ AUTENTICACIÓN ESTANDARIZADA - COMO OTROS MODELS
        self._usuario_actual_id = 0  # Cambio de hardcoded a dinámico
        self._usuario_rol = ""       # NUEVO: Control de roles
        print("📊 ReportesModel inicializado - Esperando autenticación")
        
        # Referencia al AppController (se establecerá desde main.py)
        self._app_controller = None
        
        print("📊 ReportesModel inicializado con autenticación estandarizada y control ultra-estricto")
    
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
    
    @Slot(int, str)
    def set_usuario_actual_con_rol(self, usuario_id: int, rol: str):
        """
        NUEVO: Establece usuario + rol para control de permisos completo
        """
        try:
            if usuario_id > 0 and rol:
                self._usuario_actual_id = usuario_id
                self._usuario_rol = rol.strip()
                print(f"👤 Usuario autenticado con rol en ReportesModel: {usuario_id} - {rol}")
                
                mensaje = f"Usuario {usuario_id} ({rol}) establecido en reportes"
                if rol == "Médico":
                    mensaje += " - Solo reportes médicos básicos"
                self.operacionExitosa.emit(mensaje)
            else:
                self.operacionError.emit("Usuario o rol inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario con rol: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        """Property para obtener el usuario actual"""
        return self._usuario_actual_id
    
    @Property(str, notify=operacionExitosa)
    def usuario_rol(self):
        """Property para obtener el rol del usuario actual"""
        return self._usuario_rol
    
    # NUEVO: Método para establecer AppController
    def set_app_controller(self, app_controller):
        """Establece la referencia al AppController para acceso al PDF generator"""
        self._app_controller = app_controller
        print("🔗 AppController conectado al ReportesModel")
    
    # ===============================
    # PROPIEDADES DE AUTENTICACIÓN Y PERMISOS
    # ===============================
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica si el usuario está autenticado"""
        if self._usuario_actual_id <= 0:
            self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
            return False
        return True
    
    def _verificar_permisos(self, operacion: str) -> bool:
        """
        NUEVO: Verifica permisos específicos según el rol del usuario
        
        PERMISOS ULTRA-ESTRICTOS PARA REPORTES:
        - Admin: Acceso completo a todos los reportes financieros y médicos
        - Médico: Solo reportes médicos básicos SIN información financiera
        
        Args:
            operacion: Nombre de la operación a verificar
            
        Returns:
            bool: True si tiene permisos, False caso contrario
        """
        # Verificar autenticación primero
        if not self._verificar_autenticacion():
            return False
        
        # Admin tiene acceso completo
        if self._usuario_rol == "Administrador":
            return True
        
        # Reportes financieros - SOLO ADMIN
        reportes_financieros = [
            'reporte_ventas',           # Tipo 1
            'reporte_compras',          # Tipo 3  
            'reporte_gastos',           # Tipo 7
            'reporte_consolidado',      # Tipo 8
            'exportar_pdf_financiero'
        ]
        
        # Reportes con información de costos - SOLO ADMIN
        reportes_con_costos = [
            'reporte_inventario'        # Tipo 2 (incluye precios de compra)
        ]
        
        if operacion in reportes_financieros or operacion in reportes_con_costos:
            if self._usuario_rol != "Administrador":
                self.operacionError.emit("Reportes financieros solo disponibles para administradores")
                return False
        
        # Médico puede ver reportes médicos básicos (sin precios)
        if self._usuario_rol == "Médico":
            reportes_medicos_basicos = [
                'reporte_consultas_basico',    # Tipo 4 (sin precios)
                'reporte_laboratorio_basico',  # Tipo 5 (sin precios)  
                'reporte_enfermeria_basico'    # Tipo 6 (sin precios)
            ]
            
            if operacion in reportes_medicos_basicos:
                return True
        
        return True
    
    def _es_reporte_financiero(self, tipo_reporte: int) -> bool:
        """Determina si un tipo de reporte contiene información financiera"""
        reportes_financieros = [1, 2, 3, 7, 8]  # Ventas, Inventario, Compras, Gastos, Consolidado
        return tipo_reporte in reportes_financieros
    
    # ===============================
    # PROPERTIES - Datos para QML CON RESTRICCIONES
    # ===============================
    
    @Property(list, notify=datosReporteChanged)
    def datosReporte(self) -> List[Dict[str, Any]]:
        """Datos del reporte actual - FILTRADOS POR ROL"""
        if self._usuario_rol == "Médico":
            # Para médicos, filtrar información financiera de los datos
            return self._filtrar_datos_financieros(self._datos_reporte)
        return self._datos_reporte
    
    @Property('QVariantMap', notify=resumenChanged)
    def resumenReporte(self) -> Dict[str, Any]:
        """Resumen del reporte - SIN INFORMACIÓN FINANCIERA PARA MÉDICO"""
        if self._usuario_rol == "Médico":
            return self._filtrar_resumen_financiero(self._resumen_reporte)
        return self._resumen_reporte
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas generales - BÁSICAS PARA MÉDICO"""
        if self._usuario_rol == "Médico":
            return self._filtrar_estadisticas_financieras(self._estadisticas)
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
        return len(self.datosReporte)  # Usa la property que filtra por rol
    
    @Property(float, notify=resumenChanged)
    def totalValor(self) -> float:
        """Valor total del reporte - SOLO ADMIN VE VALORES"""
        if self._usuario_rol == "Médico":
            return 0.0  # Médico no ve valores monetarios
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
    # NUEVA PROPERTY PARA DETECTAR RESTRICCIONES EN UI
    # ===============================
    
    @Property(bool, notify=operacionExitosa)
    def esVistaLimitada(self):
        """Indica si el usuario tiene vista limitada (para ocultar elementos en UI)"""
        return self._usuario_rol == "Médico"
    
    # ===============================
    # SLOTS - Métodos con CONTROL ESTRICTO DE PERMISOS
    # ===============================
    
    @Slot(int, str, str, result=bool)
    def generarReporte(self, tipo_reporte: int, fecha_desde: str, fecha_hasta: str) -> bool:
        """
        Genera reporte con VERIFICACIÓN ESTRICTA DE PERMISOS
        """
        try:
            self._set_loading(True)
            self._set_progress(10)
            
            # ✅ VERIFICAR AUTENTICACIÓN PRIMERO
            if not self._verificar_autenticacion():
                return False
            
            # ✅ VERIFICAR PERMISOS SEGÚN TIPO DE REPORTE
            if self._es_reporte_financiero(tipo_reporte):
                if not self._verificar_permisos('reporte_ventas'):  # Usar cualquier permiso financiero
                    return False
            
            print(f"📊 Generando reporte tipo {tipo_reporte} - Usuario: {self._usuario_actual_id} ({self._usuario_rol})")
            
            # Validar parámetros
            if tipo_reporte < 1 or tipo_reporte > 8:
                raise ValidationError("tipo_reporte", tipo_reporte, "Tipo de reporte inválido")
            
            # ✅ RESTRICCIÓN ADICIONAL: Médico solo puede generar reportes 4, 5, 6
            if self._usuario_rol == "Médico":
                reportes_permitidos_medico = [4, 5, 6]  # Consultas, Lab, Enfermería
                if tipo_reporte not in reportes_permitidos_medico:
                    self.operacionError.emit("Solo puede generar reportes médicos básicos")
                    return False
                print(f"👨‍⚕️ Médico generando reporte médico básico tipo {tipo_reporte}")
            
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
                if self._usuario_rol == "Médico":
                    mensaje_resultado += " (vista básica sin información financiera)"
                
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
        """Calcula resumen estadístico - FILTRA INFORMACIÓN FINANCIERA PARA MÉDICO"""
        try:
            if not datos:
                return {}
            
            total_registros = len(datos)
            total_valor = 0.0
            total_cantidad = 0
            
            # ✅ SOLO CALCULAR VALORES FINANCIEROS SI ES ADMIN
            if self._usuario_rol == "Administrador":
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
            
            # ✅ RESUMEN DIFERENTE SEGÚN ROL
            if self._usuario_rol == "Médico":
                # Médico solo ve contadores básicos
                return {
                    'totalRegistros': total_registros,
                    'totalCantidad': total_cantidad,
                    'fechaGeneracion': self._fecha_desde_actual,
                    'fechaHasta': self._fecha_hasta_actual,
                    'tipoReporte': self._tipo_reporte_actual,
                    'vistaLimitada': True
                }
            else:
                # Admin ve información financiera completa
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
    
    # ===============================
    # MÉTODOS DE FILTRADO PARA MÉDICOS
    # ===============================
    
    def _filtrar_datos_financieros(self, datos: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Filtra información financiera de los datos para médicos"""
        try:
            datos_filtrados = []
            for registro in datos:
                registro_filtrado = {}
                for clave, valor in registro.items():
                    # Excluir campos financieros
                    campos_financieros = [
                        'precio', 'costo', 'valor', 'total', 'subtotal',
                        'precio_compra', 'precio_venta', 'monto', 'importe'
                    ]
                    
                    if not any(campo in clave.lower() for campo in campos_financieros):
                        registro_filtrado[clave] = valor
                    else:
                        # Ocultar información financiera
                        registro_filtrado[clave] = "***"
                
                datos_filtrados.append(registro_filtrado)
            
            return datos_filtrados
            
        except Exception as e:
            print(f"❌ Error filtrando datos financieros: {e}")
            return datos
    
    def _filtrar_resumen_financiero(self, resumen: Dict[str, Any]) -> Dict[str, Any]:
        """Filtra información financiera del resumen para médicos"""
        try:
            if not resumen:
                return {}
            
            resumen_filtrado = {}
            for clave, valor in resumen.items():
                if 'valor' not in clave.lower() and 'precio' not in clave.lower():
                    resumen_filtrado[clave] = valor
            
            # Agregar indicador de vista limitada
            resumen_filtrado['vistaLimitada'] = True
            return resumen_filtrado
            
        except Exception as e:
            print(f"❌ Error filtrando resumen: {e}")
            return resumen
    
    def _filtrar_estadisticas_financieras(self, estadisticas: Dict[str, Any]) -> Dict[str, Any]:
        """Filtra estadísticas financieras para médicos"""
        try:
            if not estadisticas:
                return {}
            
            estadisticas_basicas = {}
            for clave, valor in estadisticas.items():
                if not any(financiero in clave.lower() for financiero in ['valor', 'precio', 'costo', 'monto']):
                    estadisticas_basicas[clave] = valor
            
            return estadisticas_basicas
            
        except Exception as e:
            print(f"❌ Error filtrando estadísticas: {e}")
            return estadisticas
    
    # ===============================
    # EXPORTACIÓN A PDF CON RESTRICCIONES
    # ===============================
    
    @Slot(result=str)
    def exportarPDF(self) -> str:
        """Exporta el reporte actual a PDF - CON VERIFICACIÓN DE PERMISOS"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN
            if not self._verificar_autenticacion():
                return ""
            
            if not self._datos_reporte:
                self.reporteError.emit("Sin Datos", "No hay datos para exportar")
                return ""
            
            # ✅ VERIFICAR PERMISOS PARA EXPORTACIÓN
            if self._es_reporte_financiero(self._tipo_reporte_actual):
                if not self._verificar_permisos('exportar_pdf_financiero'):
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
            
            print(f"📄 Iniciando exportación PDF - Usuario: {self._usuario_actual_id} ({self._usuario_rol})")
            print(f"📄 Tipo: {self._tipo_reporte_actual}, Registros: {len(self._datos_reporte)}")
            
            # ✅ USAR DATOS FILTRADOS SEGÚN ROL
            datos_para_pdf = self.datosReporte  # Usa la property que filtra por rol
            datos_json = json.dumps(datos_para_pdf, default=str)
            
            # Usar AppController para generar PDF
            ruta_pdf = self._app_controller.generarReportePDF(
                datos_json,
                str(self._tipo_reporte_actual),
                self._fecha_desde_actual,
                self._fecha_hasta_actual
            )
            
            if ruta_pdf:
                mensaje_exito = f"PDF exportado exitosamente: {ruta_pdf}"
                if self._usuario_rol == "Médico":
                    mensaje_exito += " (información financiera oculta)"
                
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
    # CONSULTAS ESPECIALES CON RESTRICCIONES
    # ===============================
    
    @Slot(result='QVariantMap')
    def obtenerResumenPeriodo(self) -> Dict[str, Any]:
        """Obtiene resumen financiero - SOLO ADMIN"""
        try:
            # ✅ VERIFICAR PERMISOS FINANCIEROS
            if not self._verificar_permisos('reporte_consolidado'):
                return {}
            
            if not self._fecha_desde_actual or not self._fecha_hasta_actual:
                return {}
            
            resumen = self.repository.get_resumen_periodo(
                self._fecha_desde_actual, 
                self._fecha_hasta_actual
            )
            
            # Filtrar según rol
            if self._usuario_rol == "Médico":
                return self._filtrar_resumen_financiero(resumen)
            
            return resumen
            
        except Exception as e:
            print(f"❌ Error obteniendo resumen del período: {e}")
            return {}
    
    @Slot(int, str, str, result=bool)
    def verificarDatosDisponibles(self, tipo_reporte: int, fecha_desde: str, fecha_hasta: str) -> bool:
        """Verifica si hay datos disponibles para el reporte"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN
            if not self._verificar_autenticacion():
                return False
            
            return self.repository.verificar_datos_disponibles(tipo_reporte, fecha_desde, fecha_hasta)
        except Exception as e:
            print(f"❌ Error verificando datos: {e}")
            return False
    
    @Slot(result=str)
    def obtenerDatosJSON(self) -> str:
        """Obtiene los datos del reporte actual en formato JSON - FILTRADOS POR ROL"""
        try:
            # ✅ USAR DATOS FILTRADOS
            datos_filtrados = self.datosReporte  # Property que filtra por rol
            return json.dumps(datos_filtrados, default=str, ensure_ascii=False)
        except Exception as e:
            print(f"❌ Error convirtiendo a JSON: {e}")
            return "[]"
    
    @Slot(result=list)
    def obtenerTiposReportes(self) -> List[Dict[str, Any]]:
        """Obtiene lista de tipos de reportes - FILTRADA POR ROL"""
        todos_reportes = [
            {"id": 1, "nombre": "Ventas de Farmacia", "requiere_fechas": True, "financiero": True},
            {"id": 2, "nombre": "Inventario de Productos", "requiere_fechas": False, "financiero": True},
            {"id": 3, "nombre": "Compras de Farmacia", "requiere_fechas": True, "financiero": True},
            {"id": 4, "nombre": "Consultas Médicas", "requiere_fechas": True, "financiero": False},
            {"id": 5, "nombre": "Análisis de Laboratorio", "requiere_fechas": True, "financiero": False},
            {"id": 6, "nombre": "Procedimientos de Enfermería", "requiere_fechas": True, "financiero": False},
            {"id": 7, "nombre": "Gastos Operativos", "requiere_fechas": True, "financiero": True},
            {"id": 8, "nombre": "Reporte Financiero Consolidado", "requiere_fechas": True, "financiero": True}
        ]
        
        # ✅ FILTRAR SEGÚN ROL
        if self._usuario_rol == "Médico":
            # Solo reportes médicos básicos
            reportes_medico = [reporte for reporte in todos_reportes if not reporte["financiero"]]
            return reportes_medico
        
        return todos_reportes
    
    # ===============================
    # UTILIDADES CON VERIFICACIÓN
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
        """Refresca el caché del sistema - SOLO ADMIN"""
        try:
            # ✅ SOLO ADMIN PUEDE REFRESCAR CACHE
            if self._usuario_rol != "Administrador":
                self.operacionError.emit("Solo administradores pueden refrescar el caché")
                return
            
            self.repository.refresh_cache()
            self.operacionExitosa.emit("Caché refrescado por administrador")
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
            self._usuario_rol = ""       # ✅ RESETEAR ROL
            
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
    print("📊 ReportesModel registrado para QML con autenticación estandarizada y control ultra-estricto")

# Para facilitar la importación
__all__ = ['ReportesModel', 'register_reportes_model']