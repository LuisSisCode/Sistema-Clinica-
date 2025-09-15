"""
LaboratorioModel - ACTUALIZADO con autenticación estandarizada
Migrado del patrón hardcoded al patrón de ConsultaModel
"""

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
        
        # ✅ AUTENTICACIÓN ESTANDARIZADA - COMO CONSULTAMODEL
        self._usuario_actual_id = 0  # Cambio de hardcoded a dinámico
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
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """
        Establece el usuario actual para las operaciones - MÉTODO REQUERIDO por AppController
        """
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario autenticado establecido en LaboratorioModel: {usuario_id}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de laboratorio")
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
    
    # ===============================
    # PROPIEDADES DE AUTENTICACIÓN
    # ===============================
    
    def _verificar_autenticacion(self) -> bool:
        """Verifica si el usuario está autenticado"""
        if self._usuario_actual_id <= 0:
            self.operacionError.emit("Usuario no autenticado. Por favor inicie sesión.")
            return False
        return True
    
    # ===============================
    # CONEXIONES Y PROPIEDADES (SIN CAMBIOS)
    # ===============================
    
    def _conectar_senales_globales(self):
        """Conecta con las señales globales para recibir actualizaciones"""
        try:
            self.global_signals.tiposAnalisisModificados.connect(self._actualizar_tipos_analisis_desde_signal)
            self.global_signals.laboratorioNecesitaActualizacion.connect(self._manejar_actualizacion_global)
            print("Señales globales conectadas en LaboratorioModel")
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
            
            print(f"📖 Obteniendo página {page + 1} con {limit_real} elementos")
            
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
            
            print(f"✅ Página {page + 1} cargada: {len(self._examenesData)} registros de {self._totalRecords}")
            
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
            
            print(f"🔄 Aplicando filtros con {self._itemsPerPage} elementos por página")
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
            
            print(f"🔄 Gestionando paciente: {nombre} {apellido_paterno} - Cédula: {cedula}")
            
            paciente_id = self.repository.buscar_o_crear_paciente_simple(
                nombre.strip(), 
                apellido_paterno.strip(), 
                apellido_materno.strip(), 
                cedula.strip()
            )
            
            if paciente_id > 0:
                self.operacionExitosa.emit(f"Paciente gestionado correctamente: ID {paciente_id}")
                return paciente_id
            else:
                self.operacionError.emit("Error gestionando paciente")
                return -1
                
        except Exception as e:
            error_msg = f"Error gestionando paciente: {str(e)}"
            print(f"❌ {error_msg}")
            self.operacionError.emit(error_msg)
            return -1
    
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
            
            # ✅ USAR usuario_actual_id EN LUGAR DE HARDCODED
            print(f"🧪 Creando examen - Paciente: {paciente_id}, Tipo: {tipo_analisis_id}, Usuario: {self._usuario_actual_id}")
            
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
        """Actualiza examen de laboratorio existente - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN
            if not self._verificar_autenticacion():
                return json.dumps({'exito': False, 'error': 'Usuario no autenticado'})
            
            self._set_estado_actual("cargando")
            
            if examen_id <= 0:
                raise ValueError("ID de examen inválido")
            if tipo_analisis_id <= 0:
                raise ValueError("ID de tipo de análisis inválido")
            if not tipo_servicio or tipo_servicio not in ['Normal', 'Emergencia']:
                tipo_servicio = 'Normal'
            
            print(f"🔄 Actualizando examen ID: {examen_id} por usuario: {self._usuario_actual_id}")
            
            examen_actual = self.repository.get_by_id(examen_id)
            if not examen_actual:
                error_msg = f"Examen con ID {examen_id} no encontrado"
                self.operacionError.emit(error_msg)
                self._set_estado_actual("error")
                return json.dumps({"exito": False, "error": error_msg})
            
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
        """Elimina examen de laboratorio - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        try:
            # ✅ VERIFICAR AUTENTICACIÓN
            if not self._verificar_autenticacion():
                return False
            
            self._set_estado_actual("cargando")
            
            print(f"🗑️ Eliminando examen ID: {examen_id} por usuario: {self._usuario_actual_id}")
            
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
            print(f"🔬 Tipos de análisis cargados: {len(tipos)}")
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
            
            print("🔄 Refrescando todos los datos del modelo...")
            
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

# ===============================
# REGISTRO PARA QML
# ===============================

def register_laboratorio_model():
    """Registra el modelo para uso en QML"""
    qmlRegisterType(LaboratorioModel, "Clinica.Models", 1, 0, "LaboratorioModel")
    print("✅ LaboratorioModel registrado para QML con autenticación estandarizada")