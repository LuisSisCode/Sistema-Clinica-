"""
LaboratorioModel - ACTUALIZADO con autenticación estandarizada
Migrado del patrón hardcoded al patrón de ConsultaModel
"""

import re
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtQml import qmlRegisterType
from typing import List, Dict, Any, Optional
import json
from datetime import datetime, timedelta

from ..core.excepciones import ExceptionHandler, ClinicaBaseException
from ..repositories.laboratorio_repository import LaboratorioRepository
from ..core.Signals_manager import get_global_signals

class LaboratorioModel(QObject):
    """
    Modelo QObject para gestión completa de análisis de laboratorio
    Con autenticación estandarizada y verificación de permisos
    """
    
    # ===============================
    # SIGNALS PRINCIPALES
    # ===============================
    
    # Operaciones CRUD
    examenCreado = Signal(str, arguments=['datos'])
    examenActualizado = Signal(str, arguments=['datos'])
    examenEliminado = Signal(int, arguments=['examenId'])
    
    # Búsqueda por cédula
    pacienteEncontradoPorCedula = Signal('QVariantMap', arguments=['pacienteData'])
    pacienteNoEncontrado = Signal(str, arguments=['cedula'])
    
    # Estados y notificaciones
    estadoCambiado = Signal(str, arguments=['nuevoEstado'])
    errorOcurrido = Signal(str, str, arguments=['mensaje', 'codigo'])
    operacionExitosa = Signal(str, arguments=['mensaje'])
    operacionError = Signal(str, arguments=['mensaje'])  # Para compatibilidad
    
    # Signals para datos
    examenesActualizados = Signal()
    tiposAnalisisActualizados = Signal()
    trabajadoresActualizados = Signal()
    
    # Signals para paginación
    currentPageChanged = Signal()
    totalPagesChanged = Signal() 
    itemsPerPageChanged = Signal()
    totalRecordsChanged = Signal()
    
    def __init__(self, parent=None):
        super().__init__()
        
        # Repository
        self.repository = LaboratorioRepository()
        self.global_signals = get_global_signals()
        self._conectar_senales_globales()
        
        # Estados internos
        self._examenesData = []
        self._tiposAnalisisData = []
        self._trabajadoresData = []
        self._estadoActual = "listo"
        
        # ✅ AUTENTICACIÓN CON ROL
        self._usuario_actual_id = 0
        self._usuario_actual_rol = ""  # ✅ NUEVO: Almacenar rol del usuario
        print("🧪 LaboratorioModel inicializado - Esperando autenticación")
        
        # Propiedades de paginación
        self._currentPage = 0
        self._totalPages = 0
        self._itemsPerPage = 6
        self._totalRecords = 0
        
        # Configuración
        self._autoRefreshInterval = 30000
        
    # ===============================
    # ✅ MÉTODO REQUERIDO PARA APPCONTROLLER
    # ===============================
    
    @Slot(int, str)
    def set_usuario_actual_con_rol(self, usuario_id: int, usuario_rol: str):
        """
        Establece el usuario actual CON ROL para verificaciones de permisos
        """
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                self._usuario_actual_rol = usuario_rol.strip()
                print(f"👤 Usuario establecido en LaboratorioModel: ID {usuario_id}, Rol: {usuario_rol}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} ({usuario_rol}) establecido en módulo de laboratorio")
            else:
                print(f"⚠️ ID de usuario inválido en LaboratorioModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en LaboratorioModel: {e}")
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
    
    def _validar_fecha_edicion(self, fecha_registro, dias_limite: int = 5) -> bool:
        """Valida que el registro no sea muy antiguo para eliminar - SOLO PARA MÉDICOS"""
        try:
            if not fecha_registro:
                return True  # Si no hay fecha, permitir edición
            
            # Convertir a datetime si es necesario
            if isinstance(fecha_registro, str):
                try:
                    fecha_obj = datetime.fromisoformat(fecha_registro.replace('Z', ''))
                except:
                    fecha_obj = datetime.strptime(fecha_registro[:10], '%Y-%m-%d')
            elif isinstance(fecha_registro, datetime):
                fecha_obj = fecha_registro
            else:
                return True  # Si no se puede determinar la fecha, permitir
            
            # Calcular diferencia
            dias_transcurridos = (datetime.now() - fecha_obj).days
            
            if dias_transcurridos > dias_limite:
                self.operacionError.emit(f"No se pueden eiminar exámenes de más de {dias_limite} días")
                print(f"📅 Eliminacion bloqueada: {dias_transcurridos} días transcurridos (límite: {dias_limite})")
                return False
            
            return True
            
        except Exception as e:
            print(f"❌ Error validando fecha: {e}")
            return True  # En caso de error, permitir la operación
    # ===============================
    # CONEXIONES Y PROPIEDADES (SIN CAMBIOS)
    # ===============================
    
    def _conectar_senales_globales(self):
        """Conecta con las señales globales para recibir actualizaciones"""
        try:
            self.global_signals.tiposAnalisisModificados.connect(self._actualizar_tipos_analisis_desde_signal)
            self.global_signals.laboratorioNecesitaActualizacion.connect(self._manejar_actualizacion_global)
            
            # ✅ AGREGAR ESTAS DOS LÍNEAS
            self.global_signals.trabajadoresNecesitaActualizacion.connect(self._actualizar_trabajadores_desde_signal)
            self.global_signals.tiposTrabajadoresModificados.connect(self._actualizar_trabajadores_desde_signal)
            
        except Exception as e:
            print(f"Error conectando señales globales en LaboratorioModel: {e}")
    
    # Properties básicas (sin cambios)
    def _get_examenes_json(self) -> str:
        return json.dumps(self._examenesData, default=str, ensure_ascii=False)
    
    def _get_tipos_analisis_json(self) -> str:
        return json.dumps(self._tiposAnalisisData, default=str, ensure_ascii=False)
    
    def _get_trabajadores_json(self) -> str:
        return json.dumps(self._trabajadoresData, default=str, ensure_ascii=False)
    
    def _get_estado_actual(self) -> str:
        return self._estadoActual
    
    def _set_estado_actual(self, nuevo_estado: str):
        if self._estadoActual != nuevo_estado:
            self._estadoActual = nuevo_estado
            self.estadoCambiado.emit(nuevo_estado)
    
    # Properties expuestas a QML
    examenesJson = Property(str, _get_examenes_json, notify=examenesActualizados)
    tiposAnalisisJson = Property(str, _get_tipos_analisis_json, notify=tiposAnalisisActualizados)
    trabajadoresJson = Property(str, _get_trabajadores_json, notify=trabajadoresActualizados)
    estadoActual = Property(str, _get_estado_actual, notify=estadoCambiado)
    
    # Properties de paginación (sin cambios)
    def _get_current_page(self) -> int:
        return self._currentPage

    def _get_total_pages(self) -> int:
        return self._totalPages

    def _get_items_per_page(self) -> int:
        return self._itemsPerPage

    def _set_items_per_page(self, value: int):
        if value != self._itemsPerPage and value > 0:
            print(f"📊 ItemsPerPage actualizado desde QML: {self._itemsPerPage} -> {value}")
            self._itemsPerPage = value
            self.itemsPerPageChanged.emit()

    def _get_total_records(self) -> int:
        return self._totalRecords

    currentPageProperty = Property(int, _get_current_page, notify=currentPageChanged)
    totalPagesProperty = Property(int, _get_total_pages, notify=totalPagesChanged)
    itemsPerPageProperty = Property(int, _get_items_per_page, _set_items_per_page, notify=itemsPerPageChanged)
    totalRecordsProperty = Property(int, _get_total_records, notify=totalRecordsChanged)
    
    @Property(list, notify=examenesActualizados)
    def examenes_paginados(self):
        return self._examenesData
    
    @Property(list, notify=tiposAnalisisActualizados)
    def tipos_analisis(self):
        return self._tiposAnalisisData
    
    @Property(list, notify=trabajadoresActualizados)
    def trabajadores_disponibles(self):
        return self._trabajadoresData
    
    # ===============================
    # SLOTS PRINCIPALES CON AUTENTICACIÓN
    # ===============================
    
    @Slot(int, int, 'QVariant', result='QVariant')
    def obtener_examenes_paginados(self, page: int, limit: int = 6, filters=None):
        """Obtiene página específica - SIN VERIFICACIÓN (solo lectura)"""
        try:
            # Convertir filtros
            filtros_dict = filters.toVariant() if hasattr(filters, 'toVariant') else filters or {}
            
            if page < 0:
                page = 0
                
            limit_real = self._itemsPerPage
            
            resultado = self.repository.get_paginated_exams_with_details(
                page, limit_real,
                filtros_dict.get('search_term', ''),
                filtros_dict.get('tipo_analisis', ''),
                filtros_dict.get('tipo_servicio', ''),
                filtros_dict.get('fecha_desde', ''),
                filtros_dict.get('fecha_hasta', '')
            )
            
            # Actualizar propiedades
            old_page = self._currentPage
            old_total_pages = self._totalPages
            old_total_records = self._totalRecords

            self._currentPage = page
            self._totalRecords = resultado.get('total_records', 0)
            self._totalPages = max(1, (self._totalRecords + limit_real - 1) // limit_real)
            self._examenesData = resultado.get('examenes', [])
            
            # Emitir señales solo si cambiaron
            if old_page != self._currentPage:
                self.currentPageChanged.emit()
            if old_total_pages != self._totalPages:
                self.totalPagesChanged.emit()
            if old_total_records != self._totalRecords:
                self.totalRecordsChanged.emit()
                
            self.examenesActualizados.emit()
            
            return {
                'examenes': self._examenesData,
                'page': page,
                'limit': limit_real,
                'total_records': self._totalRecords,
                'total_pages': self._totalPages
            }
            
        except Exception as e:
            error_msg = f"Error obteniendo exámenes paginados: {str(e)}"
            print(f"❌ {error_msg}")
            self.errorOcurrido.emit(error_msg, 'PAGINATION_EXCEPTION')
            return {'examenes': [], 'total': 0, 'page': 0, 'total_pages': 0}
    
    @Slot(str, str, str, str, str)
    def aplicar_filtros_y_recargar(self, search_term: str = "", tipo_analisis: str = "", 
                                  tipo_servicio: str = "", fecha_desde: str = "", 
                                  fecha_hasta: str = ""):
        """Aplica filtros - SIN VERIFICACIÓN (solo lectura)"""
        try:
            self._currentPage = 0
            
            # Limpiar parámetros
            search_term = search_term.strip() if search_term else ""
            tipo_analisis = tipo_analisis.strip() if tipo_analisis else ""
            tipo_servicio = tipo_servicio.strip() if tipo_servicio else ""
            fecha_desde = fecha_desde.strip() if fecha_desde else ""
            fecha_hasta = fecha_hasta.strip() if fecha_hasta else ""
            
            filtros = {
                'search_term': search_term,
                'tipo_analisis': tipo_analisis,
                'tipo_servicio': tipo_servicio,
                'fecha_desde': fecha_desde,
                'fecha_hasta': fecha_hasta
            }
            
            self.repository.invalidate_laboratory_caches()
            
            #print(f"🔄 Aplicando filtros con {self._itemsPerPage} elementos por página")
            self.obtener_examenes_paginados(0, self._itemsPerPage, filtros)
            
        except Exception as e:
            error_msg = f"Error aplicando filtros: {str(e)}"
            print(f"❌ {error_msg}")
            self.errorOcurrido.emit(error_msg, 'FILTER_ERROR')
    
    # ===============================
    # BÚSQUEDAS POR CÉDULA (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(str, result='QVariantMap')
    def buscar_paciente_por_cedula(self, cedula: str):
        """Busca un paciente específico por su cédula - SIN VERIFICACIÓN"""
        try:
            if not cedula or len(cedula.strip()) < 5:
                return {}
            
            cedula_clean = cedula.strip()
            print(f"🔍 Buscando paciente por cédula: {cedula_clean}")
            
            paciente = self.repository.search_patient_by_cedula_exact(cedula_clean)
            
            if paciente and isinstance(paciente, dict):
                print(f"👤 Paciente encontrado: {paciente.get('nombre_completo', 'N/A')}")
                
                paciente_normalizado = {
                    'id': paciente.get('id', 0),
                    'Nombre': paciente.get('Nombre', paciente.get('nombre', '')),
                    'Apellido_Paterno': paciente.get('Apellido_Paterno', paciente.get('apellido_paterno', '')),
                    'Apellido_Materno': paciente.get('Apellido_Materno', paciente.get('apellido_materno', '')),
                    'Cedula': paciente.get('Cedula', paciente.get('cedula', cedula_clean)),
                    'nombre_completo': paciente.get('nombre_completo', ''),
                    'nombre': paciente.get('Nombre', paciente.get('nombre', '')),
                    'apellido_paterno': paciente.get('Apellido_Paterno', paciente.get('apellido_paterno', '')),
                    'apellido_materno': paciente.get('Apellido_Materno', paciente.get('apellido_materno', ''))
                }
                
                self.pacienteEncontradoPorCedula.emit(paciente_normalizado)
                return paciente_normalizado
            else:
                print(f"❌ No se encontró paciente con cédula: {cedula_clean}")
                self.pacienteNoEncontrado.emit(cedula_clean)
                return {}
                
        except Exception as e:
            error_msg = f"Error buscando paciente por cédula: {str(e)}"
            print(f"❌ {error_msg}")
            self.errorOcurrido.emit(error_msg, 'CEDULA_SEARCH_ERROR')
            return {}
    
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
    
    # ===============================
    # OPERACIONES CRUD - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(int, int, str, int, str, result=str)
    def crearExamen(self, paciente_id: int, tipo_analisis_id: int, tipo_servicio: str, 
                    trabajador_id: int = 0, detalles: str = "") -> str:
        """Crea nuevo examen de laboratorio - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN PRIMERO
            if not self._verificar_autenticacion():
                return json.dumps({'exito': False, 'error': 'Usuario no autenticado'})
            
            self._set_estado_actual("cargando")
            
            # Validar parámetros
            if paciente_id <= 0:
                raise ValueError("ID de paciente inválido")
            if tipo_analisis_id <= 0:
                raise ValueError("ID de tipo de análisis inválido")
            if not tipo_servicio or tipo_servicio not in ['Normal', 'Emergencia']:
                tipo_servicio = 'Normal'
            
            print(f"🧪 Usuario {self._usuario_actual_id} ({self._usuario_actual_rol}) creando examen")
            print(f"   - Paciente: {paciente_id}, Tipo: {tipo_analisis_id}")
            
            examen_id = self.repository.create_lab_exam(
                paciente_id=paciente_id,
                tipo_analisis_id=tipo_analisis_id,
                tipo=tipo_servicio,
                trabajador_id=trabajador_id if trabajador_id > 0 else None,
                usuario_id=self._usuario_actual_id,  # ✅ USAR USUARIO AUTENTICADO
                detalles=detalles
            )
            
            if examen_id and examen_id > 0:
                self._cargar_examenes_actuales()
                
                self.operacionExitosa.emit(f"Examen creado exitosamente: ID {examen_id}")
                self.examenCreado.emit(json.dumps({'exito': True, 'examen_id': examen_id}))
                self._set_estado_actual("listo")
                
                return json.dumps({'exito': True, 'examen_id': examen_id})
            else:
                error_msg = "Error creando examen - ID inválido"
                self.operacionError.emit(error_msg)
                self._set_estado_actual("error")
                return json.dumps({'exito': False, 'error': error_msg})
                
        except Exception as e:
            error_msg = f"Error creando examen: {str(e)}"
            print(f"❌ {error_msg}")
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return json.dumps({'exito': False, 'error': error_msg})

    @Slot(int, int, str, int, str, result=str)
    def actualizarExamen(self, examen_id: int, tipo_analisis_id: int, tipo_servicio: str, 
                        trabajador_id: int = 0, detalles: str = "") -> str:
        """Actualiza examen de laboratorio existente """
        try:
            self._set_estado_actual("cargando")
            
            if examen_id <= 0:
                raise ValueError("ID de examen inválido")
            if tipo_analisis_id <= 0:
                raise ValueError("ID de tipo de análisis inválido")
            if not tipo_servicio or tipo_servicio not in ['Normal', 'Emergencia']:
                tipo_servicio = 'Normal'
            
            # ✅ VALIDAR FECHA DE EDICIÓN (5 días para laboratorio)
            examen_actual = self.repository.get_by_id(examen_id)
            if examen_actual and not self._validar_fecha_edicion(examen_actual.get('Fecha'), dias_limite=5):
                return json.dumps({'exito': False, 'error': 'Examen muy antiguo para editar'})
            
            print(f"📝 Usuario {self._usuario_actual_id} ({self._usuario_actual_rol}) actualizando examen ID: {examen_id}")
            
            exito = self.repository.update_lab_exam(
                lab_id=examen_id,
                tipo_analisis_id=tipo_analisis_id,
                tipo_servicio=tipo_servicio,
                trabajador_id=trabajador_id if trabajador_id > 0 else None,
                detalles=detalles.strip() if detalles else None
            )
            
            if exito:
                self.repository.invalidate_laboratory_caches()
                self._cargar_examenes_actuales()
                
                self.examenActualizado.emit(json.dumps({'exito': True, 'examen_id': examen_id}))
                self.operacionExitosa.emit(f"Examen {examen_id} actualizado correctamente")
                self._set_estado_actual("listo")
                
                print(f"✅ Examen {examen_id} actualizado exitosamente")
                return json.dumps({
                    "exito": True, 
                    "mensaje": "Examen actualizado correctamente",
                    "examen_id": examen_id
                })
            else:
                error_msg = "Error actualizando examen en la base de datos"
                self.operacionError.emit(error_msg)
                self._set_estado_actual("error")
                return json.dumps({"exito": False, "error": error_msg})
                
        except Exception as e:
            error_msg = f"Error actualizando examen: {str(e)}"
            print(f"❌ {error_msg}")
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return json.dumps({"exito": False, "error": error_msg})
    @Slot(int, result=bool)
    def eliminarExamen(self, examen_id: int) -> bool:
        """Elimina examen de laboratorio - ✅ SOLO ADMINISTRADORES"""
        try:
            # ✅ VERIFICAR PERMISOS DE ADMIN PARA ELIMINACIÓN
            puede_eliminar, razon = self._verificar_permisos_eliminacion(examen_id)
            if not puede_eliminar:
                self.operacionError.emit(razon)
                return False
            
            self._set_estado_actual("cargando")
            
            print(f"🗑️ Admin {self._usuario_actual_id} eliminando examen ID: {examen_id}")
            
            exito = self.repository.delete(examen_id)
            
            if exito:
                self._cargar_examenes_actuales()
                
                self.examenEliminado.emit(examen_id)
                self.operacionExitosa.emit(f"Examen {examen_id} eliminado correctamente")
                self._set_estado_actual("listo")
                return True
            else:
                self.operacionError.emit(f"No se pudo eliminar el examen {examen_id}")
                self._set_estado_actual("error")
                return False
                
        except Exception as e:
            error_msg = f"Error eliminando examen: {str(e)}"
            self.operacionError.emit(error_msg)
            self._set_estado_actual("error")
            return False
    
    @Slot(int, result='QVariantMap')
    def verificar_permisos_analisis(self, analisis_id: int):
        """Verifica permisos del usuario actual para un análisis específico"""
        try:
            puede_editar = self._usuario_actual_rol in ["Administrador", "Médico"]
            puede_eliminar, razon_eliminar = self._verificar_permisos_eliminacion(analisis_id)
            es_admin = self._usuario_actual_rol == "Administrador"
            es_medico = self._usuario_actual_rol == "Médico"
            
            # Obtener información del análisis
            analisis = self.repository.get_by_id(analisis_id)
            dias_antiguedad = 0
            
            if analisis:
                fecha_analisis = analisis.get('Fecha')
                if fecha_analisis:
                    try:
                        if isinstance(fecha_analisis, str):
                            fecha_obj = datetime.fromisoformat(fecha_analisis.replace('Z', ''))
                        elif isinstance(fecha_analisis, datetime):
                            fecha_obj = fecha_analisis
                        else:
                            fecha_obj = datetime.now()
                        
                        dias_antiguedad = (datetime.now() - fecha_obj).days
                    except:
                        dias_antiguedad = 0
            
            # Para médicos, verificar límite de días para edición
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
                'puede_editar': False,
                'puede_eliminar': False,
                'es_administrador': False,
                'es_medico': False,
                'dias_antiguedad': 999,
                'limite_dias_edicion': 5
            }

    # ===============================
    # GESTIÓN DE DATOS (SIN CAMBIOS - LECTURA)
    # ===============================
    
    @Slot()
    def cargarTiposAnalisis(self):
        """Carga tipos de análisis disponibles"""
        try:
            tipos = self.repository.get_analysis_types()
            self._tiposAnalisisData = tipos
            self.tiposAnalisisActualizados.emit()
            #print(f"🔬 Tipos de análisis cargados: {len(tipos)}")
        except Exception as e:
            self.errorOcurrido.emit(f"Error cargando tipos: {str(e)}", 'LOAD_TYPES_ERROR')
    
    @Slot()
    def cargarTrabajadores(self):
        """Carga trabajadores de laboratorio disponibles"""
        try:
            trabajadores = self.repository.get_available_lab_workers()
            self._trabajadoresData = trabajadores
            self.trabajadoresActualizados.emit()
            print(f"👥 Trabajadores cargados: {len(trabajadores)}")
        except Exception as e:
            self.errorOcurrido.emit(f"Error cargando trabajadores: {str(e)}", 'LOAD_WORKERS_ERROR')
    
    @Slot()
    def refrescarDatos(self):
        """Refresca todos los datos del modelo"""
        try:
            self._set_estado_actual("cargando")
            
            #print("🔄 Refrescando todos los datos del modelo...")
            
            self.cargarTiposAnalisis()
            self.cargarTrabajadores()
            self._cargar_examenes_actuales()
            
            self._set_estado_actual("listo")
            self.operacionExitosa.emit("Datos actualizados correctamente")
            
        except Exception as e:
            error_msg = f"Error refrescando datos: {str(e)}"
            print(f"❌ {error_msg}")
            self.errorOcurrido.emit(error_msg, 'REFRESH_ERROR')
            self._set_estado_actual("error")
    
    # ===============================
    # MÉTODOS INTERNOS (SIN CAMBIOS)
    # ===============================
    
    def _cargar_examenes_actuales(self):
        """Carga exámenes actuales usando paginación configurada"""
        try:
            print(f"🔄 Recargando exámenes con {self._itemsPerPage} elementos por página")
            self.obtener_examenes_paginados(self._currentPage, self._itemsPerPage, {})
        except Exception as e:
            print(f"❌ Error recargando exámenes: {e}")
            self._examenesData = []
            self.examenesActualizados.emit()
    
    @Slot()
    def _actualizar_tipos_analisis_desde_signal(self):
        """Actualiza tipos de análisis cuando recibe señal global"""
        try:
            print("📡 LaboratorioModel: Recibida señal de actualización de tipos de análisis")
            self.cargarTiposAnalisis()
            print("✅ Tipos de análisis actualizados desde señal global en LaboratorioModel")
        except Exception as e:
            print(f"❌ Error actualizando tipos desde señal: {e}")

    @Slot(str)
    def _manejar_actualizacion_global(self, mensaje: str):
        """Maneja actualizaciones globales del laboratorio"""
        try:
            print(f"📡 LaboratorioModel: {mensaje}")
            self.tiposAnalisisActualizados.emit()
        except Exception as e:
            print(f"❌ Error manejando actualización global: {e}")

    def emergency_disconnect(self):
        """Desconexión de emergencia para LaboratorioModel"""
        try:
            print("🚨 LaboratorioModel: Iniciando desconexión de emergencia...")
            
            self._estadoActual = "shutdown"
            
            try:
                if hasattr(self, 'global_signals'):
                    self.global_signals.tiposAnalisisModificados.disconnect(self._actualizar_tipos_analisis_desde_signal)
                    self.global_signals.laboratorioNecesitaActualizacion.disconnect(self._manejar_actualizacion_global)
            except:
                pass
            
            signals_to_disconnect = [
                'examenCreado', 'examenActualizado', 'examenEliminado',
                'pacienteEncontradoPorCedula', 'pacienteNoEncontrado',
                'estadoCambiado', 'errorOcurrido', 'operacionExitosa',
                'examenesActualizados', 'tiposAnalisisActualizados', 'trabajadoresActualizados'
            ]
            
            for signal_name in signals_to_disconnect:
                if hasattr(self, signal_name):
                    try:
                        getattr(self, signal_name).disconnect()
                    except:
                        pass
            
            self._examenesData = []
            self._tiposAnalisisData = []
            self._trabajadoresData = []
            self._currentPage = 0
            self._totalPages = 0
            self._totalRecords = 0
            self._usuario_actual_id = 0  # ✅ RESETEAR USUARIO
            
            self.repository = None
            
            print("✅ LaboratorioModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión LaboratorioModel: {e}")

        
    def _verificar_permisos_eliminacion(self, consulta_id: int) -> tuple[bool, str]:
        """Permisos de eliminación - ADMINS sin límite, MÉDICOS máximo 30 días"""
        if not self._verificar_autenticacion():
            return False, "Usuario no autenticado"
        
        if self._usuario_actual_rol == "Administrador":
            return True, "Administrador: Sin restricciones"
        
        if self._usuario_actual_rol == "Médico":
            analisis = self.repository.get_lab_exam_by_id_complete(consulta_id)
            if not analisis:
                return False, "Analisis no encontrada"
            
            fecha_analisis = analisis.get('Fecha')
            if not self._validar_fecha_eliminacion(fecha_analisis, dias_limite=30):
                return False, "Solo puede eliminar consultas de máximo 30 días"
            
            return True, "Médico: Puede eliminar (consulta reciente)"
        
        return False, "Sin permisos para eliminar consultas"
    
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
        
    # Agregar estos métodos a la clase LaboratorioModel después de los métodos existentes

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
            
            print(f"🔍 Nombre analizado: {nombre_completo} -> {componentes}")
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

    def buscar_paciente_por_nombre_inteligente(self, nombre_completo: str):
        """
        ✅ MÉTODO AUXILIAR PARA LABORATORIO_MODEL.PY
        
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
            print(f"📢 Signal recibida en LaboratorioModel: {mensaje}")
            
            # Recargar lista de trabajadores
            self.cargarTrabajadores()
            
            print("✅ Trabajadores actualizados en LaboratorioModel")
            
        except Exception as e:
            print(f"❌ Error actualizando trabajadores desde signal: {e}")
# ===============================
# REGISTRO PARA QML
# ===============================

def register_laboratorio_model():
    """Registra el modelo para uso en QML"""
    qmlRegisterType(LaboratorioModel, "Clinica.Models", 1, 0, "LaboratorioModel")
    print("✅ LaboratorioModel registrado para QML con autenticación estandarizada")