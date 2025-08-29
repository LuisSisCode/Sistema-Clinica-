"""
Modelo QObject para enfermería - Interfaz entre QML y el repositorio de enfermería
"""

import logging
from typing import List, Dict, Any, Optional
from decimal import Decimal
from datetime import datetime

from PySide6.QtCore import QObject, Signal, Slot, Property, QJsonValue
from PySide6.QtQml import qmlRegisterType

from ..core.database_conexion import DatabaseConnection
from ..repositories.enfermeria_repository import EnfermeriaRepository

# Configurar logging
logger = logging.getLogger(__name__)

class EnfermeriaModel(QObject):
    """
    Modelo QObject para manejar datos de enfermería en QML
    """
    
    # ===============================
    # SEÑALES (SIGNALS)
    # ===============================
    
    # Señales de operaciones exitosas
    operacionExitosa = Signal(str)
    procedimientoCreado = Signal(bool, str)  # success, message
    procedimientoActualizado = Signal(bool, str)
    procedimientoEliminado = Signal(bool, str)
    
    # Señales de errores
    operacionError = Signal(str)
    errorOccurred = Signal(str)
    
    # Señales de datos actualizados
    procedimientosActualizados = Signal()
    tiposProcedimientosActualizados = Signal()
    trabajadoresActualizados = Signal()
    estadisticasActualizadas = Signal()
    
    # Señales para notificaciones
    successMessage = Signal(str)
    warningMessage = Signal(str)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        try:
            # Inicializar conexión a base de datos y repositorio
            self.db_connection = DatabaseConnection()
            self.repository = EnfermeriaRepository(self.db_connection)
            
            # Cache interno de datos
            self._procedimientos = []
            self._tipos_procedimientos = []
            self._trabajadores_enfermeria = []
            self._estadisticas = {}
            self._usuario_actual_id = None
            
            # Cargar datos iniciales
            self._cargar_datos_iniciales()
            
            logger.info("EnfermeriaModel inicializado correctamente")
            
        except Exception as e:
            logger.error(f"Error inicializando EnfermeriaModel: {e}")
            self.errorOccurred.emit(f"Error inicializando módulo de enfermería: {str(e)}")
    
    # ===============================
    # PROPIEDADES (PROPERTIES)
    # ===============================
    
    @Property(list, notify=procedimientosActualizados)
    def procedimientos(self) -> List[Dict[str, Any]]:
        """Lista de procedimientos de enfermería"""
        return self._procedimientos
    
    @Property(list, notify=tiposProcedimientosActualizados)
    def tiposProcedimientos(self) -> List[Dict[str, Any]]:
        """Lista de tipos de procedimientos disponibles"""
        return self._tipos_procedimientos
    
    @Property(list, notify=trabajadoresActualizados)
    def trabajadoresEnfermeria(self) -> List[Dict[str, Any]]:
        """Lista de trabajadores que pueden realizar procedimientos de enfermería"""
        return self._trabajadores_enfermeria
    
    @Property('QVariant', notify=estadisticasActualizadas)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas de enfermería"""
        return self._estadisticas
    
    # ===============================
    # MÉTODOS DE INICIALIZACIÓN
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga los datos iniciales al inicializar el modelo"""
        try:
            logger.info("Cargando datos iniciales de enfermería...")
            
            # Cargar tipos de procedimientos
            self.actualizar_tipos_procedimientos()
            
            # Cargar trabajadores
            self.actualizar_trabajadores_enfermeria()
            
            # Cargar procedimientos
            self.actualizar_procedimientos()
            
            # Cargar estadísticas
            self.actualizar_estadisticas()
            
            logger.info("Datos iniciales de enfermería cargados correctamente")
            
        except Exception as e:
            logger.error(f"Error cargando datos iniciales: {e}")
            self.errorOccurred.emit("Error cargando datos iniciales de enfermería")
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """
        Establece el usuario actual para las operaciones
        
        Args:
            usuario_id (int): ID del usuario actual
        """
        self._usuario_actual_id = usuario_id
        logger.info(f"Usuario actual establecido en EnfermeriaModel: {usuario_id}")
    
    # ===============================
    # SLOTS PARA PROCEDIMIENTOS
    # ===============================
    
    @Slot()
    def actualizar_procedimientos(self):
        """Actualiza la lista de procedimientos desde la base de datos"""
        try:
            logger.info("Actualizando procedimientos de enfermería...")
            self._procedimientos = self.repository.obtener_procedimientos_enfermeria()
            self.procedimientosActualizados.emit()
            logger.info(f"Procedimientos actualizados: {len(self._procedimientos)} registros")
            
        except Exception as e:
            logger.error(f"Error actualizando procedimientos: {e}")
            self.operacionError.emit("Error actualizando lista de procedimientos")
    
    @Slot('QVariant')
    def crear_procedimiento(self, datos_json: QJsonValue):
        """
        Crea un nuevo procedimiento de enfermería
        
        Args:
            datos_json (QJsonValue): Datos del procedimiento en formato JSON
        """
        try:
            # Convertir QJsonValue a diccionario Python
            datos = self._convertir_json_a_dict(datos_json)
            
            # Validar datos requeridos
            if not self._validar_datos_procedimiento(datos):
                self.procedimientoCreado.emit(False, "Datos incompletos o inválidos")
                return
            
            # Preparar datos para el repositorio
            datos_procedimiento = {
                'nombreCompleto': datos.get('paciente', ''),
                'cedula': datos.get('cedula', ''),
                'idProcedimiento': int(datos.get('idProcedimiento', 0)),
                'cantidad': int(datos.get('cantidad', 1)),
                'tipo': datos.get('tipo', 'Normal'),
                'idTrabajador': int(datos.get('idTrabajador', 0)),
                'idRegistradoPor': self._usuario_actual_id or 1,
                'fecha': datetime.now()
            }
            # Debug: mostrar datos antes de enviar al repositorio
            logger.info(f"Datos del procedimiento preparados: {datos_procedimiento}")
            
            # Crear el procedimiento
            procedimiento_id = self.repository.crear_procedimiento_enfermeria(datos_procedimiento)
            
            if procedimiento_id:
                # Actualizar la lista de procedimientos
                self.actualizar_procedimientos()
                
                self.procedimientoCreado.emit(True, f"Procedimiento creado exitosamente (ID: {procedimiento_id})")
                self.operacionExitosa.emit("Procedimiento de enfermería registrado correctamente")
                logger.info(f"Procedimiento creado con ID: {procedimiento_id}")
            else:
                self.procedimientoCreado.emit(False, "Error al crear el procedimiento")
                self.operacionError.emit("Error al registrar el procedimiento de enfermería")
                
        except Exception as e:
            logger.error(f"Error creando procedimiento: {e}")
            self.procedimientoCreado.emit(False, f"Error: {str(e)}")
            self.operacionError.emit("Error al crear procedimiento de enfermería")
    
    @Slot(int, 'QVariant')
    def actualizar_procedimiento(self, procedimiento_id: int, datos_json: QJsonValue):
        """
        Actualiza un procedimiento existente
        
        Args:
            procedimiento_id (int): ID del procedimiento a actualizar
            datos_json (QJsonValue): Nuevos datos del procedimiento
        """
        try:
            # Convertir datos
            datos = self._convertir_json_a_dict(datos_json)
            
            # Validar datos
            if not self._validar_datos_procedimiento(datos):
                self.procedimientoActualizado.emit(False, "Datos incompletos o inválidos")
                return
            
            # Preparar datos para el repositorio
            datos_procedimiento = {
                'nombreCompleto': datos.get('paciente', ''),
                'cedula': datos.get('cedula', ''),
                'idProcedimiento': int(datos.get('idProcedimiento', 0)),
                'cantidad': int(datos.get('cantidad', 1)),
                'tipo': datos.get('tipo', 'Normal'),
                'idTrabajador': int(datos.get('idTrabajador', 0))
            }
            
            # Actualizar el procedimiento
            exito = self.repository.actualizar_procedimiento_enfermeria(procedimiento_id, datos_procedimiento)
            
            if exito:
                # Actualizar la lista
                self.actualizar_procedimientos()
                
                self.procedimientoActualizado.emit(True, "Procedimiento actualizado exitosamente")
                self.operacionExitosa.emit("Procedimiento actualizado correctamente")
                logger.info(f"Procedimiento actualizado: {procedimiento_id}")
            else:
                self.procedimientoActualizado.emit(False, "Error al actualizar el procedimiento")
                self.operacionError.emit("Error al actualizar el procedimiento")
                
        except Exception as e:
            logger.error(f"Error actualizando procedimiento: {e}")
            self.procedimientoActualizado.emit(False, f"Error: {str(e)}")
            self.operacionError.emit("Error al actualizar procedimiento")
    
    @Slot(int)
    def eliminar_procedimiento(self, procedimiento_id: int):
        """
        Elimina un procedimiento de enfermería
        
        Args:
            procedimiento_id (int): ID del procedimiento a eliminar
        """
        try:
            exito = self.repository.eliminar_procedimiento_enfermeria(procedimiento_id)
            
            if exito:
                # Actualizar la lista
                self.actualizar_procedimientos()
                
                self.procedimientoEliminado.emit(True, "Procedimiento eliminado exitosamente")
                self.operacionExitosa.emit("Procedimiento eliminado correctamente")
                logger.info(f"Procedimiento eliminado: {procedimiento_id}")
            else:
                self.procedimientoEliminado.emit(False, "Error al eliminar el procedimiento")
                self.operacionError.emit("Error al eliminar el procedimiento")
                
        except Exception as e:
            logger.error(f"Error eliminando procedimiento: {e}")
            self.procedimientoEliminado.emit(False, f"Error: {str(e)}")
            self.operacionError.emit("Error al eliminar procedimiento")
    
    # ===============================
    # SLOTS PARA PAGINACIÓN Y FILTROS (NUEVOS)
    # ===============================
    
    @Slot(int, int, 'QVariant', result=list)
    def obtener_procedimientos_paginados(self, offset: int, limit: int, filtros_json):
        """
        Obtiene procedimientos paginados con filtros aplicados
        
        Args:
            offset (int): Desplazamiento para paginación
            limit (int): Límite de registros por página
            filtros_json: Filtros en formato JSON de QML
            
        Returns:
            List[Dict]: Lista de procedimientos paginados
        """
        try:
            # Convertir filtros de QML a diccionario Python
            filtros = self._convertir_json_a_dict(filtros_json) if filtros_json else {}
            
            logger.info(f"Obteniendo procedimientos paginados: offset={offset}, limit={limit}, filtros={filtros}")
            
            # Llamar al repositorio
            procedimientos = self.repository.obtener_procedimientos_paginados(offset, limit, filtros)
            
            logger.info(f"Obtenidos {len(procedimientos)} procedimientos paginados")
            return procedimientos
            
        except Exception as e:
            logger.error(f"Error obteniendo procedimientos paginados: {e}")
            self.operacionError.emit("Error obteniendo procedimientos paginados")
            return []
    
    @Slot('QVariant', result=int)
    def contar_procedimientos_filtrados(self, filtros_json):
        """
        Cuenta el total de procedimientos que cumplen con los filtros
        
        Args:
            filtros_json: Filtros en formato JSON de QML
            
        Returns:
            int: Total de procedimientos
        """
        try:
            # Convertir filtros de QML a diccionario Python
            filtros = self._convertir_json_a_dict(filtros_json) if filtros_json else {}
            
            logger.info(f"Contando procedimientos con filtros: {filtros}")
            
            # Llamar al repositorio
            total = self.repository.contar_procedimientos_filtrados(filtros)
            
            logger.info(f"Total de procedimientos encontrados: {total}")
            return total
            
        except Exception as e:
            logger.error(f"Error contando procedimientos filtrados: {e}")
            self.operacionError.emit("Error contando procedimientos")
            return 0
    
    # ===============================
    # SLOTS PARA TIPOS DE PROCEDIMIENTOS
    # ===============================
    
    @Slot()
    def actualizar_tipos_procedimientos(self):
        """Actualiza la lista de tipos de procedimientos"""
        try:
            logger.info("Actualizando tipos de procedimientos...")
            self._tipos_procedimientos = self.repository.obtener_tipos_procedimientos()
            self.tiposProcedimientosActualizados.emit()
            logger.info(f"Tipos de procedimientos actualizados: {len(self._tipos_procedimientos)} tipos")
            
        except Exception as e:
            logger.error(f"Error actualizando tipos de procedimientos: {e}")
            self.operacionError.emit("Error actualizando tipos de procedimientos")
    
    @Slot('QVariant')
    def crear_tipo_procedimiento(self, datos_json: QJsonValue):
        """
        Crea un nuevo tipo de procedimiento
        
        Args:
            datos_json (QJsonValue): Datos del tipo de procedimiento
        """
        try:
            datos = self._convertir_json_a_dict(datos_json)
            
            # Validar datos
            if not datos.get('nombre') or not datos.get('precioNormal') or not datos.get('precioEmergencia'):
                self.operacionError.emit("Datos incompletos para crear tipo de procedimiento")
                return
            
            exito = self.repository.crear_tipo_procedimiento(datos)
            
            if exito:
                self.actualizar_tipos_procedimientos()
                self.operacionExitosa.emit("Tipo de procedimiento creado exitosamente")
            else:
                self.operacionError.emit("Error al crear tipo de procedimiento")
                
        except Exception as e:
            logger.error(f"Error creando tipo de procedimiento: {e}")
            self.operacionError.emit("Error al crear tipo de procedimiento")
    
    # ===============================
    # SLOTS PARA TRABAJADORES
    # ===============================
    
    @Slot()
    def actualizar_trabajadores_enfermeria(self):
        """Actualiza la lista de trabajadores de enfermería"""
        try:
            logger.info("Actualizando trabajadores de enfermería...")
            trabajadores_db = self.repository.obtener_trabajadores_enfermeria()
            
            # Convertir a lista de strings para QML
            self._trabajadores_enfermeria = []
            for trabajador in trabajadores_db:
                self._trabajadores_enfermeria.append(trabajador['nombreCompleto'])
            
            self.trabajadoresActualizados.emit()
            logger.info(f"Trabajadores actualizados: {len(self._trabajadores_enfermeria)} trabajadores")
            
        except Exception as e:
            logger.error(f"Error actualizando trabajadores: {e}")
            self.operacionError.emit("Error actualizando trabajadores de enfermería")
    
    # ===============================
    # SLOTS PARA BÚSQUEDA Y FILTROS
    # ===============================
    
    @Slot(str, result=list)
    def buscar_pacientes(self, termino_busqueda: str) -> List[Dict[str, Any]]:
        """
        Busca pacientes por nombre o cédula
        
        Args:
            termino_busqueda (str): Término a buscar
            
        Returns:
            List[Dict]: Lista de pacientes encontrados
        """
        try:
            if len(termino_busqueda.strip()) < 2:
                return []
                
            return self.repository.buscar_pacientes(termino_busqueda)
            
        except Exception as e:
            logger.error(f"Error buscando pacientes: {e}")
            self.operacionError.emit("Error en búsqueda de pacientes")
            return []
    
    @Slot('QVariant')
    def filtrar_procedimientos(self, filtros_json: QJsonValue):
        """
        Filtra procedimientos según criterios específicos
        
        Args:
            filtros_json (QJsonValue): Filtros en formato JSON
        """
        try:
            filtros = self._convertir_json_a_dict(filtros_json)
            procedimientos_filtrados = self.repository.obtener_procedimientos_enfermeria(filtros)
            self._procedimientos = procedimientos_filtrados
            self.procedimientosActualizados.emit()
            
        except Exception as e:
            logger.error(f"Error filtrando procedimientos: {e}")
            self.operacionError.emit("Error aplicando filtros")
    
    @Slot(str, result=list)
    def buscar_procedimientos(self, termino_busqueda: str) -> List[Dict[str, Any]]:
        """
        Busca procedimientos por término de búsqueda
        
        Args:
            termino_busqueda (str): Término a buscar
            
        Returns:
            List[Dict]: Lista de procedimientos encontrados
        """
        try:
            if len(termino_busqueda.strip()) < 2:
                return []
                
            return self.repository.buscar_procedimientos(termino_busqueda)
            
        except Exception as e:
            logger.error(f"Error buscando procedimientos: {e}")
            self.operacionError.emit("Error en búsqueda de procedimientos")
            return []
    
    # ===============================
    # SLOTS PARA ESTADÍSTICAS
    # ===============================
    
    @Slot()
    def actualizar_estadisticas(self):
        """Actualiza las estadísticas de enfermería"""
        try:
            logger.info("Actualizando estadísticas de enfermería...")
            self._estadisticas = self.repository.obtener_estadisticas_enfermeria('mes')
            self.estadisticasActualizadas.emit()
            logger.info("Estadísticas actualizadas")
            
        except Exception as e:
            logger.error(f"Error actualizando estadísticas: {e}")
            self.operacionError.emit("Error actualizando estadísticas")
    
    @Slot(str)
    def actualizar_estadisticas_periodo(self, periodo: str):
        """
        Actualiza estadísticas para un período específico
        
        Args:
            periodo (str): Periodo ('dia', 'semana', 'mes', 'año')
        """
        try:
            self._estadisticas = self.repository.obtener_estadisticas_enfermeria(periodo)
            self.estadisticasActualizadas.emit()
            
        except Exception as e:
            logger.error(f"Error actualizando estadísticas por período: {e}")
            self.operacionError.emit(f"Error actualizando estadísticas del {periodo}")
    
    # ===============================
    # SLOTS PARA REPORTES
    # ===============================
    
    @Slot(str, str, str, result='QVariant')
    def generar_reporte_enfermeria(self, tipo_reporte: str, fecha_desde: str = "", fecha_hasta: str = ""):
        """
        Genera datos para reportes de enfermería
        
        Args:
            tipo_reporte (str): Tipo de reporte
            fecha_desde (str): Fecha de inicio (opcional)
            fecha_hasta (str): Fecha de fin (opcional)
            
        Returns:
            Dict: Datos del reporte
        """
        try:
            if tipo_reporte == "procedimientos":
                return self._procedimientos
            elif tipo_reporte == "estadisticas":
                return self._estadisticas
            elif tipo_reporte == "tipos_procedimientos":
                return self._tipos_procedimientos
            elif tipo_reporte == "trabajadores":
                return self._trabajadores_enfermeria
            else:
                return {}
                
        except Exception as e:
            logger.error(f"Error generando reporte: {e}")
            self.operacionError.emit("Error generando reporte de enfermería")
            return {}
    
    # ===============================
    # MÉTODOS AUXILIARES
    # ===============================
    
    def _convertir_json_a_dict(self, json_value) -> Dict[str, Any]:
        """
        Convierte un valor JSON de QML a diccionario Python
        
        Args:
            json_value: Valor JSON de QML
            
        Returns:
            Dict: Diccionario Python
        """
        try:
            if json_value is None:
                return {}
                
            # Si es QJsonValue
            if hasattr(json_value, 'toVariant'):
                return json_value.toVariant()
            
            # Si es un diccionario Python
            if isinstance(json_value, dict):
                return json_value
                
            # Si es otro tipo, intentar convertir
            return dict(json_value) if json_value else {}
            
        except Exception as e:
            logger.error(f"Error convirtiendo JSON: {e}")
            return {}
    
    def _validar_datos_procedimiento(self, datos: Dict[str, Any]) -> bool:
        """
        Valida los datos de un procedimiento
        
        Args:
            datos (Dict): Datos del procedimiento
            
        Returns:
            bool: True si los datos son válidos
        """
        try:
            # Validaciones básicas
            if not datos.get('paciente', '').strip():
                logger.warning("Validación falló: paciente vacío")
                return False
            
            if not datos.get('idProcedimiento') or int(datos.get('idProcedimiento', 0)) <= 0:
                logger.warning("Validación falló: idProcedimiento inválido")
                return False
            
            if not datos.get('idTrabajador') or int(datos.get('idTrabajador', 0)) <= 0:
                logger.warning("Validación falló: idTrabajador inválido")
                return False
            
            if int(datos.get('cantidad', 0)) <= 0:
                logger.warning("Validación falló: cantidad inválida")
                return False
            
            if datos.get('tipo') not in ['Normal', 'Emergencia']:
                logger.warning("Validación falló: tipo inválido")
                return False
            
            return True
            
        except (ValueError, TypeError) as e:
            logger.error(f"Error validando datos: {e}")
            return False
    
    # ===============================
    # SLOTS PARA OBTENER DATOS ESPECÍFICOS
    # ===============================
    
    @Slot(int, result='QVariant')
    def obtener_procedimiento_por_id(self, procedimiento_id: int):
        """
        Obtiene un procedimiento específico por su ID
        
        Args:
            procedimiento_id (int): ID del procedimiento
            
        Returns:
            Dict: Datos del procedimiento o vacío si no se encuentra
        """
        try:
            for proc in self._procedimientos:
                if int(proc.get('procedimientoId', 0)) == procedimiento_id:
                    return proc
            return {}
        except Exception as e:
            logger.error(f"Error obteniendo procedimiento por ID: {e}")
            return {}
    
    @Slot(int, result='QVariant')
    def obtener_tipo_procedimiento_por_id(self, tipo_id: int):
        """
        Obtiene un tipo de procedimiento específico por su ID
        
        Args:
            tipo_id (int): ID del tipo de procedimiento
            
        Returns:
            Dict: Datos del tipo de procedimiento
        """
        try:
            for tipo in self._tipos_procedimientos:
                if tipo.get('id') == tipo_id:
                    return tipo
            return {}
        except Exception as e:
            logger.error(f"Error obteniendo tipo de procedimiento por ID: {e}")
            return {}
    
    @Slot(result=int)
    def obtener_total_procedimientos(self) -> int:
        """
        Obtiene el total de procedimientos registrados
        
        Returns:
            int: Número total de procedimientos
        """
        return len(self._procedimientos)
    
    @Slot(result=bool)
    def tiene_conexion_bd(self) -> bool:
        """
        Verifica si hay conexión a la base de datos
        
        Returns:
            bool: True si hay conexión
        """
        try:
            with self.db_connection.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                return True
        except Exception as e:
            logger.error(f"Error verificando conexión BD: {e}")
            return False
    
    # ===============================
    # SLOTS PARA DEBUG Y LOGGING
    # ===============================
    
    @Slot(str)
    def log_debug(self, mensaje: str):
        """
        Registra un mensaje de debug desde QML
        
        Args:
            mensaje (str): Mensaje a registrar
        """
        logger.debug(f"QML Debug: {mensaje}")
    
    @Slot(str)
    def log_info(self, mensaje: str):
        """
        Registra un mensaje informativo desde QML
        
        Args:
            mensaje (str): Mensaje a registrar
        """
        logger.info(f"QML Info: {mensaje}")
    
    @Slot(str)
    def log_error(self, mensaje: str):
        """
        Registra un mensaje de error desde QML
        
        Args:
            mensaje (str): Mensaje a registrar
        """
        logger.error(f"QML Error: {mensaje}")

