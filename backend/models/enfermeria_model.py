"""
Modelo QObject para Enfermería ACTUALIZADO - CORREGIDO con set_usuario_actual
Incluye: búsqueda inteligente, creación automática de pacientes, filtros del repositorio, etc.
CORREGIDO: Usuario por defecto simple + método actualizar_procedimiento separado + set_usuario_actual
"""

import logging
from typing import List, Dict, Any, Optional
from decimal import Decimal
from datetime import datetime

from PySide6.QtCore import QObject, Signal, Slot, Property, QJsonValue, QTimer
from PySide6.QtQml import qmlRegisterType

from ..core.database_conexion import DatabaseConnection
from ..repositories.enfermeria_repository import EnfermeriaRepository

# Configurar logging
logger = logging.getLogger(__name__)

class EnfermeriaModel(QObject):
    """
    Modelo QObject ACTUALIZADO para Enfermería con funcionalidades avanzadas
    Basado en el patrón de ConsultaModel - SIMPLIFICADO usuario + CRUD separado + set_usuario_actual
    """
    
    # ===============================
    # SIGNALS ACTUALIZADAS - Como ConsultaModel
    # ===============================
    
    # Operaciones CRUD con datos detallados
    procedimientoCreado = Signal(str, arguments=['datos'])  # JSON con datos del procedimiento
    procedimientoActualizado = Signal(str, arguments=['datos'])
    procedimientoEliminado = Signal(int, arguments=['procedimientoId'])
    
    # NUEVAS SEÑALES para búsqueda por cédula (como Consultas)
    pacienteEncontradoPorCedula = Signal('QVariantMap', arguments=['pacienteData'])
    pacienteNoEncontrado = Signal(str, arguments=['cedula'])
    
    # Búsquedas y filtros
    resultadosBusqueda = Signal(str, arguments=['resultados'])  # JSON
    filtrosAplicados = Signal(str, arguments=['criterios'])
    
    # Estados y notificaciones (como Consultas)
    estadoCambiado = Signal(str, arguments=['nuevoEstado'])
    errorOccurred = Signal(str, arguments=['mensaje'])  # CORREGIDO el nombre del signal
    successMessage = Signal(str, arguments=['mensaje'])  # AÑADIDO para consistencia con otros modelos
    operacionExitosa = Signal(str, arguments=['mensaje'])
    
    # Datos actualizados
    procedimientosRecientesChanged = Signal()
    tiposProcedimientosChanged = Signal()
    trabajadoresChanged = Signal()
    
    # Señales heredadas (compatibilidad)
    operacionError = Signal(str)  # AÑADIDO para compatibilidad con AppController
    procedimientoCreado_old = Signal(bool, str)  # Mantener compatibilidad
    procedimientosActualizados = Signal()
    tiposProcedimientosActualizados = Signal()
    trabajadoresActualizados = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        try:
            # Inicializar conexión y repositorio
            self.db_connection = DatabaseConnection()
            self.repository = EnfermeriaRepository(self.db_connection)
            
            # Estados internos (como ConsultaModel)
            self._procedimientosData = []
            self._tiposProcedimientosData = []
            self._trabajadoresData = []
            self._estadisticasData = {}
            self._estadoActual = "listo"  # listo, cargando, error
            
            # ✅ USUARIO AGREGADO - igual que ConsultaModel ahora
            self._usuario_actual_id = 10  # Usuario por defecto
            
            # Configuración
            self._autoRefreshInterval = 30000  # 30 segundos
            self._setupAutoRefresh()
            
            logger.info("EnfermeriaModel ACTUALIZADO inicializado correctamente")
            print("🩹 EnfermeriaModel inicializado con gestión de pacientes por cédula")
            
        except Exception as e:
            logger.error(f"Error inicializando EnfermeriaModel: {e}")
            self.errorOccurred.emit(f"Error inicializando módulo de enfermería: {str(e)}")
    
    # ===============================
    # ✅ MÉTODO FALTANTE PARA APPCONTROLLER
    # ===============================
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """
        Establece el usuario actual para las operaciones
        MÉTODO REQUERIDO por AppController
        """
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario establecido en EnfermeriaModel: ID {usuario_id}")
                self.successMessage.emit(f"Usuario {usuario_id} establecido en módulo de enfermería")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido correctamente")
            else:
                print(f"⚠️ ID de usuario inválido: {usuario_id}")
                self.errorOccurred.emit("ID de usuario inválido")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en EnfermeriaModel: {e}")
            self.errorOccurred.emit(f"Error estableciendo usuario: {str(e)}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        """Property para obtener el usuario actual"""
        return self._usuario_actual_id
    
    # ===============================
    # PROPERTIES ACTUALIZADAS - Como ConsultaModel
    # ===============================
    
    def _get_procedimientos_json(self) -> str:
        """Getter para procedimientos en formato JSON"""
        import json
        return json.dumps(self._procedimientosData, default=str, ensure_ascii=False)
    
    def _get_tipos_procedimientos_json(self) -> str:
        """Getter para tipos de procedimientos en formato JSON"""
        import json
        return json.dumps(self._tiposProcedimientosData, default=str, ensure_ascii=False)
    
    def _get_trabajadores_json(self) -> str:
        """Getter para trabajadores en formato JSON"""
        import json
        return json.dumps(self._trabajadoresData, default=str, ensure_ascii=False)
    
    def _get_estado_actual(self) -> str:
        """Getter para estado actual"""
        return self._estadoActual
    
    def _set_estado_actual(self, nuevo_estado: str):
        """Setter para estado actual"""
        if self._estadoActual != nuevo_estado:
            self._estadoActual = nuevo_estado
            self.estadoCambiado.emit(nuevo_estado)
    
    # Properties expuestas a QML
    procedimientosJson = Property(str, _get_procedimientos_json, notify=procedimientosRecientesChanged)
    tiposProcedimientosJson = Property(str, _get_tipos_procedimientos_json, notify=tiposProcedimientosChanged)
    trabajadoresJson = Property(str, _get_trabajadores_json, notify=trabajadoresChanged)
    estadoActual = Property(str, _get_estado_actual, notify=estadoCambiado)
    
    # Properties para compatibilidad con QML existente
    @Property(list, notify=procedimientosRecientesChanged)
    def procedimientos(self):
        """Lista de procedimientos para compatibilidad"""
        return self._procedimientosData
    
    @Property(list, notify=tiposProcedimientosChanged)
    def tiposProcedimientos(self):
        """Lista de tipos de procedimientos para compatibilidad"""
        return self._tiposProcedimientosData
    
    @Property(list, notify=trabajadoresChanged)
    def trabajadoresEnfermeria(self):
        """Lista de trabajadores para compatibilidad"""
        return self._trabajadoresData
    
    # ===============================
    # BÚSQUEDA INTELIGENTE DE PACIENTES - NUEVA FUNCIONALIDAD
    # ===============================
    
    @Slot(str, result='QVariantMap')
    def buscar_paciente_por_cedula(self, cedula: str):
        """
        Busca un paciente específico por su cédula
        """
        try:
            if len(cedula.strip()) < 5:
                return {}
            
            print(f"🔍 Buscando paciente por cédula: {cedula}")
            
            # Buscar en el repository
            paciente = self.repository.buscar_paciente_por_cedula_exacta(cedula.strip())
            
            if paciente:
                print(f"👤 Paciente encontrado: {paciente.get('nombreCompleto', 'N/A')}")
                
                # Emitir señal de éxito
                self.pacienteEncontradoPorCedula.emit(paciente)
                
                return paciente
            else:
                print(f"⚠️ No se encontró paciente con cédula: {cedula}")
                
                # Emitir señal de no encontrado
                self.pacienteNoEncontrado.emit(cedula)
                
                return {}
                
        except Exception as e:
            error_msg = f"Error buscando paciente por cédula: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.errorOccurred.emit(error_msg)
            self.operacionError.emit(error_msg)
            return {}
    
    @Slot(str, str, str, str, result=int)
    def buscar_o_crear_paciente_inteligente(self, nombre: str, apellido_paterno: str, 
                                          apellido_materno: str = "", cedula: str = "") -> int:
        """
        Busca paciente por cédula o crea uno nuevo si no existe
        NUEVA FUNCIONALIDAD basada en ConsultaModel
        """
        try:
            if not cedula or len(cedula.strip()) < 5:
                self.errorOccurred.emit("Cédula es obligatoria (mínimo 5 dígitos)")
                self.operacionError.emit("Cédula es obligatoria (mínimo 5 dígitos)")
                return -1
            
            if not nombre or len(nombre.strip()) < 2:
                self.errorOccurred.emit("Nombre es obligatorio")
                self.operacionError.emit("Nombre es obligatorio")
                return -1
            
            if not apellido_paterno or len(apellido_paterno.strip()) < 2:
                self.errorOccurred.emit("Apellido paterno es obligatorio")
                self.operacionError.emit("Apellido paterno es obligatorio")
                return -1
            
            print(f"📄 Gestionando paciente: {nombre} {apellido_paterno} - Cédula: {cedula}")
            
            # Buscar paciente existente primero
            paciente_existente = self.repository.buscar_paciente_por_cedula_exacta(cedula.strip())
            
            if paciente_existente:
                print(f"👤 Paciente existente encontrado: {paciente_existente['nombreCompleto']}")
                return paciente_existente['id']
            
            # Crear nuevo paciente usando el repositorio
            nuevo_paciente_data = {
                'nombreCompleto': f"{nombre.strip()} {apellido_paterno.strip()} {apellido_materno.strip()}".strip(),
                'cedula': cedula.strip()
            }
            
            # Usar una conexión temporal para crear el paciente
            with self.db_connection.get_connection() as conn:
                cursor = conn.cursor()
                paciente_id = self.repository._obtener_o_crear_paciente(cursor, nuevo_paciente_data)
                conn.commit()
            
            if paciente_id and paciente_id > 0:
                self.operacionExitosa.emit(f"Paciente gestionado correctamente: ID {paciente_id}")
                self.successMessage.emit(f"Paciente gestionado correctamente: ID {paciente_id}")
                return paciente_id
            else:
                self.errorOccurred.emit("Error gestionando paciente")
                self.operacionError.emit("Error gestionando paciente")
                return -1
                
        except Exception as e:
            error_msg = f"Error gestionando paciente: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.errorOccurred.emit(error_msg)
            self.operacionError.emit(error_msg)
            return -1
    
    @Slot(str, int, result='QVariantList')
    def buscar_pacientes(self, termino_busqueda: str, limite: int = 5):
        """
        Busca pacientes por término de búsqueda (mejorado)
        """
        try:
            if len(termino_busqueda.strip()) < 2:
                return []
            
            print(f"🔍 Buscando pacientes con término: {termino_busqueda}")
            
            resultados = self.repository.buscar_pacientes(termino_busqueda.strip())
            
            # Limitar resultados
            if limite > 0:
                resultados = resultados[:limite]
            
            print(f"📋 Encontrados {len(resultados)} pacientes")
            return resultados
            
        except Exception as e:
            error_msg = f"Error en búsqueda de pacientes: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.errorOccurred.emit(error_msg)
            self.operacionError.emit(error_msg)
            return []
    
    # ===============================
    # OPERACIONES CRUD MEJORADAS - SEPARADAS CREAR/ACTUALIZAR CON USUARIO
    # ===============================
    
    @Slot('QVariant', result=str)
    def crear_procedimiento(self, datos_procedimiento):
        """
        Crea nuevo procedimiento de enfermería - MEJORADO con usuario actual
        """
        try:
            self._set_estado_actual("cargando")
            
            # Convertir QJSValue a diccionario de Python
            if hasattr(datos_procedimiento, 'toVariant'):
                datos = datos_procedimiento.toVariant()
            else:
                datos = datos_procedimiento
            
            # Validaciones básicas mejoradas
            if not self._validar_datos_procedimiento_mejorado(datos):
                self._set_estado_actual("error")
                return self._crear_respuesta_json(False, "Datos incompletos o inválidos")
            
            # Gestionar paciente (buscar o crear)
            paciente_id = self._gestionar_paciente_procedimiento(datos)
            if paciente_id <= 0:
                self._set_estado_actual("error")
                return self._crear_respuesta_json(False, "Error gestionando datos del paciente")
            
            # ✅ PREPARAR DATOS CON USUARIO ACTUAL
            datos_repo = {
                'nombreCompleto': datos.get('paciente', '').strip(),
                'cedula': datos.get('cedula', '').strip(),
                'idProcedimiento': int(datos.get('idProcedimiento', 0)),
                'cantidad': int(datos.get('cantidad', 1)),
                'tipo': datos.get('tipo', 'Normal'),
                'idTrabajador': int(datos.get('idTrabajador', 0)),
                'idRegistradoPor': self._usuario_actual_id,  # ✅ Usar usuario actual
                'fecha': datetime.now()
            }
            
            # Crear procedimiento
            procedimiento_id = self.repository.crear_procedimiento_enfermeria(datos_repo)
            
            if procedimiento_id:
                # Actualizar datos internos
                self._cargar_procedimientos_recientes()
                
                # Obtener procedimiento completo creado
                procedimiento_completo = self._obtener_procedimiento_completo(procedimiento_id)
                
                # Emitir signals
                self.procedimientoCreado.emit(self._crear_respuesta_json(True, procedimiento_completo))
                self.procedimientoCreado_old.emit(True, f"Procedimiento creado: ID {procedimiento_id}")
                self.operacionExitosa.emit(f"Procedimiento creado exitosamente: ID {procedimiento_id}")
                self.successMessage.emit(f"Procedimiento creado exitosamente: ID {procedimiento_id}")
                
                self._set_estado_actual("listo")
                return self._crear_respuesta_json(True, {'procedimiento_id': procedimiento_id})
            else:
                raise ValueError("Error creando procedimiento en repositorio")
                
        except Exception as e:
            error_msg = f"Error creando procedimiento: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.errorOccurred.emit(error_msg)
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return self._crear_respuesta_json(False, error_msg)
    
    @Slot('QVariant', int, result=str)
    def actualizar_procedimiento(self, datos_procedimiento, procedimiento_id: int):
        """
        Actualiza procedimiento de enfermería existente - NUEVO MÉTODO SEPARADO
        """
        try:
            self._set_estado_actual("cargando")
            
            # Validar ID
            if procedimiento_id <= 0:
                self._set_estado_actual("error")
                return self._crear_respuesta_json(False, "ID de procedimiento inválido")
            
            # Convertir QJSValue a diccionario de Python
            if hasattr(datos_procedimiento, 'toVariant'):
                datos = datos_procedimiento.toVariant()
            else:
                datos = datos_procedimiento
            
            # Validaciones básicas mejoradas
            if not self._validar_datos_procedimiento_mejorado(datos):
                self._set_estado_actual("error")
                return self._crear_respuesta_json(False, "Datos incompletos o inválidos")
            
            # Gestionar paciente (buscar o crear)
            paciente_id = self._gestionar_paciente_procedimiento(datos)
            if paciente_id <= 0:
                self._set_estado_actual("error")
                return self._crear_respuesta_json(False, "Error gestionando datos del paciente")
            
            # Preparar datos para actualización
            datos_repo = {
                'nombreCompleto': datos.get('paciente', '').strip(),
                'cedula': datos.get('cedula', '').strip(),
                'idProcedimiento': int(datos.get('idProcedimiento', 0)),
                'cantidad': int(datos.get('cantidad', 1)),
                'tipo': datos.get('tipo', 'Normal'),
                'idTrabajador': int(datos.get('idTrabajador', 0))
            }
            
            print(f"📄 Actualizando procedimiento ID: {procedimiento_id}")
            print(f"   - Paciente ID: {paciente_id}")
            print(f"   - Tipo procedimiento ID: {datos_repo['idProcedimiento']}")
            print(f"   - Trabajador ID: {datos_repo['idTrabajador']}")
            
            # Actualizar procedimiento usando el método existente del repositorio
            exito = self.repository.actualizar_procedimiento_enfermeria(procedimiento_id, datos_repo)
            
            if exito:
                # Actualizar datos internos
                self._cargar_procedimientos_recientes()
                
                # Obtener procedimiento actualizado
                procedimiento_completo = self._obtener_procedimiento_completo(procedimiento_id)
                
                # Emitir signals
                self.procedimientoActualizado.emit(self._crear_respuesta_json(True, procedimiento_completo))
                self.operacionExitosa.emit(f"Procedimiento {procedimiento_id} actualizado correctamente")
                self.successMessage.emit(f"Procedimiento {procedimiento_id} actualizado correctamente")
                
                self._set_estado_actual("listo")
                print(f"✅ Procedimiento {procedimiento_id} actualizado exitosamente")
                return self._crear_respuesta_json(True, {'procedimiento_id': procedimiento_id})
            else:
                error_msg = f"Error actualizando procedimiento {procedimiento_id} en repositorio"
                self.errorOccurred.emit(error_msg)
                self.operacionError.emit(error_msg)
                self._set_estado_actual("error")
                return self._crear_respuesta_json(False, error_msg)
                
        except Exception as e:
            error_msg = f"Error actualizando procedimiento: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.errorOccurred.emit(error_msg)
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return self._crear_respuesta_json(False, error_msg)

    @Slot(int, result=bool)
    def eliminar_procedimiento(self, procedimiento_id: int) -> bool:
        """Elimina procedimiento - MEJORADO"""
        try:
            self._set_estado_actual("cargando")
            
            exito = self.repository.eliminar_procedimiento_enfermeria(procedimiento_id)
            
            if exito:
                # Actualizar datos
                self._cargar_procedimientos_recientes()
                
                # Emitir signals
                self.procedimientoEliminado.emit(procedimiento_id)
                self.operacionExitosa.emit(f"Procedimiento {procedimiento_id} eliminado correctamente")
                self.successMessage.emit(f"Procedimiento {procedimiento_id} eliminado correctamente")
                
                self._set_estado_actual("listo")
                return True
            else:
                self.errorOccurred.emit(f"No se pudo eliminar procedimiento {procedimiento_id}")
                self.operacionError.emit(f"No se pudo eliminar procedimiento {procedimiento_id}")
                self._set_estado_actual("error")
                return False
                
        except Exception as e:
            error_msg = f"Error eliminando procedimiento: {str(e)}"
            self.errorOccurred.emit(error_msg)
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return False
    
    # ===============================
    # PAGINACIÓN Y FILTROS MEJORADOS - DEL REPOSITORIO
    # ===============================
    
    @Slot(int, int, 'QVariant', result='QVariant')
    def obtener_procedimientos_paginados(self, page: int, limit: int = 6, filters=None):
        """
        Obtiene página específica de procedimientos con filtros aplicados en BD
        NUEVO PATRÓN basado en ConsultaModel
        """
        try:
            offset = page * limit
            filtros_dict = filters.toVariant() if hasattr(filters, 'toVariant') else filters or {}
            
            print(f"📄 Obteniendo página {page + 1}, límite {limit}, filtros: {filtros_dict}")
            
            # Obtener procedimientos paginados del repositorio
            procedimientos = self.repository.obtener_procedimientos_paginados(offset, limit, filtros_dict)
            
            # Obtener total para cálculo de páginas
            total = self.repository.contar_procedimientos_filtrados(filtros_dict)
            total_pages = (total + limit - 1) // limit if total > 0 else 1
            
            resultado = {
                'procedimientos': procedimientos,  # USAR 'procedimientos' como key
                'total': total,
                'page': page,
                'limit': limit,
                'total_pages': total_pages
            }
            
            print(f"✅ Página {page + 1} de {total_pages} - {len(procedimientos)} procedimientos")
            return resultado
            
        except Exception as e:
            error_msg = f"Error en paginación: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.errorOccurred.emit(error_msg)
            self.operacionError.emit(error_msg)
            return {'procedimientos': [], 'total': 0, 'page': 0, 'total_pages': 0}
    
    @Slot(str, result=str)
    def buscar_procedimientos_avanzado(self, termino_busqueda: str) -> str:
        """Búsqueda avanzada de procedimientos - NUEVO"""
        try:
            resultado = self.repository.buscar_procedimientos(termino_busqueda, limit=100)
            
            # Emitir signal con resultados
            self.resultadosBusqueda.emit(self._crear_respuesta_json(True, resultado))
            
            return self._crear_respuesta_json(True, {
                'procedimientos': resultado,
                'total': len(resultado)
            })
            
        except Exception as e:
            error_msg = f"Error en búsqueda: {str(e)}"
            self.errorOccurred.emit(error_msg)
            self.operacionError.emit(error_msg)
            return self._crear_respuesta_json(False, error_msg)
    
    # ===============================
    # GESTIÓN DE DATOS MEJORADA
    # ===============================
    
    @Slot()
    def actualizar_procedimientos(self):
        """Actualiza lista de procedimientos - MEJORADO"""
        try:
            self._set_estado_actual("cargando")
            self._cargar_procedimientos_recientes()
            self._set_estado_actual("listo")
        except Exception as e:
            self.errorOccurred.emit(f"Error cargando procedimientos: {str(e)}")
            self.operacionError.emit(f"Error cargando procedimientos: {str(e)}")
            self._set_estado_actual("error")
    
    @Slot()
    def actualizar_tipos_procedimientos(self):
        """Actualiza tipos de procedimientos - MEJORADO"""
        try:
            tipos_raw = self.repository.obtener_tipos_procedimientos()
            self._tiposProcedimientosData = []
            
            for tipo in tipos_raw or []:
                self._tiposProcedimientosData.append({
                    'id': tipo['id'],
                    'nombre': tipo['nombre'],
                    'descripcion': tipo.get('descripcion', ''),
                    'precioNormal': float(tipo.get('precioNormal', 0)),
                    'precioEmergencia': float(tipo.get('precioEmergencia', 0)),
                    'data': tipo
                })
            
            self.tiposProcedimientosChanged.emit()
            self.tiposProcedimientosActualizados.emit()  # Compatibilidad
            print(f"🔧 Tipos de procedimientos cargados: {len(self._tiposProcedimientosData)}")
            
        except Exception as e:
            error_msg = f"Error cargando tipos de procedimientos: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.errorOccurred.emit(error_msg)
            self.operacionError.emit(error_msg)
    
    @Slot()
    def actualizar_trabajadores_enfermeria(self):
        """Actualiza trabajadores - MEJORADO"""
        try:
            trabajadores_raw = self.repository.obtener_trabajadores_enfermeria()
            self._trabajadoresData = []
            
            for trabajador in trabajadores_raw or []:
                self._trabajadoresData.append(trabajador['nombreCompleto'])
            
            self.trabajadoresChanged.emit()
            self.trabajadoresActualizados.emit()  # Compatibilidad
            print(f"👥 Trabajadores cargados: {len(self._trabajadoresData)}")
            
        except Exception as e:
            error_msg = f"Error cargando trabajadores: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.errorOccurred.emit(error_msg)
            self.operacionError.emit(error_msg)
    
    @Slot()
    def refrescar_datos(self):
        """Refresca todos los datos - NUEVO"""
        try:
            self._set_estado_actual("cargando")
            
            # Cargar datos principales
            self.actualizar_procedimientos()
            self.actualizar_tipos_procedimientos()
            self.actualizar_trabajadores_enfermeria()
            
            self._set_estado_actual("listo")
            self.operacionExitosa.emit("Datos actualizados correctamente")
            self.successMessage.emit("Datos actualizados correctamente")
            
        except Exception as e:
            error_msg = f"Error refrescando datos: {str(e)}"
            self.errorOccurred.emit(error_msg)
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
    
    @Slot()
    def limpiar_cache_procedimientos(self):
        """Limpia cache para forzar recarga - NUEVO"""
        try:
            # Limpiar datos internos
            self._procedimientosData = []
            
            # Forzar recarga
            self.actualizar_procedimientos()
            
            print("🧹 Cache de procedimientos limpiado")
        except Exception as e:
            print(f"⚠️ Error limpiando cache: {e}")
    
    # ===============================
    # MÉTODOS INTERNOS AUXILIARES
    # ===============================
    
    def _cargar_procedimientos_recientes(self):
        """Carga procedimientos recientes - MÉTODO INTERNO MEJORADO"""
        try:
            # Obtener procedimientos recientes (últimos 30 días)
            procedimientos_raw = self.repository.obtener_procedimientos_enfermeria()
            
            self._procedimientosData = []
            for proc in procedimientos_raw or []:
                proc_procesado = {
                    'procedimientoId': str(proc.get('procedimientoId', 'N/A')),
                    'paciente': proc.get('paciente', 'Sin nombre'),
                    'cedula': proc.get('cedula', ''),
                    'tipoProcedimiento': proc.get('tipoProcedimiento', 'Sin procedimiento'),
                    'cantidad': proc.get('cantidad', 1),
                    'tipo': proc.get('tipo', 'Normal'),
                    'precioUnitario': proc.get('precioUnitario', '0.00'),
                    'precioTotal': proc.get('precioTotal', '0.00'),
                    'fecha': proc.get('fecha', ''),
                    'trabajadorRealizador': proc.get('trabajadorRealizador', 'Sin trabajador'),
                    'registradoPor': proc.get('registradoPor', 'Sin registro')
                }
                
                self._procedimientosData.append(proc_procesado)
            
            self.procedimientosRecientesChanged.emit()
            self.procedimientosActualizados.emit()  # Compatibilidad
            print(f"📋 Procedimientos cargados: {len(self._procedimientosData)}")
            
        except Exception as e:
            error_msg = f"Error cargando procedimientos recientes: {str(e)}"
            print(f"⚠️ {error_msg}")
            self._procedimientosData = []
    
    def _validar_datos_procedimiento_mejorado(self, datos: Dict[str, Any]) -> bool:
        """Validación mejorada de datos"""
        try:
            # Validar paciente
            if not datos.get('paciente', '').strip():
                self.errorOccurred.emit("Nombre del paciente es obligatorio")
                self.operacionError.emit("Nombre del paciente es obligatorio")
                return False
            
            # Validar procedimiento
            if not datos.get('idProcedimiento') or int(datos.get('idProcedimiento', 0)) <= 0:
                self.errorOccurred.emit("Debe seleccionar un procedimiento válido")
                self.operacionError.emit("Debe seleccionar un procedimiento válido")
                return False
            
            # Validar trabajador
            if not datos.get('idTrabajador') or int(datos.get('idTrabajador', 0)) <= 0:
                self.errorOccurred.emit("Debe seleccionar un trabajador válido")
                self.operacionError.emit("Debe seleccionar un trabajador válido")
                return False
            
            # Validar cantidad
            if int(datos.get('cantidad', 0)) <= 0:
                self.errorOccurred.emit("La cantidad debe ser mayor a 0")
                self.operacionError.emit("La cantidad debe ser mayor a 0")
                return False
            
            # Validar tipo
            if datos.get('tipo') not in ['Normal', 'Emergencia']:
                self.errorOccurred.emit("Tipo de procedimiento inválido")
                self.operacionError.emit("Tipo de procedimiento inválido")
                return False
            
            return True
            
        except (ValueError, TypeError) as e:
            self.errorOccurred.emit(f"Error en validación de datos: {str(e)}")
            self.operacionError.emit(f"Error en validación de datos: {str(e)}")
            return False
    
    def _gestionar_paciente_procedimiento(self, datos: Dict[str, Any]) -> int:
        """Gestiona paciente para procedimiento - NUEVO MÉTODO"""
        try:
            nombre_completo = datos.get('paciente', '').strip()
            cedula = datos.get('cedula', '').strip()
            
            if not nombre_completo or not cedula:
                return -1
            
            # Dividir nombre completo
            nombres = nombre_completo.split()
            nombre = nombres[0] if len(nombres) > 0 else ''
            apellido_p = nombres[1] if len(nombres) > 1 else ''
            apellido_m = ' '.join(nombres[2:]) if len(nombres) > 2 else ''
            
            # Usar función de búsqueda/creación inteligente
            return self.buscar_o_crear_paciente_inteligente(nombre, apellido_p, apellido_m, cedula)
            
        except Exception as e:
            print(f"Error gestionando paciente: {e}")
            return -1
    
    def _obtener_procedimiento_completo(self, procedimiento_id: int) -> Dict[str, Any]:
        """Obtiene procedimiento completo por ID - NUEVO MÉTODO"""
        try:
            for proc in self._procedimientosData:
                if int(proc.get('procedimientoId', 0)) == procedimiento_id:
                    return proc
            return {}
        except Exception:
            return {}
    
    def _crear_respuesta_json(self, exito: bool, datos: Any) -> str:
        """Crea respuesta JSON consistente - NUEVO MÉTODO"""
        import json
        try:
            return json.dumps({
                'exito': exito,
                'datos': datos if exito else None,
                'error': datos if not exito else None
            }, default=str, ensure_ascii=False)
        except Exception as e:
            return json.dumps({'exito': False, 'error': str(e)})
    
    def _setupAutoRefresh(self):
        """Configura actualización automática - NUEVO"""
        self._autoRefreshTimer = QTimer(self)
        self._autoRefreshTimer.timeout.connect(self.refrescar_datos)
        # Comentado por defecto
        # self._autoRefreshTimer.start(self._autoRefreshInterval)
    
    @Slot(int)
    def setAutoRefreshInterval(self, intervalMs: int):
        """Configura intervalo de actualización automática - NUEVO"""
        if intervalMs > 0:
            self._autoRefreshInterval = intervalMs
            if hasattr(self, '_autoRefreshTimer'):
                self._autoRefreshTimer.start(intervalMs)
        else:
            if hasattr(self, '_autoRefreshTimer'):
                self._autoRefreshTimer.stop()

# ===============================
# REGISTRO PARA QML
# ===============================

def register_enfermeria_model():
    """Registra el EnfermeriaModel actualizado para uso en QML"""
    try:
        qmlRegisterType(EnfermeriaModel, "Clinica.Models", 1, 0, "EnfermeriaModel")
        print("✅ EnfermeriaModel ACTUALIZADO registrado para QML")
    except Exception as e:
        print(f"❌ Error registrando EnfermeriaModel: {e}")
        raise