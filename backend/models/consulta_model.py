"""
Modelo QObject para Gestión de Consultas Médicas - CORREGIDO con set_usuario_actual
Expone funcionalidad de consultas a QML con Signals/Slots/Properties
"""

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtQml import qmlRegisterType
from typing import List, Dict, Any, Optional
import json
from datetime import datetime, timedelta

from ..core.excepciones import ExceptionHandler, ClinicaBaseException
from ..repositories.consulta_repository import ConsultaRepository
from ..repositories.medico_repository import MedicoRepository
from ..core.Signals_manager import get_global_signals

class ConsultaModel(QObject):
    """
    Modelo QObject para gestión completa de consultas médicas - CORREGIDO con usuario
    Conecta la lógica de negocio con la interfaz QML
    """
    
    # ===============================
    # SIGNALS PARA QML
    # ===============================
    
    # Operaciones CRUD
    consultaCreada = Signal(str, arguments=['datos'])  # JSON con datos de la consulta
    consultaActualizada = Signal(str, arguments=['datos'])
    consultaEliminada = Signal(int, arguments=['consultaId'])
    
    # NUEVAS SEÑALES para búsqueda por cédula
    pacienteEncontradoPorCedula = Signal('QVariantMap', arguments=['pacienteData'])
    pacienteNoEncontrado = Signal(str, arguments=['cedula'])
    
    # Búsquedas y filtros
    resultadosBusqueda = Signal(str, arguments=['resultados'])  # JSON
    filtrosAplicados = Signal(str, arguments=['criterios'])
    
    # Dashboard y estadísticas
    dashboardActualizado = Signal(str, arguments=['datos'])
    estadisticasCalculadas = Signal(str, arguments=['estadisticas'])
    
    # Estados y notificaciones
    estadoCambiado = Signal(str, arguments=['nuevoEstado'])
    operacionError = Signal(str, arguments=['mensaje'])  # AÑADIDO para compatibilidad
    operacionExitosa = Signal(str, arguments=['mensaje'])
    
    # Datos actualizados
    consultasRecientesChanged = Signal()
    especialidadesChanged = Signal()
    medicosDisponiblesChanged = Signal()
    
    # NUEVAS SEÑALES PARA MÉDICOS
    medicosEspecialidadChanged = Signal()
    especialidadesFiltradaChanged = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._is_initializing = False
        
        # Repositories
        self.repository = ConsultaRepository()
        self.medico_repo = MedicoRepository()
        self.global_signals = get_global_signals()
        self._conectar_senales_globales()
        # Estados internos
        self._consultasData = []
        self._especialidadesData = []
        self._medicosData = []
        self._dashboardData = {}
        self._estadisticasData = {}
        self._estadoActual = "listo"  # listo, cargando, error
        # ✅ AUTENTICACIÓN CON ROL
        self._usuario_actual_id = 0
        self._usuario_actual_rol = ""  # ✅ NUEVO: Almacenar rol del usuario
        
        # Configuración
        self._autoRefreshInterval = 30000  # 30 segundos
        self._setupAutoRefresh()
    
    # ===============================
    # ✅ MÉTODO FALTANTE PARA APPCONTROLLER
    # ===============================
    def _conectar_senales_globales(self):
        """Conecta con las señales globales para recibir actualizaciones"""
        try:
            # ✅ Conectar señales de especialidades
            self.global_signals.especialidadesModificadas.connect(self._actualizar_especialidades_desde_signal)
            self.global_signals.consultasNecesitaActualizacion.connect(self._manejar_actualizacion_global)
            
            # ✅ NUEVO: Conectar señales de trabajadores
            self.global_signals.trabajadoresNecesitaActualizacion.connect(self._actualizar_trabajadores_desde_signal)
            self.global_signals.tiposTrabajadoresModificados.connect(self._actualizar_trabajadores_desde_signal)
            
            print("🔗 Señales globales conectadas en ConsultaModel (incluyendo trabajadores)")
        except Exception as e:
            print(f"❌ Error conectando señales globales en ConsultaModel: {e}")

    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """Método simple para establecer usuario (sin rol) - Para compatibilidad"""
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario establecido en ConsultaModel (simple): ID {usuario_id}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de consultas")
            else:
                print(f"⚠️ ID de usuario inválido en ConsultaModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en ConsultaModel: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")

    @Slot(int, str)
    def set_usuario_actual_con_rol(self, usuario_id: int, usuario_rol: str):
        """
        ✅ MÉTODO PRINCIPAL - Establece el usuario actual CON ROL para verificaciones de permisos
        """
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                self._usuario_actual_rol = usuario_rol.strip()
                print(f"👤 Usuario establecido en ConsultaModel: ID {usuario_id}, Rol: {usuario_rol}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} ({usuario_rol}) establecido en módulo de consultas")
                
                # ✅ CARGAR DATOS INICIALES DESPUÉS DE AUTENTICACIÓN
                self.refrescar_datos()
                
            else:
                print(f"⚠️ ID de usuario inválido en ConsultaModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en ConsultaModel: {e}")
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
    def _verificar_permisos_medico_o_admin(self) -> bool:
        """Verifica permisos de médico o administrador"""
        if not self._verificar_autenticacion():
            return False
        
        if self._usuario_actual_rol not in ["Administrador", "Médico"]:
            self.operacionError.emit("Solo médicos y administradores pueden realizar esta operación")
            print(f"🚫 Acceso denegado: Usuario {self._usuario_actual_id} (Rol: {self._usuario_actual_rol})")
            return False
        
        return True
    def _validar_fecha_eliminacion(self, fecha_registro, dias_limite: int = 30) -> bool:
        """Valida que el registro no sea muy antiguo para eliminar - SOLO PARA MÉDICOS"""
        try:
            if not fecha_registro:
                return True
            
            if isinstance(fecha_registro, str):
                try:
                    fecha_obj = datetime.fromisoformat(fecha_registro.replace('Z', ''))
                except:
                    fecha_obj = datetime.strptime(fecha_registro[:10], '%Y-%m-%d')
            elif isinstance(fecha_registro, datetime):
                fecha_obj = fecha_registro
            else:
                return True
            
            dias_transcurridos = (datetime.now() - fecha_obj).days
            if dias_transcurridos > dias_limite:
                return False
            
            return True
            
        except Exception as e:
            print(f"⚠️ Error validando fecha eliminación: {e}")
            return True
    # ===============================
    # PROPERTIES PARA QML
    # ===============================
    
    def _get_consultas_json(self) -> str:
        """Getter para consultas en formato JSON"""
        return json.dumps(self._consultasData, default=str, ensure_ascii=False)
    
    def _get_especialidades_json(self) -> str:
        """Getter para especialidades en formato JSON"""
        return json.dumps(self._especialidadesData, default=str, ensure_ascii=False)
    
    def _get_medicos_json(self) -> str:
        """Getter para doctores en formato JSON"""
        return json.dumps(self._medicosData, default=str, ensure_ascii=False)
    
    def _get_dashboard_json(self) -> str:
        """Getter para datos de dashboard en formato JSON"""
        return json.dumps(self._dashboardData, default=str, ensure_ascii=False)
    
    def _get_estado_actual(self) -> str:
        """Getter para estado actual"""
        return self._estadoActual
    
    def _set_estado_actual(self, nuevo_estado: str):
        """Setter para estado actual"""
        if self._estadoActual != nuevo_estado:
            self._estadoActual = nuevo_estado
            self.estadoCambiado.emit(nuevo_estado)
    
    # Properties expuestas a QML
    consultasJson = Property(str, _get_consultas_json, notify=consultasRecientesChanged)
    especialidadesJson = Property(str, _get_especialidades_json, notify=especialidadesChanged)
    medicosJson = Property(str, _get_medicos_json, notify=medicosDisponiblesChanged)
    dashboardJson = Property(str, _get_dashboard_json, notify=dashboardActualizado)
    estadoActual = Property(str, _get_estado_actual, notify=estadoCambiado)
    
    # Properties adicionales para compatibilidad con QML existente
    @Property(list, notify=consultasRecientesChanged)
    def consultas_recientes(self):
        """Lista de consultas recientes para compatibilidad"""
        return self._consultasData
    
    @Property(list, notify=especialidadesChanged)
    def especialidades(self):
        """Lista de especialidades para compatibilidad"""
        return self._especialidadesData
    
    @Property(list, notify=medicosDisponiblesChanged)
    def doctores_disponibles(self):
        """Lista de doctores disponibles para compatibilidad"""
        return self._medicosData
    
    # ===============================
    # SLOTS PARA BÚSQUEDA POR CÉDULA - CORREGIDOS
    # ===============================

    @Slot(int, int, str, str, result=str)
    def crear_consulta(self, paciente_id: int, especialidad_id: int, tipo_consulta: str, detalles: str) -> str:
        """
        Crea una nueva consulta médica
        
        Args:
            paciente_id (int): ID del paciente
            especialidad_id (int): ID de la especialidad
            tipo_consulta (str): Tipo de consulta ('normal' o 'emergencia')
            detalles (str): Detalles de la consulta
            
        Returns:
            str: JSON con resultado de la operación
        """
        try:
            # Verificar permisos (médicos y administradores pueden crear)
            if not self._verificar_permisos_medico_o_admin():
                return json.dumps({'exito': False, 'error': 'Sin permisos para crear consultas'})
            
            self._set_estado_actual("cargando")
            
            print(f"🔍 DEBUG - Parámetros recibidos:")
            print(f"   - paciente_id: {paciente_id} (tipo: {type(paciente_id)})")
            print(f"   - especialidad_id: {especialidad_id} (tipo: {type(especialidad_id)})")
            print(f"   - tipo_consulta: '{tipo_consulta}' (tipo: {type(tipo_consulta)})")
            print(f"   - detalles: '{detalles}' (tipo: {type(detalles)})")
            print(f"   - usuario_actual_id: {self._usuario_actual_id}")
            
            # Validar datos de entrada
            if not isinstance(paciente_id, int) or paciente_id <= 0:
                error_msg = f"ID de paciente inválido: {paciente_id}"
                print(f"❌ {error_msg}")
                self.operacionError.emit(error_msg)
                self._set_estado_actual("error")
                return json.dumps({'exito': False, 'error': error_msg})
            
            if not isinstance(especialidad_id, int) or especialidad_id <= 0:
                error_msg = f"Especialidad inválida: {especialidad_id}"
                print(f"❌ {error_msg}")
                self.operacionError.emit(error_msg)
                self._set_estado_actual("error")
                return json.dumps({'exito': False, 'error': error_msg})
            
            if not detalles or len(str(detalles).strip()) < 5:
                error_msg = "Los detalles son obligatorios (mínimo 5 caracteres)"
                print(f"❌ {error_msg}")
                self.operacionError.emit(error_msg)
                self._set_estado_actual("error")
                return json.dumps({'exito': False, 'error': error_msg})
            
            # Validar tipo de consulta
            tipo_consulta_clean = str(tipo_consulta).lower().strip()
            if tipo_consulta_clean not in ['normal', 'emergencia']:
                tipo_consulta_clean = 'normal'
            
            detalles_clean = str(detalles).strip()
            
            print(f"✅ Usuario {self._usuario_actual_id} ({self._usuario_actual_rol}) creando consulta:")
            print(f"   - Paciente ID: {paciente_id}")
            print(f"   - Especialidad ID: {especialidad_id}")
            print(f"   - Tipo: {tipo_consulta_clean}")
            print(f"   - Detalles: {detalles_clean[:50]}...")
            
            # LLAMADA CORREGIDA AL REPOSITORY - ORDEN Y PARÁMETROS EXACTOS
            nueva_consulta_id = self.repository.create_consultation(
                usuario_id=self._usuario_actual_id,           # 1er parámetro
                paciente_id=paciente_id,                      # 2do parámetro  
                especialidad_id=especialidad_id,              # 3er parámetro
                detalles=detalles_clean,                      # 4to parámetro
                tipo_consulta=tipo_consulta_clean.capitalize(), # 5to parámetro
                fecha=None                                    # 6to parámetro (opcional, usa datetime actual)
            )
            
            print(f"🔍 DEBUG - Repository devolvió: {nueva_consulta_id} (tipo: {type(nueva_consulta_id)})")
            
            if nueva_consulta_id and nueva_consulta_id > 0:
                # Obtener la consulta creada con detalles completos
                consulta_creada = self.repository.get_consultation_by_id_complete(nueva_consulta_id)
                
                if consulta_creada:
                    print(f"✅ Consulta {nueva_consulta_id} creada exitosamente")
                    
                    # Emitir señales de éxito
                    self.consultaCreada.emit(json.dumps(consulta_creada, default=str))
                    self.operacionExitosa.emit(f"Consulta {nueva_consulta_id} creada correctamente")
                    
                    # Refrescar datos
                    self._cargar_consultas_recientes()
                    
                    self._set_estado_actual("listo")
                    
                    return json.dumps({
                        'exito': True, 
                        'consulta_id': nueva_consulta_id,
                        'mensaje': 'Consulta creada correctamente',
                        'datos': consulta_creada
                    }, default=str)
                else:
                    error_msg = "Consulta creada pero no se pudo recuperar información"
                    print(f"⚠️ {error_msg}")
                    self.operacionError.emit(error_msg)
                    self._set_estado_actual("error")
                    return json.dumps({'exito': False, 'error': error_msg})
            else:
                error_msg = f"Error creando consulta - Repository devolvió: {nueva_consulta_id}"
                print(f"❌ {error_msg}")
                self.operacionError.emit(error_msg)
                self._set_estado_actual("error")
                return json.dumps({'exito': False, 'error': error_msg})
                
        except Exception as e:
            error_msg = f"Error crítico creando consulta: {str(e)}"
            print(f"❌ {error_msg}")
            import traceback
            traceback.print_exc()
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(str, result='QVariantMap')
    def buscar_paciente_por_cedula(self, cedula: str):
        """
        Busca un paciente específico por su cédula
        
        Args:
            cedula (str): Cédula del paciente
            
        Returns:
            Dict: Datos del paciente encontrado o diccionario vacío
        """
        try:
            if len(cedula.strip()) < 5:
                return {}
            
            print(f"🔍 Buscando paciente por cédula: {cedula}")
            
            # Buscar en el repository
            paciente = self.repository.search_patient_by_cedula_exact(cedula.strip())
            
            if paciente:
                print(f"👤 Paciente encontrado: {paciente.get('nombre_completo', 'N/A')}")
                
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
            self.operacionError.emit(error_msg)
            return {}
    
    @Slot(str, int, result='QVariantList')
    def buscar_pacientes(self, termino_busqueda: str, limite: int = 5):
        """
        Busca pacientes usando el nuevo sistema unificado
        Mantiene compatibilidad con código existente
        
        Args:
            termino_busqueda (str): Término a buscar (cédula o nombre)
            limite (int): Límite de resultados
            
        Returns:
            List[Dict]: Lista de pacientes encontrados
        """
        try:
            if not termino_busqueda or len(termino_busqueda.strip()) < 2:
                return []
            
            print(f"🔍 Búsqueda de pacientes (método actualizado): {termino_busqueda}")
            
            # Usar el nuevo método unificado internamente
            return self.buscar_paciente_unificado(termino_busqueda, limite)
            
        except Exception as e:
            error_msg = f"Error en búsqueda de pacientes: {str(e)}"
            print(f"❌ {error_msg}")
            self.operacionError.emit(error_msg)
            return []
    
    @Slot(str, str, str, str, result=int)
    def buscar_o_crear_paciente_inteligente(self, nombre: str, apellido_paterno: str, 
                                        apellido_materno: str = "", cedula: str = "") -> int:
        """
        ✅ MÉTODO CORREGIDO - Busca paciente por cédula o crea uno nuevo 
        PERMITE CÉDULA VACÍA y maneja mejor la búsqueda
        """
        try:
            if not self._verificar_autenticacion():
                return -1
            
            if not nombre or len(nombre.strip()) < 2:
                self.operacionError.emit("Nombre es obligatorio")
                return -1
            
            if not apellido_paterno or len(apellido_paterno.strip()) < 2:
                self.operacionError.emit("Apellido paterno es obligatorio")
                return -1
            
            nombre_clean = nombre.strip()
            apellido_p_clean = apellido_paterno.strip()
            apellido_m_clean = apellido_materno.strip()
            cedula_clean = cedula.strip() if cedula else ""
            
            print(f"🔄 Usuario {self._usuario_actual_id} gestionando paciente: {nombre_clean} {apellido_p_clean}")
            print(f"   - Apellido materno: '{apellido_m_clean}'")
            print(f"   - Cédula: '{cedula_clean}' ({'con cédula' if cedula_clean else 'sin cédula'})")
            
            # ✅ ESTRATEGIA MEJORADA: Usar método del repository que maneja mejor las coincidencias
            paciente_id = self.repository.buscar_o_crear_paciente_simple(
                nombre_clean, 
                apellido_p_clean, 
                apellido_m_clean, 
                cedula_clean  # Puede ser cadena vacía
            )
            
            if paciente_id > 0:
                print(f"✅ Paciente gestionado correctamente: ID {paciente_id}")
                self.operacionExitosa.emit(f"Paciente gestionado correctamente: ID {paciente_id}")
                return paciente_id
            else:
                error_msg = "Error gestionando paciente"
                print(f"❌ {error_msg}")
                self.operacionError.emit(error_msg)
                return -1
                
        except Exception as e:
            error_msg = f"Error gestionando paciente: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.operacionError.emit(error_msg)
            return -1
        
    @Slot(str, str, str, result='QVariantMap')
    def validar_paciente_duplicado(self, nombre: str, apellido_paterno: str, apellido_materno: str = "") -> Dict[str, Any]:
        """
        ✅ Valida si ya existe un paciente con ese nombre completo
        """
        try:
            if not nombre or not apellido_paterno:
                return {'existe': False}
            
            # ✅ Buscar usando el repository correcto
            pacientes = self.repository.buscar_paciente_por_nombre_completo(
                nombre.strip(),
                apellido_paterno.strip(),
                apellido_materno.strip() if apellido_materno else ""
            )
            
            if pacientes:
                # Si retorna lista, tomar el primero
                if isinstance(pacientes, list) and len(pacientes) > 0:
                    paciente = pacientes[0]
                else:
                    paciente = pacientes
                
                # ✅ Manejar cédula NULL correctamente
                cedula_display = paciente.get('Cedula', '')
                if cedula_display is None or str(cedula_display).upper() == 'NULL' or cedula_display == '':
                    cedula_display = "No proporcionado"
                
                return {
                    'existe': True,
                    'id': paciente['id'],
                    'nombre_completo': f"{paciente.get('Nombre', '')} {paciente.get('Apellido_Paterno', '')} {paciente.get('Apellido_Materno', '')}".strip(),
                    'cedula': cedula_display
                }
            
            return {'existe': False}
            
        except Exception as e:
            print(f"⚠️ Error validando duplicado: {e}")
            return {'existe': False}
    
    # Nuevos metodo para busqueda de pacientes
    @Slot(str, int, result='QVariantList')
    def buscar_paciente_unificado(self, termino_busqueda: str, limite: int = 5):
        """
        Slot unificado para búsqueda inteligente de pacientes - CORREGIDO para cédula NULL
        Detecta automáticamente si es cédula o nombre y busca en consecuencia
        
        Args:
            termino_busqueda (str): Término a buscar (cédula o nombre)
            limite (int): Máximo número de resultados
            
        Returns:
            List[Dict]: Lista de pacientes encontrados con información completa
        """
        try:
            if not termino_busqueda or len(termino_busqueda.strip()) < 2:
                return []
            
            print(f"🔍 Búsqueda unificada desde QML: '{termino_busqueda}' (límite: {limite})")
            
            # Llamar al repository con el nuevo método unificado
            resultados = self.repository.buscar_paciente_unificado(termino_busqueda.strip(), limite)
            
            # Procesar resultados para QML - ✅ CORREGIDO para cédula NULL
            pacientes_procesados = []
            for paciente in resultados:
                # ✅ MANEJAR CÉDULA NULL CORRECTAMENTE
                cedula_raw = paciente.get('Cedula')
                cedula_processed = ""
                
                if cedula_raw is not None and str(cedula_raw).strip() and str(cedula_raw).upper() != 'NULL':
                    cedula_processed = str(cedula_raw).strip()
                
                paciente_procesado = {
                    'id': paciente.get('id'),
                    'nombre': paciente.get('Nombre', ''),
                    'apellido_paterno': paciente.get('Apellido_Paterno', ''),
                    'apellido_materno': paciente.get('Apellido_Materno', ''),
                    'cedula': cedula_processed,  # ✅ CORREGIDO: maneja NULL correctamente
                    'nombre_completo': paciente.get('nombre_completo', ''),
                    'relevancia': paciente.get('relevancia', 999),
                    # Campos adicionales para mostrar en resultados
                    'texto_busqueda': termino_busqueda,
                    'tipo_coincidencia': self._determinar_tipo_coincidencia(paciente, termino_busqueda)
                }
                pacientes_procesados.append(paciente_procesado)
            
            print(f"✅ Encontrados {len(pacientes_procesados)} pacientes")
            return pacientes_procesados
            
        except Exception as e:
            error_msg = f"Error en búsqueda unificada: {str(e)}"
            print(f"❌ {error_msg}")
            self.operacionError.emit(error_msg)
            return []

    @Slot(str, result='QVariantMap')
    def analizar_nombre_completo(self, nombre_completo: str):
        """
        Analiza un nombre completo y lo separa en componentes
        
        Args:
            nombre_completo (str): Nombre completo a analizar
            
        Returns:
            Dict: Componentes del nombre (nombre, apellido_paterno, apellido_materno)
        """
        try:
            if not nombre_completo or len(nombre_completo.strip()) < 2:
                return {
                    'nombre': '',
                    'apellido_paterno': '',
                    'apellido_materno': '',
                    'valido': False
                }
            
            # Usar el método del repository para analizar
            componentes = self.repository._analizar_termino_nombre(nombre_completo.strip())
            
            # Agregar flag de validez
            componentes['valido'] = bool(componentes.get('nombre')) and bool(componentes.get('apellido_paterno'))
            
            print(f"📝 Nombre analizado: {nombre_completo} -> {componentes}")
            return componentes
            
        except Exception as e:
            error_msg = f"Error analizando nombre: {str(e)}"
            print(f"❌ {error_msg}")
            return {
                'nombre': '',
                'apellido_paterno': '',
                'apellido_materno': '',
                'valido': False,
                'error': error_msg
            }

    @Slot(str, result=str)
    def detectar_tipo_busqueda(self, termino: str):
        """
        Detecta el tipo de búsqueda según el término ingresado
        
        Args:
            termino (str): Término a analizar
            
        Returns:
            str: 'cedula', 'nombre', 'mixto' o 'invalido'
        """
        try:
            if not termino:
                return 'invalido'
            
            tipo = self.repository._detectar_tipo_busqueda(termino.strip())
            print(f"🎯 Tipo detectado para '{termino}': {tipo}")
            return tipo
            
        except Exception as e:
            print(f"❌ Error detectando tipo: {e}")
            return 'invalido'
    # ===============================
    # SLOTS PARA OPERACIONES CRUD
    # ===============================
    
    @Slot(int, 'QVariant', result=str)
    def actualizar_consulta(self, consulta_id: int, nuevos_datos):
        """Actualiza consulta existente - VERSIÓN LIMPIA SIN VALIDACIONES PROBLEMÁTICAS"""
        try:
            self._set_estado_actual("cargando")
            
            # Convertir datos
            if hasattr(nuevos_datos, 'toVariant'):
                datos = nuevos_datos.toVariant()
            else:
                datos = nuevos_datos
            
            print(f"🔧 DEBUG - Datos recibidos del frontend: {datos}")
            print(f"✏️ Usuario {self._usuario_actual_id} ({self._usuario_actual_rol}) actualizando consulta {consulta_id}")
            
            # Construir datos de actualización
            update_data = {}
            
            # Detalles
            if 'detalles' in datos and datos['detalles'] is not None:
                detalles_text = str(datos['detalles']).strip()
                if len(detalles_text) >= 5:
                    update_data['Detalles'] = detalles_text
                    print(f"📝 Detalles procesados: {detalles_text[:50]}...")
            
            # Tipo de consulta
            if 'tipo_consulta' in datos and datos['tipo_consulta']:
                tipo = str(datos['tipo_consulta']).lower().strip()
                if tipo in ['normal', 'emergencia']:
                    update_data['Tipo_Consulta'] = tipo.capitalize()
                    print(f"🏷️ Tipo consulta procesado: {tipo}")
            
            # Especialidad - SIN VALIDACIONES EXTRA
            if 'especialidad_id' in datos and datos['especialidad_id'] is not None:
                try:
                    especialidad_id = int(datos['especialidad_id'])
                    if especialidad_id > 0:
                        update_data['Id_Especialidad'] = especialidad_id
                        print(f"🏥 Especialidad procesada correctamente: ID {especialidad_id}")
                except (ValueError, TypeError) as e:
                    print(f"⚠️ Error convirtiendo especialidad_id: {e}")
            
            print(f"📝 Datos finales a actualizar: {update_data}")
            
            # Verificar que hay datos para actualizar
            if not update_data:
                return json.dumps({'exito': False, 'error': 'No hay datos válidos para actualizar'})
            
            # Actualizar en base de datos
            success = self.repository.update_consultation(
                consulta_id=consulta_id,
                detalles=update_data.get('Detalles'),
                tipo_consulta=update_data.get('Tipo_Consulta'),
                especialidad_id=update_data.get('Id_Especialidad'),
                fecha=update_data.get('Fecha')
            )
            
            if success:
                # Obtener consulta actualizada
                consulta_actualizada = self.repository.get_consultation_by_id_complete(consulta_id)
                
                if consulta_actualizada:
                    # Emitir signals
                    self.consultaActualizada.emit(json.dumps(consulta_actualizada, default=str))
                    self.operacionExitosa.emit(f"Consulta {consulta_id} actualizada correctamente")
                    
                    # Refrescar datos
                    self._cargar_consultas_recientes()
                    
                    self._set_estado_actual("listo")
                    
                    return json.dumps({'exito': True, 'datos': consulta_actualizada}, default=str)
                else:
                    error_msg = "Consulta actualizada pero no se pudo recuperar información"
                    self.operacionError.emit(error_msg)
                    self._set_estado_actual("error")
                    return json.dumps({'exito': False, 'error': error_msg})
            else:
                error_msg = "Error actualizando consulta en base de datos"
                self.operacionError.emit(error_msg)
                self._set_estado_actual("error")
                return json.dumps({'exito': False, 'error': error_msg})
                
        except Exception as e:
            error_msg = f"Error crítico actualizando consulta: {str(e)}"
            print(f"❌ {error_msg}")
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})
    
    
    @Slot(int, result=bool)
    def eliminar_consulta(self, consulta_id: int) -> bool:
        """Elimina consulta médica - ✅ SOLO ADMINISTRADORES"""
        try:
            # ✅ VERIFICAR PERMISOS DE ADMINISTRADOR
            puede_eliminar, razon = self._verificar_permisos_eliminacion(consulta_id)
            if not puede_eliminar:
                self.operacionError.emit(razon)
                return False
            
            self._set_estado_actual("cargando")
            
            print(f"🗑️ Admin {self._usuario_actual_id} eliminando consulta {consulta_id}")
            
            exito = self.repository.delete(consulta_id)
            
            if exito:
                # Emitir signals
                self.consultaEliminada.emit(consulta_id)
                self.operacionExitosa.emit(f"Consulta {consulta_id} eliminada correctamente")
                
                # Actualizar datos
                self._cargar_consultas_recientes()
                
                self._set_estado_actual("listo")
                return True
            else:
                self.operacionError.emit(f"No se pudo eliminar la consulta {consulta_id}")
                self._set_estado_actual("error")
                return False
                
        except Exception as e:
            error_msg = f"Error eliminando consulta: {str(e)}"
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return False
        
    @Slot(int, result='QVariantMap')
    def verificar_permisos_consulta(self, consulta_id: int):
        """Verifica permisos del usuario actual para una consulta específica"""
        try:
            puede_editar = self._usuario_actual_rol in ["Administrador", "Médico"]
            puede_eliminar, razon_eliminar = self._verificar_permisos_eliminacion(consulta_id)
            es_admin = self._usuario_actual_rol == "Administrador"
            es_medico = self._usuario_actual_rol == "Médico"
            
            # Obtener información adicional
            consulta = self.repository.get_consultation_by_id_complete(consulta_id)
            dias_antiguedad = 0
            
            if consulta:

                # Calcular antigüedad
                fecha_consulta = consulta.get('Fecha')
                if fecha_consulta:
                    try:
                        if isinstance(fecha_consulta, str):
                            fecha_obj = datetime.fromisoformat(fecha_consulta.replace('Z', ''))
                        elif isinstance(fecha_consulta, datetime):
                            fecha_obj = fecha_consulta
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
            print(f"⚠️ Error verificando permisos: {e}")
            return {
                'puede_eliminar': False,
                'razon_eliminar': f"Error: {str(e)}",
                'es_administrador': False,
                'es_medico': False,
                'es_propietario': False,
                'dias_antiguedad': 999,
                'limite_dias': 30
            }
        
    # ===============================
    # SLOTS PARA BÚSQUEDAS Y FILTROS - CORREGIDOS
    # ===============================
    
    @Slot(str, result=str)
    def buscar_consultas_avanzado(self, termino_busqueda: str) -> str:
        """Realiza búsqueda avanzada de consultas"""
        try:
            resultado = self.repository.search_consultations(termino_busqueda, limit=100)
            
            # Emitir signal con resultados
            self.resultadosBusqueda.emit(json.dumps(resultado, default=str))
            
            return json.dumps({
                'exito': True,
                'consultas': resultado,
                'total': len(resultado)
            }, default=str)
            
        except Exception as e:
            error_msg = f"Error en búsqueda: {str(e)}"
            self.operacionError.emit(error_msg)
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(str, int, result='QVariantList')
    def buscar_pacientes_por_nombre(self, nombre_completo: str, limite: int = 5):
        """Busca pacientes por nombre completo"""
        try:
            if len(nombre_completo.strip()) < 3:
                return []
            
            print(f"🔍 Buscando pacientes por nombre: {nombre_completo}")
            
            resultados = self.repository.search_patient_by_full_name(
                nombre_completo.strip(), limite
            )
            
            print(f"📋 Encontrados {len(resultados)} pacientes por nombre")
            return resultados
            
        except Exception as e:
            error_msg = f"Error buscando por nombre: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.operacionError.emit(error_msg)
            return []

    @Slot(int, result=str)
    def obtener_consultas_del_paciente(self, paciente_id: int) -> str:
        """Obtiene consultas de un paciente específico"""
        try:
            consultas = self.repository.get_consultations_by_patient(paciente_id)
            
            return json.dumps({
                'exito': True,
                'consultas': consultas,
                'total': len(consultas)
            }, default=str)
            
        except Exception as e:
            error_msg = f"Error obteniendo consultas del paciente: {str(e)}"
            self.operacionError.emit(error_msg)
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtener_consultas_del_doctor(self, medico_id: int) -> str:
        """Obtiene consultas atendidas por un doctor"""
        try:
            consultas = self.repository.get_consultations_by_doctor(medico_id)
            
            return json.dumps({
                'exito': True,
                'consultas': consultas,
                'total': len(consultas)
            }, default=str)
            
        except Exception as e:
            error_msg = f"Error obteniendo consultas del doctor: {str(e)}"
            self.operacionError.emit(error_msg)
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtener_consulta_completa(self, consulta_id: int) -> str:
        """Obtiene consulta con información completa"""
        try:
            consulta = self.repository.get_consultation_by_id_complete(consulta_id)
            
            if consulta:
                return json.dumps({'exito': True, 'consulta': consulta}, default=str)
            else:
                return json.dumps({'exito': False, 'error': 'Consulta no encontrada'})
                
        except Exception as e:
            error_msg = f"Error obteniendo consulta: {str(e)}"
            self.operacionError.emit(error_msg)
            return json.dumps({'exito': False, 'error': error_msg})
    
    # ===============================
    # SLOTS PARA ESTADÍSTICAS Y REPORTES
    # ===============================
    
    @Slot(result=str)
    def obtener_dashboard(self) -> str:
        """Obtiene datos para dashboard de consultas"""
        try:
            self._set_estado_actual("cargando")
            
            dashboard = self.repository.get_consultation_statistics()
            
            # Agregar datos adicionales
            dashboard['consultas_hoy'] = len(self.repository.get_today_consultations())
            dashboard['consultas_mes'] = len(self.repository.get_consultations_this_month())
            dashboard['pacientes_frecuentes'] = self.repository.get_most_frequent_patients(limit=5)
            
            # Actualizar datos internos
            self._dashboardData = dashboard
            
            # Emitir signal
            self.dashboardActualizado.emit(json.dumps(dashboard, default=str))
            
            self._set_estado_actual("listo")
            return json.dumps({'exito': True, 'dashboard': dashboard}, default=str)
            
        except Exception as e:
            error_msg = f"Error generando dashboard: {str(e)}"
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(result=str)
    def obtener_estadisticas(self) -> str:
        """Obtiene estadísticas completas de consultas"""
        try:
            estadisticas = self.repository.get_consultation_statistics()
            
            # Actualizar datos internos
            self._estadisticasData = estadisticas
            
            # Emitir signal
            self.estadisticasCalculadas.emit(json.dumps(estadisticas, default=str))
            
            return json.dumps({'exito': True, 'estadisticas': estadisticas}, default=str)
            
        except Exception as e:
            error_msg = f"Error generando estadísticas: {str(e)}"
            self.operacionError.emit(error_msg)
            return json.dumps({'exito': False, 'error': error_msg})
    
    @Slot(int, result=str)
    def obtener_resumen_paciente(self, paciente_id: int) -> str:
        """Obtiene resumen de consultas de un paciente"""
        try:
            consultas = self.repository.get_consultations_by_patient(paciente_id)
            
            resumen = {
                'total_consultas': len(consultas),
                'consultas_recientes': consultas[:5] if consultas else [],
                'especialidades_visitadas': list(set([c['especialidad_nombre'] for c in consultas if c.get('especialidad_nombre')])),
                'ultima_consulta': consultas[0]['Fecha'] if consultas else None
            }
            
            return json.dumps({'exito': True, 'resumen': resumen}, default=str)
            
        except Exception as e:
            error_msg = f"Error obteniendo resumen: {str(e)}"
            self.operacionError.emit(error_msg)
            return json.dumps({'exito': False, 'error': error_msg})
    
    # ===============================
    # SLOTS PARA GESTIÓN DE DATOS
    # ===============================
    
    @Slot()
    def cargar_consultas(self):
        """Carga todas las consultas médicas"""
        try:
            self._set_estado_actual("cargando")
            self._cargar_consultas_recientes()
            self._set_estado_actual("listo")
        except Exception as e:
            self.operacionError.emit(f"Error cargando consultas: {str(e)}")
            self._set_estado_actual("error")
    
    @Slot()
    def cargar_especialidades(self):
        """Carga especialidades disponibles"""
        try:
            especialidades = self.medico_repo.get_all_specialty_services()
            self._especialidadesData = []
            
            for esp in especialidades or []:
                self._especialidadesData.append({
                    'id': esp['id'],
                    'text': esp['Nombre'],
                    'precio_normal': float(esp.get('Precio_Normal', 0)),
                    'precio_emergencia': float(esp.get('Precio_Emergencia', 0)),
                    'doctor_nombre': esp.get('doctor_completo', ''),
                    'doctor_especialidad': esp.get('doctor_especialidad', ''),
                    'data': esp
                })
            
            self.especialidadesChanged.emit()
            print(f"🏥 Especialidades cargadas: {len(self._especialidadesData)}")
            
        except Exception as e:
            error_msg = f"Error cargando especialidades: {str(e)}"
            print(f"⚠️ {error_msg}")
            self.operacionError.emit(error_msg)
            
    @Slot()
    def cargar_doctores(self):
        """Carga doctores disponibles"""
        try:
            doctores = self.medico_repo.get_all()
            self._medicosData = []
            
            for d in doctores or []:
                self._medicosData.append({
                    'id': d['id'],
                    'text': f"{d['Nombre']} {d['Apellido_Paterno']} {d['Apellido_Materno']}",
                    'especialidad': d['Especialidad'],
                    'matricula': d['Matricula'],
                    'data': d
                })
            
            self.medicosDisponiblesChanged.emit()
            
        except Exception as e:
            self.operacionError.emit(f"Error cargando doctores: {str(e)}")
    
    @Slot()
    def refresh_consultas(self):
        """Refresca las consultas recientes"""
        self._cargar_consultas_recientes()
    
    @Slot()
    def refresh_especialidades(self):
        """Refresca especialidades"""
        self.cargar_especialidades()
    
    @Slot()
    def refresh_doctores(self):
        """Refresca lista de doctores"""
        self.cargar_doctores()
    
    @Slot()
    def refrescar_datos(self):
        """
        Recarga todos los datos: consultas, especialidades y médicos
        """
        try:
            if not self._verificar_autenticacion():
                return
            
            print("🔄 Refrescando datos del módulo de consultas...")
            
            self.estadoCambiado.emit("cargando")
            
            # Cargar consultas con médicos
            self.obtener_consultas_con_medicos()
            
            # Cargar especialidades con médicos disponibles
            self.obtener_especialidades_con_medicos()
            
            self.estadoCambiado.emit("listo")
            self.operacionExitosa.emit("Datos actualizados correctamente")
            
            print("✅ Datos refrescados exitosamente")
            
        except Exception as e:
            print(f"❌ Error refrescando datos: {e}")
            self.estadoCambiado.emit("error")
            self.operacionError.emit(f"Error actualizando datos: {str(e)}")
    
    # ===============================
    # SLOTS PARA CONSULTAS ESPECÍFICAS
    # ===============================
    
    @Slot(result=str)
    def obtener_consultas_hoy(self) -> str:
        """Obtiene consultas del día actual"""
        try:
            consultas = self.repository.get_today_consultations()
            return json.dumps({
                'exito': True,
                'consultas': consultas,
                'total': len(consultas)
            }, default=str)
        except Exception as e:
            return json.dumps({'exito': False, 'error': str(e)})
    
    @Slot(result=str)
    def obtener_especialidades_disponibles(self) -> str:
        """Obtiene especialidades disponibles"""
        try:
            return json.dumps({
                'exito': True,
                'especialidades': self._especialidadesData
            }, default=str)
        except Exception as e:
            return json.dumps({'exito': False, 'error': str(e)})
    
    @Slot(result=str)
    def obtener_doctores_activos(self) -> str:
        """Obtiene doctores activos"""
        try:
            return json.dumps({
                'exito': True,
                'doctores': self._medicosData
            }, default=str)
        except Exception as e:
            return json.dumps({'exito': False, 'error': str(e)})
    
    @Slot()
    def limpiar_cache_consultas(self):
        """Limpia el cache de consultas para forzar recarga"""
        try:
            self.repository.invalidate_consultation_caches()
        except Exception as e:
            print(f"⚠️ Error limpiando cache: {e}")
    
    @Slot(int, int, 'QVariant', result='QVariant')
    def obtener_consultas_paginadas(self, page: int, limit: int = 5, filters=None):
        """Obtiene página específica de consultas - CORREGIDO CON FORMATEO DE FECHAS"""
        try:
            filtros_dict = filters.toVariant() if hasattr(filters, 'toVariant') else filters or {}
            resultado = self.repository.get_consultas_paginadas(page, limit, filtros_dict)
            
            # ✅ PROCESAR FECHAS EN LAS CONSULTAS PAGINADAS
            if 'consultas' in resultado and resultado['consultas']:
                for consulta in resultado['consultas']:
                    # Formatear fecha usando el mismo método que _cargar_consultas_recientes
                    fecha_raw = consulta.get('Fecha') or consulta.get('fecha')
                    fecha_formateada = self._formatear_fecha_python(fecha_raw)
                    consulta['fecha'] = fecha_formateada
                    
                    # Asegurar que otros campos estén en el formato correcto
                    consulta['id'] = str(consulta.get('id', 'N/A'))
                    consulta['paciente_completo'] = consulta.get('paciente_completo') or 'Sin nombre'
                    consulta['paciente_cedula'] = consulta.get('paciente_cedula') or 'Sin cédula'
                    consulta['Detalles'] = consulta.get('Detalles') or 'Sin detalles'
                    consulta['especialidad_doctor'] = (
                        consulta.get('especialidad_doctor') or 
                        consulta.get('especialidad_doctor_completo') or 
                        f"{consulta.get('especialidad_nombre', 'Sin especialidad')} - (Sin asignar)"
                    )
                    consulta['tipo_consulta'] = consulta.get('tipo_consulta') or 'Normal'
                    consulta['precio'] = float(consulta.get('precio') or 0)
            
            return resultado
            
        except Exception as e:
            self.operacionError.emit(f"Error paginación: {str(e)}")
            return {'consultas': [], 'total': 0, 'page': 0, 'total_pages': 0}

    # ===============================
    # MÉTODOS INTERNOS - CORREGIDOS CON NOMBRES REALES
    # ===============================
    def _formatear_fecha_python(self, fecha) -> str:
        """Formatea fecha en Python manejando QVariant datetime - CORREGIDO"""
        if not fecha:
            return "Sin fecha"
        
        try:
            # ✅ SOLUCIÓN: Manejar QVariant sin importación problemática
            # Si es QVariant, extraer el valor usando .value() si existe el método
            if hasattr(fecha, 'value') and callable(getattr(fecha, 'value')):
                fecha = fecha.value()
            
            # Si es datetime, formatear directamente
            if isinstance(fecha, datetime):
                return fecha.strftime('%d/%m/%Y')
            
            # Si es string, intentar parsearlo
            if isinstance(fecha, str):
                if fecha == "Sin fecha":
                    return fecha
                # Intentar formato ISO
                try:
                    dt = datetime.fromisoformat(fecha.replace('Z', ''))
                    return dt.strftime('%d/%m/%Y')
                except:
                    pass
                # Si ya está formateado DD/MM/YYYY
                if '/' in fecha and len(fecha) == 10:
                    return fecha
            return "Sin fecha"
            
        except Exception as e:
            print(f"❌ Error formateando fecha: {e} - Tipo: {type(fecha)} - Valor: {fecha}")
            return "Sin fecha"
        
    def _cargar_consultas_recientes(self):
        """Actualiza lista interna de consultas"""
        try:
            consultas_raw = self.repository.get_all_with_details()
            
            self._consultasData = []
            for consulta in consultas_raw:
                fecha_raw = consulta.get('Fecha') or consulta.get('fecha_original')
                fecha_formateada = self._formatear_fecha_python(fecha_raw)
                
                consulta_procesada = {
                    'id': str(consulta.get('id', 'N/A')),
                    'paciente_completo': consulta.get('paciente_completo') or 'Sin nombre',
                    'paciente_cedula': consulta.get('paciente_cedula') or 'Sin cédula',
                    'Detalles': consulta.get('Detalles') or 'Sin detalles',
                    'especialidad_doctor': consulta.get('especialidad_doctor') or 'Sin especialidad/doctor',
                    'tipo_consulta': consulta.get('tipo_consulta') or 'Normal',
                    'precio': float(consulta.get('precio') or 0),
                    'fecha': fecha_formateada
                }
                
                self._consultasData.append(consulta_procesada)
            
            self.consultasRecientesChanged.emit()
            print(f"📋 Consultas cargadas: {len(self._consultasData)}")
            
        except Exception as e:
            error_msg = f"Error actualizando consultas: {str(e)}"
            print(f"⚠️ {error_msg}")
            self._consultasData = []
            
    def _formatear_fecha_simple(self, fecha) -> str:
        """Formatea fecha de manera simple y segura"""
        if not fecha:
            return "Sin fecha"
        
        try:
            if isinstance(fecha, str):
                fecha_obj = datetime.fromisoformat(fecha.replace('Z', '+00:00'))
            elif isinstance(fecha, datetime):
                fecha_obj = fecha
            else:
                return "Fecha inválida"
            
            return fecha_obj.strftime('%d/%m/%Y')
        except Exception as e:
            print(f"Error formateando fecha: {e}")
            return "Fecha inválida"

    def _cargar_estadisticas_dashboard(self):
        """Carga estadísticas para el dashboard"""
        try:
            self._dashboardData = self.repository.get_consultation_statistics()
            self.dashboardActualizado.emit(json.dumps(self._dashboardData, default=str))
            print("📊 Estadísticas de consultas cargadas")
        except Exception as e:
            print(f"Error cargando estadísticas dashboard: {e}")
            self._dashboardData = {}
    
    def _setupAutoRefresh(self):
        """Configura actualización automática de datos"""
        self._autoRefreshTimer = QTimer(self)
        self._autoRefreshTimer.timeout.connect(self.refrescar_datos)
        # Comentado por defecto - se puede activar si es necesario
        # self._autoRefreshTimer.start(self._autoRefreshInterval)
    
    def _verificar_permisos_eliminacion(self, consulta_id: int) -> tuple[bool, str]:
        """Permisos de eliminación - ADMINS sin límite, MÉDICOS máximo 30 días"""
        if not self._verificar_autenticacion():
            return False, "Usuario no autenticado"
        
        if self._usuario_actual_rol == "Administrador":
            return True, "Administrador: Sin restricciones"
        
        if self._usuario_actual_rol == "Médico":
            consulta = self.repository.get_consultation_by_id_complete(consulta_id)
            if not consulta:
                return False, "Consulta no encontrada"
            
            fecha_consulta = consulta.get('Fecha')
            if not self._validar_fecha_eliminacion(fecha_consulta, dias_limite=30):
                return False, "Solo puede eliminar consultas de máximo 30 días"
            
            return True, "Médico: Puede eliminar (consulta reciente)"
        
        return False, "Sin permisos para eliminar consultas"

    @Slot(int)
    def setAutoRefreshInterval(self, intervalMs: int):
        """Configura intervalo de actualización automática"""
        if intervalMs > 0:
            self._autoRefreshInterval = intervalMs
            if hasattr(self, '_autoRefreshTimer'):
                self._autoRefreshTimer.start(intervalMs)
        else:
            if hasattr(self, '_autoRefreshTimer'):
                self._autoRefreshTimer.stop()
    
    @Slot(str)
    def _manejar_actualizacion_global(self, mensaje: str = ""):
        """
        Maneja actualizaciones globales del sistema
        Se ejecuta cuando hay cambios que afectan a consultas
        """
        try:
            print(f"🌐 Actualización global en ConsultaModel: {mensaje}")
            
            # Si el mensaje contiene "trabajador", actualizar trabajadores
            if "trabajador" in mensaje.lower():
                self._actualizar_trabajadores_desde_signal(mensaje)
            
            # Si el mensaje contiene "especialidad", actualizar especialidades
            if "especialidad" in mensaje.lower() or "consulta" in mensaje.lower():
                self._actualizar_especialidades_desde_signal(mensaje)
                
        except Exception as e:
            print(f"⚠️ Error en actualización global: {e}")

    def cleanup(self):
        """Limpieza completa de ConsultaModel"""
        try:
            print("🧹 Iniciando limpieza completa de ConsultaModel...")
            
            if hasattr(self, '_autoRefreshTimer'):
                try:
                    if self._autoRefreshTimer.isActive():
                        self._autoRefreshTimer.stop()
                    self._autoRefreshTimer.deleteLater()
                except Exception as e:
                    print(f"⚠️ Error deteniendo auto-refresh timer: {e}")
            
            # Limpiar datos
            self._consultasData = []
            self._especialidadesData = []
            self._medicosData = []
            self._dashboardData = {}
            self._estadisticasData = {}
            
            # ✅ RESETEAR USUARIO Y ROL
            self._usuario_actual_id = 0
            self._usuario_actual_rol = ""
            
            print("✅ Limpieza completa de ConsultaModel finalizada")
            
        except Exception as e:
            print(f"❌ Error crítico durante cleanup de ConsultaModel: {e}")

    def emergency_disconnect(self):
        """Desconexión de emergencia para ConsultaModel"""
        try:
            print("🚨 ConsultaModel: Iniciando desconexión de emergencia...")
            
            if hasattr(self, '_autoRefreshTimer') and self._autoRefreshTimer.isActive():
                self._autoRefreshTimer.stop()
            
            self._estadoActual = "shutdown"
            self._is_initializing = False
            self._usuario_actual_id = 0
            self._usuario_actual_rol = ""  # ✅ RESETEAR ROL
            
            self.cleanup()
            
            print("✅ ConsultaModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión ConsultaModel: {e}")

    def buscar_paciente_por_nombre_inteligente(self, nombre_completo: str):
        """
        ✅ MÉTODO AUXILIAR PARA CONSULTA_MODEL.PY
        
        Busca paciente por nombre con la nueva lógica mejorada
        """
        try:
            if not nombre_completo or len(nombre_completo.strip()) < 3:
                return None
            
            print(f"🔍 Búsqueda inteligente por nombre: '{nombre_completo}'")
            
            # Usar el método mejorado
            pacientes = self.repository.search_patient_by_full_name(nombre_completo, limite=5)
            
            if pacientes:
                # Ordenar por relevancia y seleccionar el mejor
                pacientes_ordenados = sorted(pacientes, key=lambda x: x.get('relevancia', 999))
                mejor_paciente = pacientes_ordenados[0]
                
                print(f"✅ Mejor paciente encontrado: {mejor_paciente['nombre_completo']} (ID: {mejor_paciente['id']})")
                return mejor_paciente
            
            return None
            
        except Exception as e:
            print(f"❌ Error en búsqueda inteligente: {e}")
            return None
    # ===============================
    # FUNCIONES LEGACY RENOMBRADAS - MODIFICAR EXISTENTES
    # ===============================

    @Slot(str, result='QVariantMap')
    def _buscar_paciente_por_cedula_legacy(self, cedula: str):
        """
        LEGACY: Busca paciente por cédula exacta
        Usar buscar_paciente_unificado() en su lugar
        """
        try:
            if len(cedula.strip()) < 5:
                return {}
            
            print(f"🔍 LEGACY - Búsqueda por cédula: {cedula}")
            
            paciente = self.repository.search_patient_by_cedula_exact(cedula.strip())
            
            if paciente:
                print(f"👤 LEGACY - Paciente encontrado: {paciente.get('nombre_completo', 'N/A')}")
                self.pacienteEncontradoPorCedula.emit(paciente)
                return paciente
            else:
                print(f"⚠️ LEGACY - No se encontró paciente con cédula: {cedula}")
                self.pacienteNoEncontrado.emit(cedula)
                return {}
                
        except Exception as e:
            error_msg = f"Error buscando paciente por cédula: {str(e)}"
            print(f"⚠️ LEGACY - {error_msg}")
            self.operacionError.emit(error_msg)
            return {}

    @Slot(str, int, result='QVariantList')
    def _buscar_pacientes_por_nombre_legacy(self, nombre_completo: str, limite: int = 5):
        """
        LEGACY: Busca pacientes por nombre completo
        Usar buscar_paciente_unificado() en su lugar
        """
        try:
            if len(nombre_completo.strip()) < 3:
                return []
            
            print(f"🔍 LEGACY - Búsqueda por nombre: {nombre_completo}")
            
            resultados = self.repository.search_patient_by_full_name(nombre_completo.strip(), limite)
            
            print(f"📋 LEGACY - Encontrados {len(resultados)} pacientes por nombre")
            return resultados
            
        except Exception as e:
            error_msg = f"Error en búsqueda por nombre: {str(e)}"
            print(f"⚠️ LEGACY - {error_msg}")
            self.operacionError.emit(error_msg)
            return []
        
    # ===============================
    # MÉTODOS AUXILIARES PRIVADOS - AGREGAR AL FINAL DE LA CLASE
    # ===============================

    def _determinar_tipo_coincidencia(self, paciente: Dict, termino_busqueda: str) -> str:
        """
        ✅ MEJORADO - Determina cómo coincidió el paciente con la búsqueda
        Maneja correctamente cédulas NULL
        
        Args:
            paciente: Datos del paciente encontrado
            termino_busqueda: Término que se buscó
            
        Returns:
            str: Tipo de coincidencia ('cedula_exacta', 'cedula_parcial', 'nombre_completo', 'nombre_parcial', 'sin_cedula')
        """
        try:
            termino_lower = termino_busqueda.lower().strip()
            cedula_raw = paciente.get('Cedula')
            nombre_completo = paciente.get('nombre_completo', '').lower()
            
            # ✅ MANEJAR CÉDULA NULL/VACÍA
            cedula = ""
            if cedula_raw is not None and str(cedula_raw).strip() and str(cedula_raw).upper() != 'NULL':
                cedula = str(cedula_raw).strip()
            
            # Verificar coincidencia por cédula si existe
            if cedula and termino_busqueda.replace(' ', '').isdigit():
                cedula_numeros = ''.join(c for c in termino_busqueda if c.isdigit())
                if cedula == cedula_numeros:
                    return 'cedula_exacta'
                elif cedula_numeros in cedula:
                    return 'cedula_parcial'
            
            # Si el paciente no tiene cédula pero se buscó por números
            if not cedula and termino_busqueda.replace(' ', '').isdigit():
                return 'sin_cedula'
            
            # Verificar coincidencia por nombre
            if termino_lower in nombre_completo:
                if termino_lower == nombre_completo:
                    return 'nombre_completo'
                else:
                    return 'nombre_parcial'
            
            return 'otra'
            
        except Exception as e:
            print(f"⚠️ Error determinando tipo de coincidencia: {e}")
            return 'desconocida'

    def _validar_datos_paciente_unificado(self, datos_paciente: Dict) -> bool:
        """
        Valida que los datos del paciente estén completos para crear/actualizar
        
        Args:
            datos_paciente: Diccionario con datos del paciente
            
        Returns:
            bool: True si los datos son válidos
        """
        try:
            # Validaciones básicas
            if not datos_paciente.get('nombre') or len(datos_paciente['nombre'].strip()) < 2:
                return False
            
            if not datos_paciente.get('apellido_paterno') or len(datos_paciente['apellido_paterno'].strip()) < 2:
                return False
            
            # Cédula es opcional pero si está presente debe ser válida
            cedula = datos_paciente.get('cedula', '').strip()
            if cedula and not self.repository._es_cedula_valida(cedula):
                return False
            
            return True
            
        except Exception as e:
            print(f"❌ Error validando datos del paciente: {e}")
            return False
        
    def _es_mismo_paciente(self, paciente: Dict, nombre: str, apellido_p: str, apellido_m: str, cedula: str) -> bool:
        """
        Determina si un paciente encontrado es el mismo que se está buscando/creando
        
        Args:
            paciente: Paciente encontrado en BD
            nombre, apellido_p, apellido_m, cedula: Datos a comparar
            
        Returns:
            bool: True si es el mismo paciente
        """
        try:
            # Comparación por cédula (más confiable)
            if cedula and cedula.strip() and paciente.get('Cedula'):
                cedula_limpia = ''.join(c for c in cedula if c.isdigit())
                cedula_bd = ''.join(c for c in str(paciente.get('Cedula', '')) if c.isdigit())
                if cedula_limpia and cedula_bd and cedula_limpia == cedula_bd:
                    return True
            
            # Comparación por nombres (normalizada)
            def normalizar(texto):
                if not texto:
                    return ""
                return texto.lower().strip()
            
            nombre_norm = normalizar(nombre)
            apellido_p_norm = normalizar(apellido_p)
            apellido_m_norm = normalizar(apellido_m)
            
            nombre_bd_norm = normalizar(paciente.get('Nombre', ''))
            apellido_p_bd_norm = normalizar(paciente.get('Apellido_Paterno', ''))
            apellido_m_bd_norm = normalizar(paciente.get('Apellido_Materno', ''))
            
            # Coincidencia exacta de nombre y apellido paterno (mínimo)
            if nombre_norm == nombre_bd_norm and apellido_p_norm == apellido_p_bd_norm:
                # Si ambos tienen apellido materno, deben coincidir
                if apellido_m_norm and apellido_m_bd_norm:
                    return apellido_m_norm == apellido_m_bd_norm
                # Si solo uno tiene apellido materno, es aceptable
                return True
            
            return False
            
        except Exception as e:
            print(f"⚠️ Error comparando pacientes: {e}")
            return False
        
    @Slot(str)
    def _actualizar_trabajadores_desde_signal(self, mensaje: str = ""):
        """
        ✅ NUEVO: Responde a cambios en trabajadores desde señales globales
        Se ejecuta cuando se crea/actualiza/elimina un trabajador
        """
        try:
            print(f"📢 Signal recibida en ConsultaModel: {mensaje}")
            
            # Recargar lista de trabajadores (si tienes un método para esto)
            # Si el modelo tiene una property de trabajadores, recárgala aquí
            
            # Emitir señal para que QML actualice combos
            self.medicosDisponiblesChanged.emit()
            
            print("✅ Trabajadores actualizados en ConsultaModel")
            
        except Exception as e:
            print(f"❌ Error actualizando trabajadores desde signal: {e}")

    @Slot(str)
    def _actualizar_especialidades_desde_signal(self, mensaje: str = ""):
        """
        ✅ YA EXISTE, pero asegurar que está implementado
        Responde a cambios en especialidades desde señales globales
        """
        try:
            print(f"📢 Signal de especialidades recibida: {mensaje}")
            
            # Recargar especialidades
            if hasattr(self, '_cargar_especialidades'):
                self._cargar_especialidades()
            
            # Emitir señal para QML
            self.especialidadesChanged.emit()
            
            print("✅ Especialidades actualizadas en ConsultaModel")
            
        except Exception as e:
            print(f"❌ Error actualizando especialidades: {e}")

    def _cargar_doctores(self):
        """
        Carga la lista de médicos disponibles desde el repositorio
        ACTUALIZADO: Ahora usa MedicoRepository que consulta Trabajadores
        """
        try:
            # Obtener médicos desde el repository (usa TrabajadorRepository internamente)
            medicos_raw = self.medico_repo.get_active()
            
            # Transformar a formato QML-friendly
            self._medicosData = [
                {
                    'id': medico['id'],
                    'nombre_completo': f"{medico['Nombre']} {medico['Apellido_Paterno']} {medico.get('Apellido_Materno', '')}".strip(),
                    'especialidad': medico.get('especialidad_descriptiva', ''),
                    'matricula': medico.get('Matricula', ''),
                    'especialidades_asignadas': medico.get('especialidades_nombres', ''),
                    'total_especialidades': medico.get('total_especialidades', 0)
                }
                for medico in medicos_raw
            ]
            
            print(f"✅ {len(self._medicosData)} médicos cargados")
            
        except Exception as e:
            print(f"❌ Error cargando médicos: {e}")
            import traceback
            traceback.print_exc()
            self._medicosData = []

    def _cargar_especialidades(self):
        """
        Carga la lista de especialidades disponibles desde el repositorio
        ACTUALIZADO: Usa método actualizado de ConsultaRepository
        """
        try:
            # Obtener especialidades desde el repository
            especialidades_raw = self.repository.get_especialidades()
            
            # Transformar a formato QML-friendly
            self._especialidadesData = [
                {
                    'id': esp['id'],
                    'nombre': esp['Nombre'],
                    'precio_normal': float(esp.get('Precio_Normal', 0)),
                    'precio_emergencia': float(esp.get('Precio_Emergencia', 0)),
                    'medicos_disponibles': esp.get('medicos_disponibles', 0),
                    'detalles': esp.get('Detalles', '')
                }
                for esp in especialidades_raw
            ]
            
            print(f"✅ {len(self._especialidadesData)} especialidades cargadas")
            
        except Exception as e:
            print(f"❌ Error cargando especialidades: {e}")
            import traceback
            traceback.print_exc()
            self._especialidadesData = []

    # ===============================
    # NUEVOS MÉTODOS PARA COMBOBOX DE MÉDICOS
    # ===============================
    
    @Slot(int, result='QVariantList')
    def obtener_medicos_por_especialidad(self, especialidad_id: int):
        """
        Obtiene médicos disponibles para una especialidad específica
        Para poblar el ComboBox de médicos después de seleccionar especialidad
        
        Args:
            especialidad_id: ID de la especialidad seleccionada
            
        Returns:
            Lista de médicos en formato QVariantList para QML
        """
        try:
            if especialidad_id <= 0:
                print(f"⚠️ ID de especialidad inválido: {especialidad_id}")
                return []
            
            # Obtener médicos desde el repository
            medicos = self.repository.get_medicos_por_especialidad(especialidad_id)
            
            print(f"👨‍⚕️ Médicos encontrados para especialidad {especialidad_id}: {len(medicos)}")
            
            # Convertir a formato QML amigable
            medicos_qml = []
            for medico in medicos:
                medico_data = {
                    'trabajador_id': medico['trabajador_id'],
                    'nombre_completo': medico['medico_nombre_completo'],
                    'display_text': medico['medico_display'],
                    'es_principal': medico['Es_Principal'] == 1,
                    'matricula': medico.get('Matricula', ''),
                    'estado': medico.get('Estado', 'Activo')
                }
                medicos_qml.append(medico_data)
            
            # Si solo hay 1 médico, incluir flag para auto-selección
            if len(medicos_qml) == 1:
                medicos_qml[0]['auto_seleccionar'] = True
                print(f"   ℹ️ Solo 1 médico disponible - Se auto-seleccionará: {medicos_qml[0]['display_text']}")
            
            self.medicosEspecialidadChanged.emit()
            
            return medicos_qml
            
        except Exception as e:
            print(f"❌ Error obteniendo médicos por especialidad: {e}")
            self.operacionError.emit(f"Error cargando médicos: {str(e)}")
            return []
    
    @Slot(result='QVariantList')
    def obtener_especialidades_con_medicos(self):
        """
        Obtiene especialidades que tienen médicos activos disponibles
        Para poblar el ComboBox de especialidades (solo las que tienen médicos)
        
        Returns:
            Lista de especialidades en formato QVariantList para QML
        """
        try:
            # Obtener especialidades desde el repository
            especialidades = self.repository.get_especialidades_con_medicos()
            
            print(f"🏥 Especialidades con médicos disponibles: {len(especialidades)}")
            
            # Convertir a formato QML amigable
            especialidades_qml = []
            for esp in especialidades:
                esp_data = {
                    'especialidad_id': esp['especialidad_id'],
                    'nombre': esp['especialidad_nombre'],
                    'display_text': esp['especialidad_display'],
                    'precio_normal': float(esp['Precio_Normal']),
                    'precio_emergencia': float(esp['Precio_Emergencia']),
                    'cantidad_medicos': esp['cantidad_medicos'],
                    'medico_unico_id': esp.get('medico_unico_id'),  # Para auto-selección
                    'medico_unico_nombre': esp.get('medico_unico_nombre', '')
                }
                especialidades_qml.append(esp_data)
            
            self.especialidadesFiltradaChanged.emit()
            
            return especialidades_qml
            
        except Exception as e:
            print(f"❌ Error obteniendo especialidades con médicos: {e}")
            self.operacionError.emit(f"Error cargando especialidades: {str(e)}")
            return []
    
    @Slot(int, int, int, int, str, str, result=bool)
    def crear_consulta_completa(self, usuario_id: int, paciente_id: int, 
                               especialidad_id: int, trabajador_id: int,
                               detalles: str, tipo_consulta: str):
        """
        Crea una nueva consulta con médico asignado
        
        Args:
            usuario_id: ID del usuario que registra
            paciente_id: ID del paciente
            especialidad_id: ID de la especialidad
            trabajador_id: ID del médico que atiende (NUEVO)
            detalles: Observaciones o diagnóstico
            tipo_consulta: "Normal" o "Emergencia"
            
        Returns:
            True si se creó exitosamente, False en caso contrario
        """
        try:
            # Validaciones básicas
            if usuario_id <= 0:
                self.operacionError.emit("Usuario no válido")
                return False
            
            if paciente_id <= 0:
                self.operacionError.emit("Paciente no válido")
                return False
            
            if especialidad_id <= 0:
                self.operacionError.emit("Especialidad no válida")
                return False
            
            if trabajador_id <= 0:
                self.operacionError.emit("Debe seleccionar un médico")
                return False
            
            if not detalles or len(detalles.strip()) < 5:
                self.operacionError.emit("Los detalles deben tener al menos 5 caracteres")
                return False
            
            # Crear la consulta usando el nuevo método del repository
            consulta_id = self.repository.create_consultation_completa(
                usuario_id=usuario_id,
                paciente_id=paciente_id,
                especialidad_id=especialidad_id,
                trabajador_id=trabajador_id,
                detalles=detalles.strip(),
                tipo_consulta=tipo_consulta
            )
            
            if consulta_id:
                print(f"✅ Consulta creada exitosamente: ID {consulta_id}")
                print(f"   - Paciente: {paciente_id}")
                print(f"   - Especialidad: {especialidad_id}")
                print(f"   - Médico: {trabajador_id}")
                print(f"   - Tipo: {tipo_consulta}")
                
                self.operacionExitosa.emit("Consulta médica creada exitosamente")
                
                # Recargar datos
                self.refrescar_datos()
                
                return True
            else:
                self.operacionError.emit("Error al crear la consulta")
                return False
                
        except ClinicaBaseException as e:
            print(f"❌ Error validación creando consulta: {e}")
            self.operacionError.emit(str(e))
            return False
        except Exception as e:
            print(f"❌ Error inesperado creando consulta: {e}")
            self.operacionError.emit(f"Error inesperado: {str(e)}")
            return False
    
    @Slot(int, result='QVariantMap')
    def obtener_info_medico(self, trabajador_id: int):
        """
        Obtiene información detallada de un médico
        ✅ CORREGIDO: Sin usar campo Especialidad eliminado de Trabajadores
        """
        try:
            if trabajador_id <= 0:
                return {}
            
            query = """
            SELECT 
                t.id,
                t.Nombre,
                t.Apellido_Paterno,
                t.Apellido_Materno,
                t.Matricula,
                tt.Tipo as tipo_trabajador,
                tt.area_funcional,
                CONCAT('Dr. ', t.Nombre, ' ', t.Apellido_Paterno) as nombre_completo,
                -- ✅ Especialidades desde tabla intermedia
                STRING_AGG(e.Nombre, ', ') as especialidades_nombres,
                COUNT(DISTINCT te.Id_Especialidad) as total_especialidades
            FROM Trabajadores t
            INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
            LEFT JOIN Trabajador_Especialidad te ON t.id = te.Id_Trabajador
            LEFT JOIN Especialidad e ON te.Id_Especialidad = e.id
            WHERE t.id = ?
            GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, 
                    t.Matricula, tt.Tipo, tt.area_funcional
            """
            
            result = self.repository._execute_query(query, (trabajador_id,), fetch_one=True)
            
            if result:
                return {
                    'id': result['id'],
                    'nombre_completo': result['nombre_completo'],
                    'matricula': result.get('Matricula', ''),
                    'especialidades': result.get('especialidades_nombres', 'Sin especialidades'),
                    'total_especialidades': result.get('total_especialidades', 0),
                    'tipo': result.get('tipo_trabajador', ''),
                    'area_funcional': result.get('area_funcional', '')
                }
            
            return {}
            
        except Exception as e:
            print(f"❌ Error obteniendo info de médico: {e}")
            return {}
        
    @Slot(result='QVariantList')
    def obtener_consultas_con_medicos(self):
        """
        Obtiene todas las consultas con información completa del médico
        Para actualizar la tabla principal
        
        Returns:
            Lista de consultas con todos los datos en formato QML
        """
        try:
            # Obtener consultas con información completa del médico
            consultas = self.repository.get_consultas_completas(limite=100)
            
            print(f"📋 Consultas con médicos obtenidas: {len(consultas)}")
            
            # Convertir a formato QML
            consultas_qml = []
            for consulta in consultas:
                consulta_data = {
                    'consulta_id': consulta['consulta_id'],
                    'fecha': consulta['Fecha'],
                    'tipo_consulta': consulta['Tipo_Consulta'],
                    'detalles': consulta['Detalles'],
                    
                    # Paciente
                    'paciente_id': consulta['paciente_id'],
                    'paciente_nombre': consulta['paciente_nombre_completo'],
                    'paciente_ci': consulta.get('paciente_ci', ''),
                    
                    # Especialidad
                    'especialidad_id': consulta['especialidad_id'],
                    'especialidad_nombre': consulta['especialidad_nombre'],
                    
                    # ✅ NUEVO: Médico
                    'trabajador_id': consulta.get('trabajador_id'),
                    'medico_nombre': consulta.get('medico_nombre_display', '(Sin asignar)'),
                    
                    # ✅ NUEVO: Display completo para columna
                    'especialidad_doctor': consulta['especialidad_doctor_completo'],
                    
                    # Precio
                    'precio': float(consulta.get('precio_aplicado', 0))
                }
                consultas_qml.append(consulta_data)
            
            self._consultasData = consultas_qml
            self.consultasRecientesChanged.emit()
            
            return consultas_qml
            
        except Exception as e:
            print(f"❌ Error obteniendo consultas con médicos: {e}")
            self.operacionError.emit(f"Error cargando consultas: {str(e)}")
            return []

# ===============================
# REGISTRO PARA QML
# ===============================

def register_consulta_model():
    """Registra el modelo para uso en QML"""
    qmlRegisterType(ConsultaModel, "Clinica.Models", 1, 0, "ConsultaModel")
    print("✅ ConsultaModel registrado para QML con gestión de pacientes por cédula")