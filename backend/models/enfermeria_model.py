"""
Modelo QObject para Enfermería - CON RESTRICCIONES DE SEGURIDAD
Migrado del patrón hardcoded al patrón de autenticación dinámica con verificación de permisos
"""

import logging
from typing import List, Dict, Any, Optional
from decimal import Decimal
from datetime import datetime

from PySide6.QtCore import QObject, Signal, Slot, Property, QJsonValue, QTimer
from PySide6.QtQml import qmlRegisterType
from ..core.database_conexion import DatabaseConnection
from ..repositories.enfermeria_repository import EnfermeriaRepository
from ..core.Signals_manager import get_global_signals

# Configurar logging
logger = logging.getLogger(__name__)

class EnfermeriaModel(QObject):
    """
    Modelo QObject COMPLETO para Enfermería CON RESTRICCIONES DE SEGURIDAD
    """
    
    # ===============================
    # SIGNALS ACTUALIZADAS
    # ===============================
    
    # Operaciones CRUD con datos detallados
    procedimientoCreado = Signal(str, arguments=['datos'])
    procedimientoActualizado = Signal(str, arguments=['datos'])
    procedimientoEliminado = Signal(int, arguments=['procedimientoId'])
    
    # Búsquedas por cédula
    pacienteEncontradoPorCedula = Signal('QVariantMap', arguments=['pacienteData'])
    pacienteNoEncontrado = Signal(str, arguments=['cedula'])
    
    # Búsquedas y filtros
    resultadosBusqueda = Signal(str, arguments=['resultados'])
    filtrosAplicados = Signal(str, arguments=['criterios'])
    
    # Estados y notificaciones
    estadoCambiado = Signal(str, arguments=['nuevoEstado'])
    errorOcurrido = Signal(str, str, arguments=['mensaje', 'codigo'])
    operacionExitosa = Signal(str, arguments=['mensaje'])
    operacionError = Signal(str, arguments=['mensaje'])
    
    # Datos actualizados
    procedimientosRecientesChanged = Signal()
    tiposProcedimientosChanged = Signal()
    trabajadoresChanged = Signal()
    
    # Signals para paginación
    currentPageChanged = Signal()
    totalPagesChanged = Signal() 
    itemsPerPageChanged = Signal()
    totalRecordsChanged = Signal()
    
    # Señales de compatibilidad
    procedimientoCreado_old = Signal(bool, str)
    procedimientosActualizados = Signal()
    tiposProcedimientosActualizados = Signal()
    trabajadoresActualizados = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        try:
            # Inicializar conexión y repositorio
            self.db_connection = DatabaseConnection()
            self.repository = EnfermeriaRepository(self.db_connection)
            self.global_signals = get_global_signals()
            self._conectar_senales_globales()
            
            # Estados internos
            self._procedimientosData = []
            self._tiposProcedimientosData = []
            self._trabajadoresData = []
            self._estadisticasData = {}
            self._estadoActual = "inicializando"
            
            # ✅ AUTENTICACIÓN CON ROL
            self._usuario_actual_id = 0
            self._usuario_actual_rol = ""  # ✅ NUEVO: Almacenar rol del usuario
            print("🩹 EnfermeriaModel inicializado - Esperando autenticación")
            
            # Propiedades de paginación
            self._currentPage = 0
            self._totalPages = 0
            self._itemsPerPage = 6
            self._totalRecords = 0
            
            # Filtros estandarizados
            self._filtrosActuales = {
                'busqueda': '',
                'tipo_procedimiento': '',
                'tipo': '',
                'fecha_desde': '',
                'fecha_hasta': ''
            }
            
            # Configuración de auto-refresh optimizado
            self._autoRefreshInterval = 30000
            self._setupAutoRefresh()
            
            # Inicialización inmediata
            self._inicializar_datos()
            
            logger.info("✅ EnfermeriaModel con restricciones de seguridad inicializado correctamente")
            
        except Exception as e:
            logger.error(f"❌ Error inicializando EnfermeriaModel: {e}")
            self.errorOcurrido.emit(f"Error inicializando módulo de enfermería: {str(e)}", 'INIT_ERROR')
            self._estadoActual = "error"
    
    # ===============================
    # ✅ MÉTODOS DE AUTENTICACIÓN ACTUALIZADOS
    # ===============================

    def _verificar_autenticacion(self) -> bool:
        """Verifica autenticación básica"""
        if self._usuario_actual_id <= 0:
            self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
            return False
        return True

    def _verificar_permisos_admin(self) -> bool:
        """Verifica permisos de administrador"""
        if not self._verificar_autenticacion():
            return False
        
        if self._usuario_actual_rol != "Administrador":
            self.operacionError.emit("Solo administradores pueden realizar esta operación")
            print(f"🚫 Acceso denegado: Usuario {self._usuario_actual_id} (Rol: {self._usuario_actual_rol})")
            return False
        
        return True

    def _verificar_permisos_eliminacion(self, procedimiento_id: int) -> tuple[bool, str]:
        """Permisos de eliminación - ADMINS sin límite, MÉDICOS máximo 30 días"""
        if not self._verificar_autenticacion():
            return False, "Usuario no autenticado"
        
        if self._usuario_actual_rol == "Administrador":
            return True, "Administrador: Sin restricciones"
        
        if self._usuario_actual_rol == "Médico":
            proc_data = self.repository.get_procedimiento_by_id(procedimiento_id)
            if not proc_data:
                return False, "Procedimiento no encontrado"
            
            # Verificar fecha (30 días límite para eliminación)
            fecha_proc = proc_data.get('Fecha')
            if not self._validar_fecha_eliminacion(fecha_proc, dias_limite=30):
                return False, "Solo puede eliminar procedimientos de máximo 30 días"
            
            return True, "Médico: Puede eliminar (procedimiento reciente)"
        
        return False, "Sin permisos para eliminar procedimientos"

    def _validar_fecha_eliminacion(self, fecha_registro, dias_limite: int = 30) -> bool:
        """Valida que el registro no sea muy antiguo para eliminar"""
        try:
            if not fecha_registro:
                return True
            
            if isinstance(fecha_registro, str):
                fecha_obj = datetime.fromisoformat(fecha_registro.replace('Z', ''))
            elif isinstance(fecha_registro, datetime):
                fecha_obj = fecha_registro
            else:
                return True
            
            dias_transcurridos = (datetime.now() - fecha_obj).days
            return dias_transcurridos <= dias_limite
            
        except Exception as e:
            print(f"⚠️ Error validando fecha eliminación: {e}")
            return True
    
    @Slot(int, str)
    def set_usuario_actual_con_rol(self, usuario_id: int, usuario_rol: str):
        """
        Establece el usuario actual CON ROL para verificaciones de permisos
        """
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                self._usuario_actual_rol = usuario_rol.strip()
                print(f"👤 Usuario establecido en EnfermeriaModel: ID {usuario_id}, Rol: {usuario_rol}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} ({usuario_rol}) establecido en módulo de enfermería")
            else:
                print(f"⚠️ ID de usuario inválido en EnfermeriaModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en EnfermeriaModel: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        """Property para obtener el usuario actual"""
        return self._usuario_actual_id
    
    @Property(str, notify=operacionExitosa)
    def usuario_actual_rol(self):
        """Property para obtener el rol del usuario actual"""
        return self._usuario_actual_rol
    
    # ===============================
    # ✅ MÉTODOS DE VERIFICACIÓN DE PERMISOS
    # ===============================
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica autenticación básica"""
        if self._usuario_actual_id <= 0:
            self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
            return False
        return True
    
    def _verificar_permisos_admin(self) -> bool:
        """Verifica permisos de administrador"""
        if not self._verificar_autenticacion():
            return False
        
        if self._usuario_actual_rol != "Administrador":
            self.operacionError.emit("Solo administradores pueden realizar esta operación")
            print(f"🚫 Acceso denegado: Usuario {self._usuario_actual_id} (Rol: {self._usuario_actual_rol})")
            return False
        
        return True
    
    # ===============================
    # CONEXIONES Y PROPIEDADES (SIN CAMBIOS ESTRUCTURALES)
    # ===============================
    
    def _conectar_senales_globales(self):
        """Conecta con las señales globales para recibir actualizaciones"""
        try:
            self.global_signals.tiposProcedimientosModificados.connect(self._actualizar_tipos_procedimientos_desde_signal)
            self.global_signals.enfermeriaNecesitaActualizacion.connect(self._manejar_actualizacion_global)
            #print("🔗 Señales globales conectadas en EnfermeriaModel")
        except Exception as e:
            print(f"❌ Error conectando señales globales en EnfermeriaModel: {e}")
    
    def _get_procedimientos_json(self) -> str:
        """Getter para procedimientos en formato JSON"""
        import json
        try:
            return json.dumps(self._procedimientosData, default=str, ensure_ascii=False)
        except Exception as e:
            logger.error(f"Error generando JSON procedimientos: {e}")
            return "[]"
    
    def _get_tipos_procedimientos_json(self) -> str:
        """Getter para tipos de procedimientos en formato JSON"""
        import json
        try:
            return json.dumps(self._tiposProcedimientosData, default=str, ensure_ascii=False)
        except Exception as e:
            logger.error(f"Error generando JSON tipos procedimientos: {e}")
            return "[]"
    
    def _get_trabajadores_json(self) -> str:
        """Getter para trabajadores en formato JSON"""
        import json
        try:
            return json.dumps(self._trabajadoresData, default=str, ensure_ascii=False)
        except Exception as e:
            logger.error(f"Error generando JSON trabajadores: {e}")
            return "[]"
    
    def _get_estado_actual(self) -> str:
        """Getter para estado actual"""
        return self._estadoActual
    
    def _set_estado_actual(self, nuevo_estado: str):
        """Setter para estado actual"""
        if self._estadoActual != nuevo_estado:
            self._estadoActual = nuevo_estado
            self.estadoCambiado.emit(nuevo_estado)
            #logger.info(f"Estado cambiado a: {nuevo_estado}")
    
    # Getters/setters paginación
    def _get_current_page(self) -> int:
        return self._currentPage

    def _get_total_pages(self) -> int:
        return self._totalPages

    def _get_items_per_page(self) -> int:
        return self._itemsPerPage

    def _set_items_per_page(self, value: int):
        """Setter que permite configuración desde QML"""
        if value != self._itemsPerPage and value > 0:
            print(f"📊 ItemsPerPage actualizado desde QML: {self._itemsPerPage} -> {value}")
            self._itemsPerPage = value
            self.itemsPerPageChanged.emit()
            # Recargar datos con nuevo tamaño de página
            self._cargar_procedimientos_actuales()

    def _get_total_records(self) -> int:
        return self._totalRecords
    
    # Properties expuestas a QML
    procedimientosJson = Property(str, _get_procedimientos_json, notify=procedimientosRecientesChanged)
    tiposProcedimientosJson = Property(str, _get_tipos_procedimientos_json, notify=tiposProcedimientosChanged)
    trabajadoresJson = Property(str, _get_trabajadores_json, notify=trabajadoresChanged)
    estadoActual = Property(str, _get_estado_actual, notify=estadoCambiado)
    
    # Properties paginación para QML
    currentPageProperty = Property(int, _get_current_page, notify=currentPageChanged)
    totalPagesProperty = Property(int, _get_total_pages, notify=totalPagesChanged)
    itemsPerPageProperty = Property(int, _get_items_per_page, _set_items_per_page, notify=itemsPerPageChanged)
    totalRecordsProperty = Property(int, _get_total_records, notify=totalRecordsChanged)
    
    # Properties para compatibilidad con QML existente
    @Property(list, notify=procedimientosRecientesChanged)
    def procedimientos(self):
        return self._procedimientosData
    
    @Property(list, notify=tiposProcedimientosChanged)
    def tiposProcedimientos(self):
        return self._tiposProcedimientosData
    
    @Property(list, notify=trabajadoresChanged)
    def trabajadoresEnfermeria(self):
        return self._trabajadoresData
    
    # ===============================
    # APLICAR FILTROS (SIN CAMBIOS - SOLO LECTURA)
    # ===============================
    
    @Slot(str, str, str, str, str)
    def aplicar_filtros_y_recargar(self, search_term: str = "", tipo_procedimiento: str = "", 
                                tipo: str = "", fecha_desde: str = "", fecha_hasta: str = ""):
        """Aplica filtros estandarizados - SIN VERIFICACIÓN (solo lectura)"""
        try:
            self._set_estado_actual("cargando")
            
            # Resetear a página 0 siempre que cambien filtros
            self._currentPage = 0
            
            # Limpiar y estandarizar parámetros
            filtros_limpios = {
                'busqueda': search_term.strip() if search_term else "",
                'tipo_procedimiento': tipo_procedimiento.strip() if tipo_procedimiento else "",
                'tipo': tipo.strip() if tipo else "",
                'fecha_desde': fecha_desde.strip() if fecha_desde else "",
                'fecha_hasta': fecha_hasta.strip() if fecha_hasta else ""
            }
            
            # Validación específica para tipo
            tipo_limpio = filtros_limpios['tipo']
            if tipo_limpio and tipo_limpio not in ["", "Todos"]:
                if tipo_limpio not in ["Normal", "Emergencia"]:
                    print(f"⚠️ TIPO INVÁLIDO RECIBIDO: '{tipo_limpio}' - Ignorando")
                    filtros_limpios['tipo'] = ""
                else:
                    print(f"✅ TIPO VÁLIDO: '{tipo_limpio}'")
            
            # Filtrar valores vacíos y "Todos"
            filtros_aplicables = {}
            for key, value in filtros_limpios.items():
                if value and value not in ["", "Todos", "Seleccionar procedimiento..."]:
                    filtros_aplicables[key] = value
            
            # Actualizar filtros internos
            self._filtrosActuales = filtros_aplicables
            
            # Obtener datos paginados con filtros
            self.obtener_procedimientos_paginados(0, self._itemsPerPage, filtros_aplicables)
            
            # Emitir señal de filtros aplicados
            import json
            self.filtrosAplicados.emit(json.dumps(filtros_aplicables, ensure_ascii=False))
            
        except Exception as e:
            error_msg = f"Error aplicando filtros: {str(e)}"
            print(f"❌ {error_msg}")
            logger.error(error_msg)
            self.errorOcurrido.emit(error_msg, 'FILTER_ERROR')
            self._set_estado_actual("error")
    
    # ===============================
    # PAGINACIÓN (SIN CAMBIOS - SOLO LECTURA)
    # ===============================
    
    @Slot(int, int, 'QVariant', result='QVariant')
    def obtener_procedimientos_paginados(self, page: int, limit: int = 6, filters=None):
        """Obtiene página específica - SIN VERIFICACIÓN (solo lectura)"""
        try:
            if page < 0:
                page = 0
                
            limit_real = self._itemsPerPage
            
            if filters:
                if hasattr(filters, 'toVariant'):
                    filtros_dict = filters.toVariant()
                else:
                    filtros_dict = filters
            else:
                filtros_dict = self._filtrosActuales
            
            #print(f"📖 Obteniendo página {page + 1} con {limit_real} elementos")
            #print(f"🔍 Filtros aplicados: {filtros_dict}")
            
            procedimientos = self.repository.obtener_procedimientos_paginados(
                page * limit_real, limit_real, filtros_dict
            )
            
            total_records = self.repository.contar_procedimientos_filtrados(filtros_dict)
            
            # Actualizar propiedades internas
            old_page = self._currentPage
            old_total_pages = self._totalPages
            old_total_records = self._totalRecords

            self._currentPage = page
            self._totalRecords = total_records
            self._totalPages = max(1, (self._totalRecords + limit_real - 1) // limit_real) if total_records > 0 else 1
            
            # Actualizar datos procedimientos
            self._procedimientosData = procedimientos
            
            # Emitir señales solo si cambiaron las propiedades
            if old_page != self._currentPage:
                self.currentPageChanged.emit()
            if old_total_pages != self._totalPages:
                self.totalPagesChanged.emit()
            if old_total_records != self._totalRecords:
                self.totalRecordsChanged.emit()
                
            # Emitir señal de datos actualizados
            self.procedimientosRecientesChanged.emit()
            
            self._set_estado_actual("listo")
            
            return {
                'procedimientos': self._procedimientosData,
                'page': page,
                'limit': limit_real,
                'total_records': self._totalRecords,
                'total_pages': self._totalPages,
                'success': True
            }
            
        except Exception as e:
            error_msg = f"Error obteniendo procedimientos paginados: {str(e)}"
            print(f"❌ {error_msg}")
            logger.error(error_msg)
            self.errorOcurrido.emit(error_msg, 'PAGINATION_EXCEPTION')
            self._set_estado_actual("error")
            return {'procedimientos': [], 'total': 0, 'page': 0, 'total_pages': 0, 'success': False}
    
    @Slot(str, result=str)
    def buscar_procedimientos_avanzado(self, termino_busqueda: str) -> str:
        """Búsqueda avanzada de procedimientos - SIN VERIFICACIÓN (solo lectura)"""
        try:
            resultado = self.repository.buscar_procedimientos(termino_busqueda, limit=100)
            
            self.resultadosBusqueda.emit(self._crear_respuesta_json(True, resultado))
            
            return self._crear_respuesta_json(True, {
                'procedimientos': resultado,
                'total': len(resultado)
            })
            
        except Exception as e:
            error_msg = f"Error en búsqueda: {str(e)}"
            self.errorOcurrido.emit(error_msg, 'SEARCH_ERROR')
            return self._crear_respuesta_json(False, error_msg)
    
    # ===============================
    # BÚSQUEDAS DE PACIENTES (LECTURA SIN VERIFICACIÓN, ESCRITURA CON VERIFICACIÓN)
    # ===============================
    
    @Slot(str, str, str, str, result=int)
    def buscar_o_crear_paciente_inteligente(self, nombre: str, apellido_paterno: str, 
                                          apellido_materno: str = "", cedula: str = "") -> int:
        """Busca paciente por cédula o crea uno nuevo - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN PARA OPERACIÓN DE ESCRITURA
            if not self._verificar_autenticacion():
                return -1
            
            if not cedula or len(cedula.strip()) < 5:
                self.operacionError.emit("Cédula es obligatoria (mínimo 5 dígitos)")
                return -1
            
            if not nombre or len(nombre.strip()) < 2:
                self.operacionError.emit("Nombre es obligatorio")
                return -1
            
            if not apellido_paterno or len(apellido_paterno.strip()) < 2:
                self.operacionError.emit("Apellido paterno es obligatorio")
                return -1
            
            print(f"🔄 Usuario {self._usuario_actual_id} ({self._usuario_actual_rol}) gestionando paciente: {nombre} {apellido_paterno}")
            
            # Buscar paciente existente primero
            paciente_existente = self.repository.buscar_paciente_por_cedula_exacta(cedula.strip())
            
            if paciente_existente:
                print(f"👤 Paciente existente encontrado: {paciente_existente['nombreCompleto']}")
                return paciente_existente['id']
            
            # Crear nuevo paciente
            nuevo_paciente_data = {
                'nombreCompleto': f"{nombre.strip()} {apellido_paterno.strip()} {apellido_materno.strip()}".strip(),
                'cedula': cedula.strip()
            }
            
            # Usar método interno del repository para crear paciente
            with self.db_connection.get_connection() as conn:
                cursor = conn.cursor()
                paciente_id = self.repository._obtener_o_crear_paciente(cursor, nuevo_paciente_data)
                conn.commit()
            
            if paciente_id and paciente_id > 0:
                self.operacionExitosa.emit(f"Paciente gestionado correctamente: ID {paciente_id}")
                return paciente_id
            else:
                self.operacionError.emit("Error gestionando paciente")
                return -1
                
        except Exception as e:
            error_msg = f"Error gestionando paciente: {str(e)}"
            print(f"⚠️ {error_msg}")
            logger.error(error_msg)
            self.operacionError.emit(error_msg)
            return -1
    
    # ===============================
    # ✅ OPERACIONES CRUD CON RESTRICCIONES DE SEGURIDAD
    # ===============================
    
    @Slot('QVariant', result=str)
    def crear_procedimiento(self, datos_procedimiento):
        """Crea nuevo procedimiento de enfermería - CON SOPORTE ANÓNIMO"""
        try:
            # Verificar autenticación
            if not self._verificar_autenticacion():
                return self._crear_respuesta_json(False, "Usuario no autenticado")
            
            self._set_estado_actual("cargando")
            
            # Convertir datos de QML
            if hasattr(datos_procedimiento, 'toVariant'):
                datos = datos_procedimiento.toVariant()
            else:
                datos = datos_procedimiento
            
            # Validaciones básicas (modificadas para anónimo)
            if not self._validar_datos_procedimiento_anonimo(datos):
                self._set_estado_actual("error")
                return self._crear_respuesta_json(False, "Datos incompletos o inválidos")
            
            # Gestionar paciente (anónimo o normal)
            paciente_id = self._gestionar_paciente_procedimiento_anonimo(datos)
            if paciente_id <= 0:
                self._set_estado_actual("error")
                return self._crear_respuesta_json(False, "Error gestionando datos del paciente")
            
            # Preparar datos para repositorio
            datos_repo = {
                'nombreCompleto': datos.get('paciente', '').strip(),
                'cedula': datos.get('cedula', '').strip(),
                'idProcedimiento': int(datos.get('idProcedimiento', 0)),
                'cantidad': int(datos.get('cantidad', 1)),
                'tipo': datos.get('tipo', 'Normal'),
                'idTrabajador': int(datos.get('idTrabajador', 0)),
                'idRegistradoPor': self._usuario_actual_id,
                'fecha': datetime.now(),
                'esAnonimo': datos.get('esAnonimo', False)
            }
            
            print(f"💾 Usuario {self._usuario_actual_id} ({self._usuario_actual_rol}) creando procedimiento {'ANÓNIMO' if datos_repo['esAnonimo'] else 'NORMAL'}")
            
            # Crear procedimiento
            procedimiento_id = self.repository.crear_procedimiento_enfermeria(datos_repo)
            
            if procedimiento_id:
                # Recargar datos
                self._cargar_procedimientos_actuales()
                
                # Emitir signals
                procedimiento_completo = self._obtener_procedimiento_completo(procedimiento_id)
                self.procedimientoCreado.emit(self._crear_respuesta_json(True, procedimiento_completo))
                self.procedimientoCreado_old.emit(True, f"Procedimiento creado: ID {procedimiento_id}")
                
                mensaje = f"Procedimiento {'anónimo' if datos_repo['esAnonimo'] else 'normal'} creado exitosamente: ID {procedimiento_id}"
                self.operacionExitosa.emit(mensaje)
                
                self._set_estado_actual("listo")
                return self._crear_respuesta_json(True, {'procedimiento_id': procedimiento_id})
            else:
                raise ValueError("Error creando procedimiento en repositorio")
                
        except Exception as e:
            error_msg = f"Error creando procedimiento: {str(e)}"
            print(f"⚠️ {error_msg}")
            logger.error(error_msg)
            self.errorOcurrido.emit(error_msg, 'CREATE_EXCEPTION')
            self._set_estado_actual("error")
            return self._crear_respuesta_json(False, error_msg)
        
    def _validar_datos_procedimiento_anonimo(self, datos: Dict[str, Any]) -> bool:
        """Validación mejorada que considera modo anónimo"""
        try:
            # Validar procedimiento (siempre obligatorio)
            if not datos.get('idProcedimiento') or int(datos.get('idProcedimiento', 0)) <= 0:
                self.operacionError.emit("Debe seleccionar un procedimiento válido")
                return False
            
            # Validar trabajador (siempre obligatorio)
            if not datos.get('idTrabajador') or int(datos.get('idTrabajador', 0)) <= 0:
                self.operacionError.emit("Debe seleccionar un trabajador válido")
                return False
            
            # Validar cantidad (siempre obligatoria)
            if int(datos.get('cantidad', 0)) <= 0:
                self.operacionError.emit("La cantidad debe ser mayor a 0")
                return False
            
            # Validar tipo (siempre obligatorio)
            if datos.get('tipo') not in ['Normal', 'Emergencia']:
                self.operacionError.emit("Tipo de procedimiento inválido")
                return False
            
            # NUEVA LÓGICA: Si NO es anónimo, validar datos del paciente
            if not datos.get('esAnonimo', False):
                if not datos.get('paciente', '').strip():
                    self.operacionError.emit("Nombre del paciente es obligatorio")
                    return False
            
            print(f"✅ Validación exitosa - Modo: {'ANÓNIMO' if datos.get('esAnonimo', False) else 'NORMAL'}")
            return True
            
        except (ValueError, TypeError) as e:
            self.operacionError.emit(f"Error en validación de datos: {str(e)}")
            return False

    def _gestionar_paciente_procedimiento_anonimo(self, datos: Dict[str, Any]) -> int:
        """Gestiona paciente considerando modo anónimo"""
        try:
            es_anonimo = datos.get('esAnonimo', False)
            
            if es_anonimo:
                print("🎭 Gestionando paciente anónimo")
                return self._obtener_o_crear_paciente_anonimo()
            else:
                # Usar método normal existente
                nombre_completo = datos.get('paciente', '').strip()
                cedula = datos.get('cedula', '').strip()
                
                if not nombre_completo:
                    return -1
                
                # Dividir nombre completo
                nombres = nombre_completo.split()
                nombre = nombres[0] if len(nombres) > 0 else ''
                apellido_p = nombres[1] if len(nombres) > 1 else ''
                apellido_m = ' '.join(nombres[2:]) if len(nombres) > 2 else ''
                
                return self.buscar_o_crear_paciente_inteligente(nombre, apellido_p, apellido_m, cedula)
                
        except Exception as e:
            print(f"Error gestionando paciente: {e}")
            logger.error(f"Error gestionando paciente: {e}")
            return -1

    @Slot('QVariant', int, result=str)
    def actualizar_procedimiento(self, datos_procedimiento, procedimiento_id: int):
        """Actualiza procedimiento de enfermería existente - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN (sin restricción de fecha)"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN
            if not self._verificar_autenticacion():
                return self._crear_respuesta_json(False, "Usuario no autenticado")

            self._set_estado_actual("cargando")

            if procedimiento_id <= 0:
                self._set_estado_actual("error")
                return self._crear_respuesta_json(False, "ID de procedimiento inválido")

            # Ya no se valida la fecha para edición

            # Convertir datos
            if hasattr(datos_procedimiento, 'toVariant'):
                datos = datos_procedimiento.toVariant()
            else:
                datos = datos_procedimiento

            # Validaciones
            if not self._validar_datos_procedimiento_mejorado(datos):
                self._set_estado_actual("error")
                return self._crear_respuesta_json(False, "Datos incompletos o inválidos")

            # Gestionar paciente
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

            print(f"📝 Usuario {self._usuario_actual_id} ({self._usuario_actual_rol}) actualizando procedimiento ID: {procedimiento_id}")

            # Actualizar procedimiento
            exito = self.repository.actualizar_procedimiento_enfermeria(procedimiento_id, datos_repo)

            if exito:
                # Recargar datos
                self._cargar_procedimientos_actuales()

                # Emitir signals
                procedimiento_completo = self._obtener_procedimiento_completo(procedimiento_id)
                self.procedimientoActualizado.emit(self._crear_respuesta_json(True, procedimiento_completo))
                self.operacionExitosa.emit(f"Procedimiento {procedimiento_id} actualizado correctamente")

                self._set_estado_actual("listo")
                print(f"✅ Procedimiento {procedimiento_id} actualizado exitosamente")
                return self._crear_respuesta_json(True, {'procedimiento_id': procedimiento_id})
            else:
                error_msg = f"Error actualizando procedimiento {procedimiento_id} en repositorio"
                self.errorOcurrido.emit(error_msg, 'UPDATE_ERROR')
                self._set_estado_actual("error")
                return self._crear_respuesta_json(False, error_msg)

        except Exception as e:
            error_msg = f"Error actualizando procedimiento: {str(e)}"
            print(f"⚠️ {error_msg}")
            logger.error(error_msg)
            self.errorOcurrido.emit(error_msg, 'UPDATE_EXCEPTION')
            self._set_estado_actual("error")
            return self._crear_respuesta_json(False, error_msg)

    @Slot(int, result=bool)
    def eliminar_procedimiento(self, procedimiento_id: int) -> bool:
        try:
            # ✅ VERIFICAR PERMISOS DE ADMIN PARA ELIMINACIÓN
            if not self._verificar_permisos_admin():
                return False
            # ✅ VERIFICAR RESTRICCIONES DE ELIMINACIÓN SEGÚN ROL
            puede_eliminar, razon = self._verificar_permisos_eliminacion(procedimiento_id)
            if not puede_eliminar:
                self.operacionError.emit(razon)
                return False
            
            self._set_estado_actual("cargando")
            
            print(f"🗑️ Admin {self._usuario_actual_id} eliminando procedimiento ID: {procedimiento_id}")
            
            exito = self.repository.eliminar_procedimiento_enfermeria(procedimiento_id)
            
            if exito:
                self._cargar_procedimientos_actuales()
                
                self.procedimientoEliminado.emit(procedimiento_id)
                self.operacionExitosa.emit(f"Procedimiento {procedimiento_id} eliminado correctamente")
                self._set_estado_actual("listo")
                return True
            else:
                self.operacionError.emit(f"No se pudo eliminar procedimiento {procedimiento_id}")
                self._set_estado_actual("error")
                return False
                
        except Exception as e:
            error_msg = f"Error eliminando procedimiento: {str(e)}"
            logger.error(error_msg)
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return False
              
    # ===============================
    # GESTIÓN DE DATOS (SIN CAMBIOS - LECTURA)
    # ===============================
    
    @Slot()
    def actualizar_procedimientos(self):
        """Actualiza lista de procedimientos"""
        try:
            self._set_estado_actual("cargando")
            self._cargar_procedimientos_actuales()
            self._set_estado_actual("listo")
        except Exception as e:
            self.errorOcurrido.emit(f"Error cargando procedimientos: {str(e)}", 'LOAD_ERROR')
            self._set_estado_actual("error")
    
    # ===============================
    # APLICAR FILTROS Y PAGINACIÓN (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(str, str, str, str, str)
    def aplicar_filtros_y_recargar(self, search_term: str = "", tipo_procedimiento: str = "", 
                                tipo: str = "", fecha_desde: str = "", fecha_hasta: str = ""):
        """Aplica filtros estandarizados - SIN VERIFICACIÓN (solo lectura)"""
        try:
            self._set_estado_actual("cargando")
            
            # Resetear a página 0 siempre que cambien filtros
            self._currentPage = 0
            
            # Limpiar y estandarizar parámetros
            filtros_limpios = {
                'busqueda': search_term.strip() if search_term else "",
                'tipo_procedimiento': tipo_procedimiento.strip() if tipo_procedimiento else "",
                'tipo': tipo.strip() if tipo else "",
                'fecha_desde': fecha_desde.strip() if fecha_desde else "",
                'fecha_hasta': fecha_hasta.strip() if fecha_hasta else ""
            }
            
            # Validación específica para tipo
            tipo_limpio = filtros_limpios['tipo']
            if tipo_limpio and tipo_limpio not in ["", "Todos"]:
                if tipo_limpio not in ["Normal", "Emergencia"]:
                    print(f"⚠️ TIPO INVÁLIDO RECIBIDO: '{tipo_limpio}' - Ignorando")
                    filtros_limpios['tipo'] = ""
                else:
                    print(f"✅ TIPO VÁLIDO: '{tipo_limpio}'")
            
            # Filtrar valores vacíos y "Todos"
            filtros_aplicables = {}
            for key, value in filtros_limpios.items():
                if value and value not in ["", "Todos", "Seleccionar procedimiento..."]:
                    filtros_aplicables[key] = value
            
            # Actualizar filtros internos
            self._filtrosActuales = filtros_aplicables
            
            # Obtener datos paginados con filtros
            self.obtener_procedimientos_paginados(0, self._itemsPerPage, filtros_aplicables)
            
            # Emitir señal de filtros aplicados
            import json
            self.filtrosAplicados.emit(json.dumps(filtros_aplicables, ensure_ascii=False))
            
        except Exception as e:
            error_msg = f"Error aplicando filtros: {str(e)}"
            print(f"❌ {error_msg}")
            logger.error(error_msg)
            self.errorOcurrido.emit(error_msg, 'FILTER_ERROR')
            self._set_estado_actual("error")
    
    @Slot(int, int, 'QVariant', result='QVariant')
    def obtener_procedimientos_paginados(self, page: int, limit: int = 6, filters=None):
        """Obtiene página específica - SIN VERIFICACIÓN (solo lectura)"""
        try:
            if page < 0:
                page = 0
                
            limit_real = self._itemsPerPage
            
            if filters:
                if hasattr(filters, 'toVariant'):
                    filtros_dict = filters.toVariant()
                else:
                    filtros_dict = filters
            else:
                filtros_dict = self._filtrosActuales
            
            procedimientos = self.repository.obtener_procedimientos_paginados(
                page * limit_real, limit_real, filtros_dict
            )
            
            total_records = self.repository.contar_procedimientos_filtrados(filtros_dict)
            
            # Actualizar propiedades internas
            old_page = self._currentPage
            old_total_pages = self._totalPages
            old_total_records = self._totalRecords

            self._currentPage = page
            self._totalRecords = total_records
            self._totalPages = max(1, (self._totalRecords + limit_real - 1) // limit_real) if total_records > 0 else 1
            
            # Actualizar datos procedimientos
            self._procedimientosData = procedimientos
            
            # Emitir señales solo si cambiaron las propiedades
            if old_page != self._currentPage:
                self.currentPageChanged.emit()
            if old_total_pages != self._totalPages:
                self.totalPagesChanged.emit()
            if old_total_records != self._totalRecords:
                self.totalRecordsChanged.emit()
                
            # Emitir señal de datos actualizados
            self.procedimientosRecientesChanged.emit()
            
            self._set_estado_actual("listo")
            
            return {
                'procedimientos': self._procedimientosData,
                'page': page,
                'limit': limit_real,
                'total_records': self._totalRecords,
                'total_pages': self._totalPages,
                'success': True
            }
            
        except Exception as e:
            error_msg = f"Error obteniendo procedimientos paginados: {str(e)}"
            print(f"❌ {error_msg}")
            logger.error(error_msg)
            self.errorOcurrido.emit(error_msg, 'PAGINATION_EXCEPTION')
            self._set_estado_actual("error")
            return {'procedimientos': [], 'total': 0, 'page': 0, 'total_pages': 0, 'success': False}
    
    # ===============================
    # GESTIÓN DE DATOS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot()
    def actualizar_tipos_procedimientos(self):
        """Actualiza tipos de procedimientos"""
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
            self.tiposProcedimientosActualizados.emit()
            print(f"🔧 Tipos de procedimientos cargados: {len(self._tiposProcedimientosData)}")
            
        except Exception as e:
            error_msg = f"Error cargando tipos de procedimientos: {str(e)}"
            print(f"⚠️ {error_msg}")
            logger.error(error_msg)
            self.errorOcurrido.emit(error_msg, 'LOAD_TYPES_ERROR')
    
    @Slot()
    def actualizar_trabajadores_enfermeria(self):
        """Actualiza trabajadores con estructura completa"""
        try:
            trabajadores_raw = self.repository.obtener_trabajadores_enfermeria()
            self._trabajadoresData = []
            
            for trabajador in trabajadores_raw or []:
                self._trabajadoresData.append({
                    'id': trabajador['id'],
                    'nombreCompleto': trabajador['nombreCompleto'],
                    'nombre': trabajador['nombre'],
                    'apellidoPaterno': trabajador['apellidoPaterno'],
                    'apellidoMaterno': trabajador['apellidoMaterno'],
                    'tipoTrabajador': trabajador['tipoTrabajador'],
                    'matricula': trabajador['matricula'],
                    'especialidad': trabajador['especialidad']
                })
            
            self.trabajadoresChanged.emit()
            self.trabajadoresActualizados.emit()
            print(f"👥 Trabajadores cargados: {len(self._trabajadoresData)}")
            
        except Exception as e:
            error_msg = f"Error cargando trabajadores: {str(e)}"
            print(f"⚠️ {error_msg}")
            logger.error(error_msg)
            self.errorOcurrido.emit(error_msg, 'LOAD_WORKERS_ERROR')
    
    @Slot()
    def refrescar_datos(self):
        """Refresca todos los datos del modelo"""
        try:
            self._set_estado_actual("cargando")
            
            #print("🔄 Refrescando todos los datos del modelo...")
            
            # Cargar datos de referencia
            self.actualizar_tipos_procedimientos()
            self.actualizar_trabajadores_enfermeria()
            
            # Recargar procedimientos con filtros actuales
            self.obtener_procedimientos_paginados(self._currentPage, self._itemsPerPage, self._filtrosActuales)
            
            self._set_estado_actual("listo")
            self.operacionExitosa.emit("Datos actualizados correctamente")
            
        except Exception as e:
            error_msg = f"Error refrescando datos: {str(e)}"
            print(f"❌ {error_msg}")
            logger.error(error_msg)
            self.errorOcurrido.emit(error_msg, 'REFRESH_ERROR')
            self._set_estado_actual("error")

    @Slot()
    def limpiar_cache_procedimientos(self):
        """Limpia cache para forzar recarga"""
        try:
            self._procedimientosData = []
            self.actualizar_procedimientos()
            print("🧹 Cache de procedimientos limpiado")
        except Exception as e:
            print(f"⚠️ Error limpiando cache: {e}")
    
    @Slot(result=str)
    def diagnosticar_filtros_activos(self):
        """Método para diagnosticar el estado actual de filtros"""
        try:
            diagnostico = {
                'filtros_internos': self._filtrosActuales,
                'pagina_actual': self._currentPage,
                'total_registros': self._totalRecords,
                'items_por_pagina': self._itemsPerPage,
                'estado_modelo': self._estadoActual,
                'usuario_autenticado': self._usuario_actual_id  # ✅ AGREGADO
            }
            
            import json
            result = json.dumps(diagnostico, ensure_ascii=False, indent=2)
            print("📊 DIAGNÓSTICO DE FILTROS:")
            print(result)
            return result
            
        except Exception as e:
            error_msg = f"Error en diagnóstico: {str(e)}"
            print(f"❌ {error_msg}")
            return json.dumps({'error': error_msg})
        
    
    # ===============================
    # MÉTODOS INTERNOS (SIN CAMBIOS IMPORTANTES)
    # ===============================
    
    def _inicializar_datos(self):
        """Inicialización inmediata de datos"""
        try:
            
            # Cargar datos de referencia primero
            self.actualizar_tipos_procedimientos()
            self.actualizar_trabajadores_enfermeria()
            
            # Cargar procedimientos iniciales
            self._cargar_procedimientos_actuales()
            
            print("✅ Datos iniciales cargados correctamente")
        except Exception as e:
            print(f"❌ Error en inicialización: {e}")
            logger.error(f"Error en inicialización: {e}")
    
    def _cargar_procedimientos_actuales(self):
        """Carga procedimientos usando filtros actuales"""
        try:
            #print(f"🔄 Recargando procedimientos con {self._itemsPerPage} elementos por página")
            self.obtener_procedimientos_paginados(self._currentPage, self._itemsPerPage, self._filtrosActuales)
        except Exception as e:
            print(f"❌ Error recargando procedimientos: {e}")
            logger.error(f"Error recargando procedimientos: {e}")
            self._procedimientosData = []
            self.procedimientosRecientesChanged.emit()
    
    def _validar_datos_procedimiento_mejorado(self, datos: Dict[str, Any]) -> bool:
        """Validación mejorada de datos"""
        try:
            # Validar paciente
            if not datos.get('paciente', '').strip():
                self.operacionError.emit("Nombre del paciente es obligatorio")
                return False
            
            # Validar procedimiento
            if not datos.get('idProcedimiento') or int(datos.get('idProcedimiento', 0)) <= 0:
                self.operacionError.emit("Debe seleccionar un procedimiento válido")
                return False
            
            # Validar trabajador
            if not datos.get('idTrabajador') or int(datos.get('idTrabajador', 0)) <= 0:
                self.operacionError.emit("Debe seleccionar un trabajador válido")
                return False
            
            # Validar cantidad
            if int(datos.get('cantidad', 0)) <= 0:
                self.operacionError.emit("La cantidad debe ser mayor a 0")
                return False
            
            # Validar tipo
            if datos.get('tipo') not in ['Normal', 'Emergencia']:
                self.operacionError.emit("Tipo de procedimiento inválido")
                return False
            
            return True
            
        except (ValueError, TypeError) as e:
            self.operacionError.emit(f"Error en validación de datos: {str(e)}")
            return False
        
    @Slot(int, result='QVariantMap')
    def verificar_permisos_procedimiento(self, procedimiento_id: int):
        """Verifica permisos del usuario actual para un procedimiento específico"""
        try:
            puede_editar = self._usuario_actual_rol in ["Administrador", "Médico"]
            puede_eliminar, razon_eliminar = self._verificar_permisos_eliminacion(procedimiento_id)
            es_admin = self._usuario_actual_rol == "Administrador"
            es_medico = self._usuario_actual_rol == "Médico"
            
            # Obtener información del procedimiento
            procedimiento = self.repository.get_procedimiento_by_id(procedimiento_id)
            dias_antiguedad = 0
            
            if procedimiento:
                fecha_procedimiento = procedimiento.get('Fecha')
                if fecha_procedimiento:
                    try:
                        if isinstance(fecha_procedimiento, str):
                            fecha_obj = datetime.fromisoformat(fecha_procedimiento.replace('Z', ''))
                        elif isinstance(fecha_procedimiento, datetime):
                            fecha_obj = fecha_procedimiento
                        else:
                            fecha_obj = datetime.now()
                        
                        dias_antiguedad = (datetime.now() - fecha_obj).days
                    except:
                        dias_antiguedad = 0
            
            return {
                'puede_editar': puede_editar,
                'puede_eliminar': puede_eliminar,
                'razon_eliminar': razon_eliminar,
                'es_administrador': es_admin,
                'es_medico': es_medico,
                'dias_antiguedad': dias_antiguedad,
                'limite_dias': 30
            }
            
        except Exception as e:
            print(f"⚠️ Error verificando permisos procedimiento: {e}")
            return {
                'puede_editar': False,
                'puede_eliminar': False,
                'es_administrador': False,
                'es_medico': False,
                'dias_antiguedad': 999,
                'limite_dias': 30
            }
    
    def _gestionar_paciente_procedimiento(self, datos: Dict[str, Any]) -> int:
        """Gestiona paciente para procedimiento"""
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
            logger.error(f"Error gestionando paciente: {e}")
            return -1
    
    def _obtener_procedimiento_completo(self, procedimiento_id: int) -> Dict[str, Any]:
        """Obtiene procedimiento completo por ID"""
        try:
            for proc in self._procedimientosData:
                if int(proc.get('procedimientoId', 0)) == procedimiento_id:
                    return proc
            return {}
        except Exception:
            return {}
    
    def _crear_respuesta_json(self, exito: bool, datos: Any) -> str:
        """Crea respuesta JSON consistente"""
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
        """Auto-refresh optimizado"""
        self._autoRefreshTimer = QTimer(self)
        self._autoRefreshTimer.timeout.connect(self._auto_refresh_ligero)
        # Deshabilitado por defecto
    
    def _auto_refresh_ligero(self):
        """Auto-refresh ligero que no interfiere con la interfaz"""
        try:
            if self._estadoActual == "listo":
                self.actualizar_tipos_procedimientos()
                self.actualizar_trabajadores_enfermeria()
        except Exception as e:
            logger.error(f"Error en auto-refresh: {e}")
    
    @Slot()
    def _actualizar_tipos_procedimientos_desde_signal(self):
        """Actualiza tipos de procedimientos cuando recibe señal global"""
        try:
            print("📡 EnfermeriaModel: Recibida señal de actualización de tipos de procedimientos")
            self.actualizar_tipos_procedimientos()
            print("✅ Tipos de procedimientos actualizados desde señal global en EnfermeriaModel")
        except Exception as e:
            print(f"❌ Error actualizando tipos desde señal: {e}")

    @Slot(str)
    def _manejar_actualizacion_global(self, mensaje: str):
        """Maneja actualizaciones globales de enfermería"""
        try:
            print(f"📡 EnfermeriaModel: {mensaje}")
            self.tiposProcedimientosActualizados.emit()
        except Exception as e:
            print(f"❌ Error manejando actualización global: {e}")

    def cleanup(self):
        """Método genérico de limpieza para cualquier modelo QObject"""
        try:
            model_name = self.__class__.__name__
            print(f"🧹 Iniciando limpieza de {model_name}...")
            
            # Detener timers
            timer_count = 0
            for attr_name in dir(self):
                if (attr_name.endswith('Timer') or attr_name.endswith('_timer')):
                    timer = getattr(self, attr_name)
                    if timer and hasattr(timer, 'isActive') and timer.isActive():
                        try:
                            timer.stop()
                            timer_count += 1
                        except Exception as e:
                            print(f"⚠️ Error deteniendo timer {attr_name}: {e}")
            
            if timer_count > 0:
                print(f"⏹️ {timer_count} timers detenidos")
            
            # ✅ RESETEAR USUARIO Y ROL
            self._usuario_actual_id = 0
            self._usuario_actual_rol = ""
            
            # Limpiar datos en memoria
            self._procedimientosData = []
            self._tiposProcedimientosData = []
            self._trabajadoresData = []
            self._estadisticasData = {}
            self._filtrosActuales = {}
            
            print(f"📊 Datos de {model_name} limpiados")
            print(f"✅ Limpieza de {model_name} completada")
            
        except Exception as e:
            print(f"❌ Error durante cleanup de {self.__class__.__name__}: {e}")

    """
    Slots de búsqueda de pacientes para enfermeria_model.py
    Agregar estos métodos a la clase EnfermeriaModel
    """

    @Slot(str, int, result='QVariantList')
    def buscar_paciente_unificado(self, termino_busqueda: str, limite: int = 5):
        """Slot unificado para búsqueda inteligente de pacientes - CORREGIDO"""
        try:
            if len(termino_busqueda.strip()) < 2:
                return []
            
            print(f"🔍 Búsqueda unificada: '{termino_busqueda}' (límite: {limite})")
            
            resultados = self.repository.buscar_paciente_unificado(termino_busqueda.strip(), limite)
            
            # ✅ CONVERTIR CON NOMBRES CONSISTENTES PARA QML
            resultados_qml = []
            for resultado in resultados:
                # ✅ MAPEO CORREGIDO - Usar nombres que coincidan con QML
                paciente_qml = {
                    'id': resultado.get('id', 0),
                    'nombre': resultado.get('nombre', ''),
                    'apellidoPaterno': resultado.get('apellidoPaterno', ''),  # ✅ camelCase para Python
                    'apellidoMaterno': resultado.get('apellidoMaterno', ''),  # ✅ camelCase para Python
                    'nombreCompleto': resultado.get('nombreCompleto', ''),   # ✅ camelCase para Python
                    'cedula': resultado.get('cedula', ''),
                    'tipo_coincidencia': resultado.get('tipo_coincidencia', 'general'),
                    'score': float(resultado.get('score', 1.0))
                }
                
                resultados_qml.append(paciente_qml)
            
            print(f"📋 Encontrados {len(resultados_qml)} pacientes")
            return resultados_qml
            
        except Exception as e:
            error_msg = f"Error en búsqueda unificada: {str(e)}"
            print(f"⚠️ {error_msg}")
            logger.error(error_msg)
            self.errorOcurrido.emit(error_msg, 'UNIFIED_SEARCH_ERROR')
            return []

    @Slot(str, result='QVariantMap')
    def buscar_paciente_por_cedula(self, cedula: str):
        """Busca un paciente específico por su cédula - CORREGIDO"""
        try:
            if len(cedula.strip()) < 5:
                return {}
            
            print(f"🔍 Buscando paciente por cédula: {cedula}")
            
            paciente = self.repository.search_patient_by_cedula_exact(cedula.strip())
            
            if paciente:
                # ✅ CONVERTIR NOMBRES A FORMATO CONSISTENTE
                paciente_corregido = {
                    'id': paciente.get('id', 0),
                    'nombre': paciente.get('nombre', ''),
                    'apellidoPaterno': paciente.get('apellidoPaterno', ''),
                    'apellidoMaterno': paciente.get('apellidoMaterno', ''),
                    'nombreCompleto': paciente.get('nombreCompleto', ''),
                    'cedula': paciente.get('cedula', ''),
                    'tipo_coincidencia': paciente.get('tipo_coincidencia', 'cedula_exacta'),
                    'score': float(paciente.get('score', 1.0))
                }
                
                print(f"👤 Paciente encontrado: {paciente_corregido.get('nombreCompleto', 'N/A')}")
                self.pacienteEncontradoPorCedula.emit(paciente_corregido)
                return paciente_corregido
            else:
                print(f"⚠️ No se encontró paciente con cédula: {cedula}")
                self.pacienteNoEncontrado.emit(cedula)
                return {}
                
        except Exception as e:
            error_msg = f"Error buscando paciente por cédula: {str(e)}"
            print(f"⚠️ {error_msg}")
            logger.error(error_msg)
            self.errorOcurrido.emit(error_msg, 'CEDULA_SEARCH_ERROR')
            return {}

    @Slot(str, str, str, str, result=int)
    def buscar_o_crear_paciente_inteligente(self, nombre: str, apellido_paterno: str, 
                                        apellido_materno: str = "", cedula: str = "") -> int:
        """Busca paciente por cédula o crea uno nuevo"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN PARA OPERACIÓN DE ESCRITURA
            if not self._verificar_autenticacion():
                return -1
            
            if not nombre or len(nombre.strip()) < 2:
                self.operacionError.emit("Nombre es obligatorio")
                return -1
            
            if not apellido_paterno or len(apellido_paterno.strip()) < 2:
                self.operacionError.emit("Apellido paterno es obligatorio")
                return -1
            
            # La cédula es opcional ahora
            cedula_clean = cedula.strip() if cedula else ""
            
            print(f"🔄 Usuario {self._usuario_actual_id} ({self._usuario_actual_rol}) gestionando paciente: {nombre} {apellido_paterno}")
            
            # Usar método inteligente del repository
            paciente_id = self.repository.buscar_o_crear_paciente_simple(
                nombre.strip(),
                apellido_paterno.strip(),
                apellido_materno.strip(),
                cedula_clean
            )
            
            if paciente_id and paciente_id > 0:
                self.operacionExitosa.emit(f"Paciente gestionado correctamente: ID {paciente_id}")
                return paciente_id
            else:
                self.operacionError.emit("Error gestionando paciente")
                return -1
                
        except Exception as e:
            error_msg = f"Error gestionando paciente: {str(e)}"
            print(f"⚠️ {error_msg}")
            logger.error(error_msg)
            self.operacionError.emit(error_msg)
            return -1

    @Slot(str, int, result='QVariantList')
    def buscar_pacientes_por_nombre(self, nombre_completo: str, limite: int = 5):
        """Busca pacientes por nombre completo - CORREGIDO"""
        try:
            if len(nombre_completo.strip()) < 3:
                return []
            
            print(f"🔍 Buscando pacientes por nombre: {nombre_completo}")
            
            resultados = self.repository.search_patient_by_full_name(nombre_completo.strip(), limite)
            
            # ✅ CONVERTIR A FORMATO QML CONSISTENTE
            resultados_qml = []
            for resultado in resultados:
                paciente_qml = {
                    'id': resultado.get('id', 0),
                    'nombre': resultado.get('nombre', ''),
                    'apellidoPaterno': resultado.get('apellidoPaterno', ''),
                    'apellidoMaterno': resultado.get('apellidoMaterno', ''),
                    'nombreCompleto': resultado.get('nombreCompleto', ''),
                    'cedula': resultado.get('cedula', ''),
                    'tipo_coincidencia': resultado.get('tipo_coincidencia', 'nombre'),
                    'score': float(resultado.get('score', 1.0))
                }
                resultados_qml.append(paciente_qml)
            
            print(f"📋 Encontrados {len(resultados_qml)} pacientes por nombre")
            return resultados_qml
            
        except Exception as e:
            error_msg = f"Error buscando por nombre: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.operacionError.emit(error_msg)
            return []

    @Slot(str, result='QVariantMap')
    def analizar_nombre_completo(self, nombre_completo: str):
        """Analiza un nombre completo y lo separa en componentes - CORREGIDO"""
        try:
            if not nombre_completo or len(nombre_completo.strip()) < 2:
                return {
                    'nombre': '',
                    'apellidoPaterno': '',  # ✅ camelCase consistente
                    'apellidoMaterno': ''   # ✅ camelCase consistente
                }
            
            componentes = self.repository._analizar_termino_nombre(nombre_completo.strip())
            
            # ✅ MAPEAR A NOMBRES CONSISTENTES
            return {
                'nombre': componentes.get('nombre', ''),
                'apellidoPaterno': componentes.get('apellido_paterno', ''),  # ✅ convertir naming
                'apellidoMaterno': componentes.get('apellido_materno', '')   # ✅ convertir naming
            }
            
        except Exception as e:
            error_msg = f"Error analizando nombre: {str(e)}"
            print(f"⚠️ {error_msg}")
            logger.error(error_msg)
            return {
                'nombre': '',
                'apellidoPaterno': '',
                'apellidoMaterno': ''
            }


    @Slot(str, result=str)
    def detectar_tipo_busqueda(self, termino: str):
        """Detecta el tipo de búsqueda según el término ingresado"""
        try:
            if not termino or len(termino.strip()) < 2:
                return "desconocido"
            
            tipo = self.repository._detectar_tipo_busqueda(termino.strip())
            return tipo
            
        except Exception as e:
            error_msg = f"Error detectando tipo de búsqueda: {str(e)}"
            print(f"⚠️ {error_msg}")
            logger.error(error_msg)
            return "desconocido"

    @Slot(str, int, result='QVariantList')
    def buscar_pacientes(self, termino_busqueda: str, limite: int = 5):
        """Busca pacientes usando el nuevo sistema unificado - CORREGIDO"""
        try:
            # ✅ USAR EL MÉTODO UNIFICADO CORREGIDO
            return self.buscar_paciente_unificado(termino_busqueda, limite)
            
        except Exception as e:
            error_msg = f"Error en búsqueda de pacientes: {str(e)}"
            print(f"⚠️ {error_msg}")
            logger.error(error_msg)
            self.errorOcurrido.emit(error_msg, 'PATIENT_SEARCH_ERROR')
            return []

    # ===============================
    # MÉTODOS AUXILIARES PARA BÚSQUEDA
    # ===============================

    def _gestionar_paciente_procedimiento_mejorado(self, datos: Dict[str, Any]) -> int:
        """
        Gestión mejorada de paciente para procedimiento usando búsqueda inteligente
        Reemplaza el método _gestionar_paciente_procedimiento existente
        """
        try:
            nombre_completo = datos.get('paciente', '').strip()
            cedula = datos.get('cedula', '').strip()
            
            if not nombre_completo:
                return -1
            
            # Analizar nombre completo
            componentes = self.analizar_nombre_completo(nombre_completo)
            nombre = componentes.get('nombre', '')
            apellido_p = componentes.get('apellidoPaterno', '')
            apellido_m = componentes.get('apellidoMaterno', '')
            
            # Si tenemos cédula, priorizarla para búsqueda
            if cedula and len(cedula) >= 5:
                # Buscar por cédula primero
                paciente_existente = self.buscar_paciente_por_cedula(cedula)
                if paciente_existente and paciente_existente.get('id'):
                    print(f"👤 Paciente encontrado por cédula: {paciente_existente['nombreCompleto']}")
                    return paciente_existente['id']
            
            # Si no se encuentra por cédula o no hay cédula, usar método inteligente
            return self.buscar_o_crear_paciente_inteligente(nombre, apellido_p, apellido_m, cedula)
            
        except Exception as e:
            print(f"Error gestionando paciente mejorado: {e}")
            logger.error(f"Error gestionando paciente mejorado: {e}")
            return -1

    # ===============================
    # SLOTS PARA COMPATIBILIDAD (mantener métodos existentes)
    # ===============================

    # Mantener el método original como fallback
    def buscar_paciente_por_cedula_legacy(self, cedula: str):
        """Método legacy - usar buscar_paciente_por_cedula en su lugar"""
        return self.buscar_paciente_por_cedula(cedula)

    def buscar_pacientes_por_nombre_legacy(self, nombre_completo: str, limite: int = 5):
        """Método legacy - usar buscar_pacientes_por_nombre en su lugar"""
        return self.buscar_pacientes_por_nombre(nombre_completo, limite)
    
    @Slot(str, result=str)
    def debug_busqueda_paciente(self, termino: str):
        """Método de debugging para verificar el flujo de búsqueda"""
        try:
            import json
            
            print(f"🔍 DEBUG: Iniciando búsqueda para '{termino}'")
            
            # Detectar tipo
            tipo = self.detectar_tipo_busqueda(termino)
            print(f"🔍 DEBUG: Tipo detectado: {tipo}")
            
            # Realizar búsqueda
            resultados = self.buscar_paciente_unificado(termino, 5)
            
            debug_info = {
                'termino_original': termino,
                'tipo_detectado': tipo,
                'cantidad_resultados': len(resultados),
                'resultados': resultados[:2] if resultados else []  # Solo primeros 2 para debug
            }
            
            resultado_json = json.dumps(debug_info, ensure_ascii=False, indent=2)
            print(f"🔍 DEBUG: Resultado completo:\n{resultado_json}")
            
            return resultado_json
            
        except Exception as e:
            error_msg = f"Error en debug de búsqueda: {str(e)}"
            print(f"⚠️ {error_msg}")
            return json.dumps({'error': error_msg})
        
    # ===============================
    # 7. MÉTODO AUXILIAR PARA VALIDAR ESTRUCTURA
    # ===============================

    def _validar_estructura_paciente(self, paciente_data: dict) -> dict:
        """Valida y normaliza la estructura de datos de paciente"""
        try:
            # ✅ ESTRUCTURA ESTÁNDAR PARA QML
            paciente_normalizado = {
                'id': int(paciente_data.get('id', 0)),
                'nombre': str(paciente_data.get('nombre', '')),
                'apellidoPaterno': str(paciente_data.get('apellidoPaterno', '') or 
                                    paciente_data.get('apellido_paterno', '')),
                'apellidoMaterno': str(paciente_data.get('apellidoMaterno', '') or 
                                    paciente_data.get('apellido_materno', '')),
                'nombreCompleto': str(paciente_data.get('nombreCompleto', '') or 
                                    paciente_data.get('nombre_completo', '')),
                'cedula': str(paciente_data.get('cedula', '')),
                'tipo_coincidencia': str(paciente_data.get('tipo_coincidencia', 'general')),
                'score': float(paciente_data.get('score', 1.0))
            }
            
            # ✅ GENERAR nombreCompleto si está vacío
            if not paciente_normalizado['nombreCompleto']:
                nombre_parts = [
                    paciente_normalizado['nombre'],
                    paciente_normalizado['apellidoPaterno'],
                    paciente_normalizado['apellidoMaterno']
                ]
                paciente_normalizado['nombreCompleto'] = ' '.join(filter(None, nombre_parts)).strip()
            
            return paciente_normalizado
            
        except Exception as e:
            print(f"⚠️ Error validando estructura paciente: {e}")
            return {
                'id': 0,
                'nombre': '',
                'apellidoPaterno': '',
                'apellidoMaterno': '',
                'nombreCompleto': '',
                'cedula': '',
                'tipo_coincidencia': 'error',
                'score': 0.0
            }
        
    @Slot(str, str, str, str, bool, result=int)
    def buscar_o_crear_paciente_con_anonimo(self, nombre: str, apellido_paterno: str, 
                                        apellido_materno: str = "", cedula: str = "", 
                                        es_anonimo: bool = False) -> int:
        """Busca o crea paciente, incluyendo manejo de pacientes anónimos"""
        try:
            # Verificar autenticación
            if not self._verificar_autenticacion():
                return -1
            
            # Si es anónimo, buscar/crear paciente anónimo
            if es_anonimo:
                print(f"🎭 Usuario {self._usuario_actual_id} creando procedimiento anónimo")
                return self._obtener_o_crear_paciente_anonimo()
            
            # Validaciones para paciente normal
            if not nombre or len(nombre.strip()) < 2:
                self.operacionError.emit("Nombre es obligatorio para paciente normal")
                return -1
            
            if not apellido_paterno or len(apellido_paterno.strip()) < 2:
                self.operacionError.emit("Apellido paterno es obligatorio para paciente normal")
                return -1
            
            # Usar el método existente para pacientes normales
            return self.buscar_o_crear_paciente_inteligente(nombre, apellido_paterno, apellido_materno, cedula)
            
        except Exception as e:
            error_msg = f"Error gestionando paciente: {str(e)}"
            print(f"⚠️ {error_msg}")
            logger.error(error_msg)
            self.operacionError.emit(error_msg)
            return -1

    def _obtener_o_crear_paciente_anonimo(self) -> int:
        """Obtiene o crea el paciente anónimo único del sistema"""
        try:
            # Buscar paciente anónimo existente
            paciente_anonimo = self.repository.buscar_paciente_anonimo()
            
            if paciente_anonimo:
                print(f"🎭 Usando paciente anónimo existente ID: {paciente_anonimo['id']}")
                return paciente_anonimo['id']
            
            # Crear paciente anónimo si no existe
            paciente_id = self.repository.crear_paciente_anonimo()
            
            if paciente_id > 0:
                print(f"🎭 Paciente anónimo creado con ID: {paciente_id}")
                self.operacionExitosa.emit(f"Paciente anónimo preparado para procedimiento")
                return paciente_id
            else:
                self.operacionError.emit("Error creando paciente anónimo")
                return -1
                
        except Exception as e:
            print(f"💥 Error gestionando paciente anónimo: {e}")
            logger.error(f"Error gestionando paciente anónimo: {e}")
            return -1

# ===============================
# REGISTRO PARA QML
# ===============================

def register_enfermeria_model():
    """Registra el EnfermeriaModel con restricciones de seguridad para uso en QML"""
    try:
        qmlRegisterType(EnfermeriaModel, "Clinica.Models", 1, 0, "EnfermeriaModel")
        print("✅ EnfermeriaModel con restricciones de seguridad registrado para QML")
    except Exception as e:
        print(f"❌ Error registrando EnfermeriaModel: {e}")
        raise