# ===============================
# FUNCIÓN DE REGISTRO PARA QML
# ===============================

def register_enfermeria_model():
    """Registra el EnfermeriaModel para su uso en QML"""
    try:
        qmlRegisterType(EnfermeriaModel, "EnfermeriaModel", 1, 0, "EnfermeriaModel")
        logger.info("EnfermeriaModel registrado correctamente para QML")
    except Exception as e:
        logger.error(f"Error registrando EnfermeriaModel: {e}")
        raise
@Slot(str, result='QVariant')
def buscar_paciente_por_cedula(self, cedula: str):
    """
    Busca un paciente específico por su cédula
    
    Args:
        cedula (str): Cédula del paciente
        
    Returns:
        Dict: Datos del paciente encontrado o diccionario vacío
    """
    try:
        if len(cedula.strip()) < 6:
            return {}
        
        logger.info(f"Buscando paciente por cédula: {cedula}")
        
        # Buscar en el repositorio
        paciente = self.repository.buscar_paciente_por_cedula_exacta(cedula.strip())
        
        if paciente:
            logger.info(f"Paciente encontrado: {paciente.get('nombreCompleto', 'N/A')}")
            return paciente
        else:
            logger.info(f"No se encontró paciente con cédula: {cedula}")
            return {}
            
    except Exception as e:
        logger.error(f"Error buscando paciente por cédula: {e}")
        self.operacionError.emit("Error buscando paciente por cédula")
        return {}