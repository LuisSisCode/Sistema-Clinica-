"""
MedicoModel - ACTUALIZADO con autenticación estandarizada
Migrado del patrón sin autenticación al patrón de ConsultaModel
"""

from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtQml import qmlRegisterType
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

from ..repositories.medico_repository import MedicoRepository
from ..repositories.consulta_repository import ConsultaRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, safe_execute
)
from ..core.utils import (
    formatear_nombre_completo, preparar_para_qml, formatear_precio,
    safe_int, safe_float, safe_str, validar_rango_numerico,
    limpiar_texto, crear_respuesta_qml
)
from ..core.Signals_manager import get_global_signals

class MedicoModel(QObject):
    """
    Model QObject para gestión de doctores y especialidades - ACTUALIZADO con autenticación
    Conecta directamente con QML mediante Signals/Slots/Properties
    """
    
    # ===============================
    # SIGNALS PARA QML
    # ===============================
    
    # Signals de datos
    doctoresChanged = Signal()
    doctorActualChanged = Signal()
    especialidadesChanged = Signal()
    estadisticasGeneralesChanged = Signal()
    doctoresActivosChanged = Signal()
    serviciosDoctorChanged = Signal()
    
    # Signals de operaciones
    doctorCreado = Signal(int, str)        # medico_id, nombre_completo
    doctorActualizado = Signal(int)        # medico_id
    servicioCreado = Signal(int, str)      # servicio_id, nombre
    servicioActualizado = Signal(int)      # servicio_id
    operacionExitosa = Signal(str)         # mensaje
    operacionError = Signal(str)           # mensaje_error
    
    # Signals de estados
    loadingChanged = Signal()
    procesandoDoctorChanged = Signal()
    buscandoChanged = Signal()
    generandoReporteChanged = Signal()
    
    def __init__(self):
        super().__init__()
        
        # Repositories
        self.medico_repo = MedicoRepository()
        self.consulta_repo = ConsultaRepository()
        self.global_signals = get_global_signals()
        self._conectar_senales_globales()
        
        # Datos internos
        self._doctores = []
        self._doctor_actual = {}
        self._especialidades = []
        self._estadisticas_generales = {}
        self._doctores_activos = []
        self._servicios_doctor = []
        
        # Estados
        self._loading = False
        self._procesando_doctor = False
        self._buscando = False
        self._generando_reporte = False
        
        # ✅ AUTENTICACIÓN ESTANDARIZADA - COMO CONSULTAMODEL
        self._usuario_actual_id = 0  # Cambio de hardcoded a dinámico
        print("👨‍⚕️ MedicoModel inicializado - Esperando autenticación")
        
        # Configuración
        self._filtros_activos = {}
        self._doctor_seleccionado_id = 0
        
        # Timer para actualización automática
        self.update_timer = QTimer()
        self.update_timer.timeout.connect(self._auto_update_doctores)
        self.update_timer.start(300000)  # 5 minutos
        
        # Cargar datos iniciales
        self._cargar_datos_iniciales()
        
        print("👨‍⚕️ MedicoModel inicializado con autenticación estandarizada")
    
    # ===============================
    # ✅ MÉTODO REQUERIDO PARA APPCONTROLLER
    # ===============================
    
    def _conectar_senales_globales(self):
        """Conecta con las señales globales para recibir actualizaciones"""
        try:
            self.global_signals.especialidadesModificadas.connect(self._actualizar_especialidades_desde_signal)
            self.global_signals.doctoresNecesitaActualizacion.connect(self._manejar_actualizacion_global)
            #print("🔗 Señales globales conectadas en MedicoModel")
        except Exception as e:
            print(f"❌ Error conectando señales globales en MedicoModel: {e}")
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """
        Establece el usuario actual para las operaciones - MÉTODO REQUERIDO por AppController
        """
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario autenticado establecido en MedicoModel: {usuario_id}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de doctores")
            else:
                print(f"⚠️ ID de usuario inválido en MedicoModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en MedicoModel: {e}")
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
    # PROPERTIES PARA QML (SIN CAMBIOS)
    # ===============================
    
    @Property(list, notify=doctoresChanged)
    def doctores(self):
        """Lista de doctores"""
        return self._doctores
    
    @Property('QVariant', notify=doctorActualChanged)
    def doctor_actual(self):
        """Doctor actualmente seleccionado"""
        return self._doctor_actual
    
    @Property(list, notify=especialidadesChanged)
    def especialidades(self):
        """Lista de todas las especialidades/servicios"""
        return self._especialidades
    
    @Property('QVariant', notify=estadisticasGeneralesChanged)
    def estadisticas_generales(self):
        """Estadísticas generales de doctores"""
        return self._estadisticas_generales
    
    @Property(list, notify=doctoresActivosChanged)
    def doctores_activos(self):
        """Doctores más activos"""
        return self._doctores_activos
    
    @Property(list, notify=serviciosDoctorChanged)
    def servicios_doctor(self):
        """Servicios del doctor seleccionado"""
        return self._servicios_doctor
    
    @Property(bool, notify=loadingChanged)
    def loading(self):
        """Estado de carga general"""
        return self._loading
    
    @Property(bool, notify=procesandoDoctorChanged)
    def procesando_doctor(self):
        """Estado de procesamiento de doctor"""
        return self._procesando_doctor
    
    @Property(bool, notify=buscandoChanged)
    def buscando(self):
        """Estado de búsqueda"""
        return self._buscando
    
    @Property(bool, notify=generandoReporteChanged)
    def generando_reporte(self):
        """Estado de generación de reporte"""
        return self._generando_reporte
    
    # Properties de estadísticas rápidas
    @Property(int, notify=doctoresChanged)
    def total_doctores(self):
        """Total de doctores registrados"""
        return len(self._doctores)
    
    @Property(int, notify=estadisticasGeneralesChanged)
    def especialidades_diferentes(self):
        """Cantidad de especialidades diferentes"""
        return self._estadisticas_generales.get('resumen_general', {}).get('especialidades_diferentes', 0)
    
    @Property(float, notify=estadisticasGeneralesChanged)
    def edad_promedio(self):
        """Edad promedio de doctores"""
        return float(self._estadisticas_generales.get('resumen_general', {}).get('edad_promedio', 0))
    
    @Property(int, notify=especialidadesChanged)
    def total_servicios(self):
        """Total de servicios disponibles"""
        return len(self._especialidades)
    
    # ===============================
    # SLOTS PARA QML - CONFIGURACIÓN (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(int)
    def set_doctor_seleccionado(self, medico_id: int):
        """Establece el doctor seleccionado - SIN VERIFICACIÓN (solo lectura)"""
        if medico_id > 0:
            self._doctor_seleccionado_id = medico_id
            self._cargar_doctor_detalle(medico_id)
            self._cargar_servicios_doctor(medico_id)
            print(f"👨‍⚕️ Doctor seleccionado: {medico_id}")
    
    @Slot()
    def refresh_doctores(self):
        """Refresca la lista de doctores - SIN VERIFICACIÓN (solo lectura)"""
        self._cargar_doctores()
    
    @Slot()
    def refresh_estadisticas(self):
        """Refresca estadísticas generales - SIN VERIFICACIÓN (solo lectura)"""
        self._cargar_estadisticas_generales()
    
    @Slot()
    def refresh_especialidades(self):
        """Refresca especialidades - SIN VERIFICACIÓN (solo lectura)"""
        self._cargar_especialidades()
    
    # ===============================
    # SLOTS PARA QML - GESTIÓN DOCTORES - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot('QVariant', result=int)
    def crear_doctor(self, datos_doctor):
        """
        Crea nuevo doctor - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
        datos_doctor: {
            'nombre': str,
            'apellido_paterno': str,
            'apellido_materno': str,
            'especialidad': str,
            'matricula': str,
            'edad': int,
            'servicios_iniciales': [
                {
                    'nombre': str,
                    'detalles': str,
                    'precio_normal': float,
                    'precio_emergencia': float
                }
            ] (opcional)
        }
        """
        # ✅ VERIFICAR AUTENTICACIÓN PRIMERO
        if not self._verificar_autenticacion():
            return 0
        
        if not datos_doctor:
            self.operacionError.emit("Datos de doctor requeridos")
            return 0
        
        self._set_procesando_doctor(True)
        
        try:
            # Validaciones básicas
            nombre = limpiar_texto(datos_doctor.get('nombre', ''))
            apellido_paterno = limpiar_texto(datos_doctor.get('apellido_paterno', ''))
            apellido_materno = limpiar_texto(datos_doctor.get('apellido_materno', ''))
            especialidad = limpiar_texto(datos_doctor.get('especialidad', ''))
            matricula = safe_str(datos_doctor.get('matricula', '')).strip().upper()
            edad = safe_int(datos_doctor.get('edad', 0))
            
            # Validaciones
            if not nombre or len(nombre) < 2:
                raise ValidationError("nombre", nombre, "Nombre requerido (mínimo 2 caracteres)")
            
            if not apellido_paterno or len(apellido_paterno) < 2:
                raise ValidationError("apellido_paterno", apellido_paterno, "Apellido paterno requerido")
            
            if not especialidad or len(especialidad) < 3:
                raise ValidationError("especialidad", especialidad, "Especialidad requerida")
            
            if not matricula or len(matricula) < 3:
                raise ValidationError("matricula", matricula, "Matrícula requerida")
            
            if not validar_rango_numerico(edad, 25, 75):
                raise ValidationError("edad", edad, "Edad debe estar entre 25 y 75 años")
            
            # Verificar que la matrícula no exista
            if safe_execute(self.medico_repo.matricula_exists, matricula):
                raise ValidationError("matricula", matricula, "Matrícula ya existe")
            
            # ✅ USAR usuario_actual_id EN LUGAR DE HARDCODED
            print(f"👨‍⚕️ Creando doctor - Usuario: {self._usuario_actual_id}")
            
            # Crear doctor
            medico_id = safe_execute(
                self.medico_repo.create_doctor,
                nombre=nombre,
                apellido_paterno=apellido_paterno,
                apellido_materno=apellido_materno,
                especialidad=especialidad,
                matricula=matricula,
                edad=edad
            )
            
            if medico_id:
                # Crear servicios iniciales si se proporcionan
                servicios_creados = 0
                if datos_doctor.get('servicios_iniciales'):
                    for servicio in datos_doctor['servicios_iniciales']:
                        try:
                            servicio_id = safe_execute(
                                self.medico_repo.create_specialty_service,
                                medico_id=medico_id,
                                nombre=servicio['nombre'],
                                detalles=servicio.get('detalles', ''),
                                precio_normal=safe_float(servicio['precio_normal']),
                                precio_emergencia=safe_float(servicio['precio_emergencia'])
                            )
                            if servicio_id:
                                servicios_creados += 1
                        except Exception as e:
                            print(f"⚠️ Error creando servicio inicial: {e}")
                
                # Actualizar datos
                self._cargar_doctores()
                self._cargar_estadisticas_generales()
                self._cargar_especialidades()
                
                nombre_completo = formatear_nombre_completo(nombre, apellido_paterno, apellido_materno)
                
                self.doctorCreado.emit(medico_id, nombre_completo)
                mensaje = f"Doctor creado: {nombre_completo}"
                if servicios_creados > 0:
                    mensaje += f" ({servicios_creados} servicios)"
                self.operacionExitosa.emit(mensaje)
                
                print(f"✅ Doctor creado - ID: {medico_id}, Servicios: {servicios_creados}, Usuario: {self._usuario_actual_id}")
                return medico_id
            else:
                raise ValidationError("doctor", None, "Error creando doctor")
                
        except Exception as e:
            self.operacionError.emit(f"Error creando doctor: {str(e)}")
            return 0
        finally:
            self._set_procesando_doctor(False)
    
    @Slot(int, 'QVariant', result=bool)
    def actualizar_doctor(self, medico_id: int, nuevos_datos):
        """Actualiza doctor existente - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        if medico_id <= 0 or not nuevos_datos:
            self.operacionError.emit("ID de doctor y datos requeridos")
            return False
        
        self._set_procesando_doctor(True)
        
        try:
            print(f"📝 Actualizando doctor ID: {medico_id} por usuario: {self._usuario_actual_id}")
            
            # Preparar datos para actualización
            datos_actualizacion = {}
            
            if 'nombre' in nuevos_datos:
                datos_actualizacion['nombre'] = limpiar_texto(nuevos_datos['nombre'])
            
            if 'apellido_paterno' in nuevos_datos:
                datos_actualizacion['apellido_paterno'] = limpiar_texto(nuevos_datos['apellido_paterno'])
            
            if 'apellido_materno' in nuevos_datos:
                datos_actualizacion['apellido_materno'] = limpiar_texto(nuevos_datos['apellido_materno'])
            
            if 'especialidad' in nuevos_datos:
                datos_actualizacion['especialidad'] = limpiar_texto(nuevos_datos['especialidad'])
            
            if 'matricula' in nuevos_datos:
                nueva_matricula = safe_str(nuevos_datos['matricula']).strip().upper()
                # Verificar que no exista (excepto para este doctor)
                if safe_execute(self.medico_repo.matricula_exists, nueva_matricula):
                    doctor_actual = safe_execute(self.medico_repo.get_by_id, medico_id)
                    if not doctor_actual or doctor_actual.get('Matricula', '').upper() != nueva_matricula:
                        raise ValidationError("matricula", nueva_matricula, "Matrícula ya existe")
                datos_actualizacion['matricula'] = nueva_matricula
            
            if 'edad' in nuevos_datos:
                edad = safe_int(nuevos_datos['edad'])
                if not validar_rango_numerico(edad, 25, 75):
                    raise ValidationError("edad", edad, "Edad debe estar entre 25 y 75 años")
                datos_actualizacion['edad'] = edad
            
            # Actualizar doctor
            success = safe_execute(
                self.medico_repo.update_doctor,
                medico_id, **datos_actualizacion
            )
            
            if success:
                # Actualizar datos
                self._cargar_doctores()
                if self._doctor_seleccionado_id == medico_id:
                    self._cargar_doctor_detalle(medico_id)
                
                self.doctorActualizado.emit(medico_id)
                self.operacionExitosa.emit("Doctor actualizado correctamente")
                
                return True
            else:
                raise ValidationError("update", None, "Error actualizando doctor")
                
        except Exception as e:
            self.operacionError.emit(f"Error actualizando doctor: {str(e)}")
            return False
        finally:
            self._set_procesando_doctor(False)
    
    @Slot(int, result=bool)
    def eliminar_doctor(self, medico_id: int):
        """Elimina doctor (soft delete) - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        if medico_id <= 0:
            self.operacionError.emit("ID de doctor requerido")
            return False
        
        self._set_procesando_doctor(True)
        
        try:
            print(f"🗑️ Eliminando doctor ID: {medico_id} por usuario: {self._usuario_actual_id}")
            
            # Verificar si tiene consultas recientes
            consultas = safe_execute(
                self.consulta_repo.get_consultations_by_doctor,
                medico_id, limit=1
            )
            
            if consultas:
                self.operacionError.emit("No se puede eliminar: doctor tiene consultas registradas")
                return False
            
            # Eliminar doctor
            success = safe_execute(self.medico_repo.delete_doctor, medico_id)
            
            if success:
                self._cargar_doctores()
                if self._doctor_seleccionado_id == medico_id:
                    self._doctor_actual = {}
                    self._servicios_doctor = []
                    self.doctorActualChanged.emit()
                    self.serviciosDoctorChanged.emit()
                
                self.operacionExitosa.emit("Doctor eliminado correctamente")
                return True
            else:
                raise ValidationError("delete", None, "Error eliminando doctor")
                
        except Exception as e:
            self.operacionError.emit(f"Error eliminando doctor: {str(e)}")
            return False
        finally:
            self._set_procesando_doctor(False)
    
    # ===============================
    # SLOTS PARA QML - SERVICIOS/ESPECIALIDADES - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
    # ===============================
    
    @Slot(int, 'QVariant', result=int)
    def crear_servicio(self, medico_id: int, datos_servicio):
        """
        Crea nuevo servicio para un doctor - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN
        datos_servicio: {
            'nombre': str,
            'detalles': str,
            'precio_normal': float,
            'precio_emergencia': float
        }
        """
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return 0
        
        if medico_id <= 0 or not datos_servicio:
            self.operacionError.emit("Doctor y datos de servicio requeridos")
            return 0
        
        self._set_procesando_doctor(True)
        
        try:
            print(f"🔬 Creando servicio para doctor: {medico_id} por usuario: {self._usuario_actual_id}")
            
            # Validaciones
            nombre = limpiar_texto(datos_servicio.get('nombre', ''))
            detalles = limpiar_texto(datos_servicio.get('detalles', ''))
            precio_normal = safe_float(datos_servicio.get('precio_normal', 0))
            precio_emergencia = safe_float(datos_servicio.get('precio_emergencia', 0))
            
            if not nombre or len(nombre) < 5:
                raise ValidationError("nombre", nombre, "Nombre de servicio requerido (mínimo 5 caracteres)")
            
            if precio_normal <= 0:
                raise ValidationError("precio_normal", precio_normal, "Precio normal debe ser mayor a 0")
            
            if precio_emergencia <= 0:
                raise ValidationError("precio_emergencia", precio_emergencia, "Precio emergencia debe ser mayor a 0")
            
            if precio_emergencia < precio_normal:
                raise ValidationError("precio_emergencia", precio_emergencia, 
                                    "Precio emergencia debe ser mayor al precio normal")
            
            # Verificar límite de servicios por doctor
            doctor = safe_execute(self.medico_repo.get_doctor_with_services, medico_id)
            if doctor and len(doctor.get('servicios', [])) >= 10:
                raise ValidationError("servicios", None, "Doctor ya tiene el máximo de servicios (10)")
            
            # Crear servicio
            servicio_id = safe_execute(
                self.medico_repo.create_specialty_service,
                medico_id=medico_id,
                nombre=nombre,
                detalles=detalles,
                precio_normal=precio_normal,
                precio_emergencia=precio_emergencia
            )
            
            if servicio_id:
                # Actualizar datos
                self._cargar_especialidades()
                if self._doctor_seleccionado_id == medico_id:
                    self._cargar_servicios_doctor(medico_id)
                
                self.servicioCreado.emit(servicio_id, nombre)
                self.operacionExitosa.emit(f"Servicio creado: {nombre}")
                
                print(f"✅ Servicio creado - ID: {servicio_id}, Doctor: {medico_id}")
                return servicio_id
            else:
                raise ValidationError("servicio", None, "Error creando servicio")
                
        except Exception as e:
            self.operacionError.emit(f"Error creando servicio: {str(e)}")
            return 0
        finally:
            self._set_procesando_doctor(False)
    
    @Slot(int, 'QVariant', result=bool)
    def actualizar_servicio(self, servicio_id: int, nuevos_datos):
        """Actualiza servicio existente - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            return False
        
        if servicio_id <= 0 or not nuevos_datos:
            self.operacionError.emit("ID de servicio y datos requeridos")
            return False
        
        self._set_procesando_doctor(True)
        
        try:
            print(f"📝 Actualizando servicio ID: {servicio_id} por usuario: {self._usuario_actual_id}")
            
            # Preparar datos
            datos_actualizacion = {}
            
            if 'nombre' in nuevos_datos:
                nombre = limpiar_texto(nuevos_datos['nombre'])
                if len(nombre) < 5:
                    raise ValidationError("nombre", nombre, "Nombre muy corto")
                datos_actualizacion['nombre'] = nombre
            
            if 'detalles' in nuevos_datos:
                datos_actualizacion['detalles'] = limpiar_texto(nuevos_datos['detalles'])
            
            if 'precio_normal' in nuevos_datos:
                precio = safe_float(nuevos_datos['precio_normal'])
                if precio <= 0:
                    raise ValidationError("precio_normal", precio, "Precio debe ser mayor a 0")
                datos_actualizacion['precio_normal'] = precio
            
            if 'precio_emergencia' in nuevos_datos:
                precio = safe_float(nuevos_datos['precio_emergencia'])
                if precio <= 0:
                    raise ValidationError("precio_emergencia", precio, "Precio debe ser mayor a 0")
                datos_actualizacion['precio_emergencia'] = precio
            
            # Validar relación de precios
            if 'precio_normal' in datos_actualizacion and 'precio_emergencia' in datos_actualizacion:
                if datos_actualizacion['precio_emergencia'] < datos_actualizacion['precio_normal']:
                    raise ValidationError("precio_emergencia", None, 
                                        "Precio emergencia debe ser mayor al normal")
            
            # Actualizar servicio
            success = safe_execute(
                self.medico_repo.update_specialty_service,
                servicio_id, **datos_actualizacion
            )
            
            if success:
                self._cargar_especialidades()
                if self._doctor_seleccionado_id > 0:
                    self._cargar_servicios_doctor(self._doctor_seleccionado_id)
                
                self.servicioActualizado.emit(servicio_id)
                self.operacionExitosa.emit("Servicio actualizado correctamente")
                
                return True
            else:
                raise ValidationError("update", None, "Error actualizando servicio")
                
        except Exception as e:
            self.operacionError.emit(f"Error actualizando servicio: {str(e)}")
            return False
        finally:
            self._set_procesando_doctor(False)
    
    # ===============================
    # SLOTS PARA QML - BÚSQUEDAS (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(str)
    def buscar_doctores(self, termino: str):
        """Búsqueda simple de doctores - SIN VERIFICACIÓN (solo lectura)"""
        if not termino or len(termino.strip()) < 2:
            self._cargar_doctores()
            return
        
        self._set_buscando(True)
        
        try:
            resultados = safe_execute(
                self.medico_repo.search_doctors,
                termino.strip(), 50
            )
            
            # Formatear para QML
            doctores_formateados = []
            for doctor in resultados or []:
                doctores_formateados.append({
                    'id': doctor['id'],
                    'nombre_completo': formatear_nombre_completo(
                        doctor['Nombre'], doctor['Apellido_Paterno'], doctor['Apellido_Materno']
                    ),
                    'especialidad': doctor['Especialidad'],
                    'matricula': doctor['Matricula'],
                    'edad': doctor['Edad'],
                    'total_servicios': doctor.get('total_servicios', 0),
                    'data': doctor
                })
            
            self._doctores = doctores_formateados
            self.doctoresChanged.emit()
            
            print(f"🔍 Búsqueda doctores: {len(doctores_formateados)} resultados")
            
        except Exception as e:
            self.operacionError.emit(f"Error en búsqueda: {str(e)}")
        finally:
            self._set_buscando(False)
    
    @Slot('QVariant')
    def buscar_doctores_avanzado(self, criterios):
        """
        Búsqueda avanzada con criterios - SIN VERIFICACIÓN (solo lectura)
        criterios: {
            'texto': str,
            'especialidad': str,
            'edad_min': int,
            'edad_max': int,
            'con_servicios': bool,
            'activos_ultimo_mes': bool
        }
        """
        if not criterios:
            return
        
        self._set_buscando(True)
        
        try:
            # Búsqueda base
            if criterios.get('texto'):
                resultados = safe_execute(
                    self.medico_repo.search_doctors,
                    criterios['texto'], 100
                )
            else:
                resultados = safe_execute(self.medico_repo.get_all_with_specialties)
            
            if not resultados:
                resultados = []
            
            # Aplicar filtros
            if criterios.get('especialidad'):
                esp = criterios['especialidad'].lower()
                resultados = [d for d in resultados if esp in d['Especialidad'].lower()]
            
            if criterios.get('edad_min') or criterios.get('edad_max'):
                edad_min = safe_int(criterios.get('edad_min', 0))
                edad_max = safe_int(criterios.get('edad_max', 999))
                resultados = [d for d in resultados if edad_min <= d['Edad'] <= edad_max]
            
            if criterios.get('con_servicios', False):
                resultados = [d for d in resultados if d.get('total_servicios', 0) > 0]
            
            # Formatear resultados
            doctores_formateados = []
            for doctor in resultados:
                doctores_formateados.append({
                    'id': doctor['id'],
                    'nombre_completo': formatear_nombre_completo(
                        doctor['Nombre'], doctor['Apellido_Paterno'], doctor['Apellido_Materno']
                    ),
                    'especialidad': doctor['Especialidad'],
                    'matricula': doctor['Matricula'],
                    'edad': doctor['Edad'],
                    'total_servicios': doctor.get('total_servicios', 0),
                    'data': doctor
                })
            
            self._doctores = doctores_formateados
            self._filtros_activos = criterios.copy()
            self.doctoresChanged.emit()
            
            print(f"🔍 Búsqueda avanzada: {len(doctores_formateados)} resultados")
            
        except Exception as e:
            self.operacionError.emit(f"Error en búsqueda avanzada: {str(e)}")
        finally:
            self._set_buscando(False)
    
    @Slot()
    def limpiar_filtros(self):
        """Limpia filtros y muestra todos los doctores - SIN VERIFICACIÓN (solo lectura)"""
        self._filtros_activos = {}
        self._cargar_doctores()
        self.operacionExitosa.emit("Filtros limpiados")
    
    # ===============================
    # SLOTS PARA QML - REPORTES (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(int, str, str, result='QVariant')
    def generar_reporte_doctor(self, medico_id: int, fecha_inicio: str, fecha_fin: str):
        """Genera reporte detallado de un doctor - SIN VERIFICACIÓN (solo lectura)"""
        if medico_id <= 0:
            self.operacionError.emit("Doctor no seleccionado")
            return {}
        
        self._set_generando_reporte(True)
        
        try:
            # Obtener información del doctor
            doctor = safe_execute(
                self.medico_repo.get_doctor_with_consultation_history,
                medico_id
            )
            
            if not doctor:
                self.operacionError.emit("Doctor no encontrado")
                return {}
            
            # Filtrar consultas por período
            consultas = doctor.get('historial_consultas', [])
            if fecha_inicio and fecha_fin:
                from ..core.utils import parsear_fecha
                fecha_ini = parsear_fecha(fecha_inicio)
                fecha_fin_parsed = parsear_fecha(fecha_fin)
                
                if fecha_ini and fecha_fin_parsed:
                    consultas_filtradas = []
                    for c in consultas:
                        fecha_consulta = parsear_fecha(str(c.get('Fecha', '')))
                        if fecha_consulta and fecha_ini <= fecha_consulta <= fecha_fin_parsed:
                            consultas_filtradas.append(c)
                    consultas = consultas_filtradas
            
            # Calcular estadísticas
            estadisticas = {
                'total_consultas': len(consultas),
                'pacientes_unicos': len(set(c.get('Id_Paciente') for c in consultas)),
                'ingresos_estimados': sum(safe_float(c.get('Precio_Normal', 0)) for c in consultas),
                'promedio_por_consulta': 0,
                'servicios_utilizados': len(set(c.get('Id_Especialidad') for c in consultas))
            }
            
            if estadisticas['total_consultas'] > 0:
                estadisticas['promedio_por_consulta'] = (
                    estadisticas['ingresos_estimados'] / estadisticas['total_consultas']
                )
            
            # Formatear reporte
            reporte = {
                'doctor_info': {
                    'id': doctor['id'],
                    'nombre_completo': formatear_nombre_completo(
                        doctor['Nombre'], doctor['Apellido_Paterno'], doctor['Apellido_Materno']
                    ),
                    'especialidad': doctor['Especialidad'],
                    'matricula': doctor['Matricula'],
                    'edad': doctor['Edad']
                },
                'periodo': {
                    'fecha_inicio': fecha_inicio,
                    'fecha_fin': fecha_fin
                },
                'estadisticas': estadisticas,
                'servicios': doctor.get('servicios', []),
                'consultas_detalle': preparar_para_qml(consultas[:50]),  # Máximo 50 para rendimiento
                'generado_en': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
            
            print(f"📊 Reporte doctor generado: {estadisticas['total_consultas']} consultas")
            
            return preparar_para_qml(reporte)
            
        except Exception as e:
            self.operacionError.emit(f"Error generando reporte: {str(e)}")
            return {}
        finally:
            self._set_generando_reporte(False)
    
    # ===============================
    # SLOTS PARA QML - UTILIDADES (SIN VERIFICACIÓN - LECTURA)
    # ===============================
    
    @Slot(str, result=bool)
    def validar_matricula_disponible(self, matricula: str):
        """Valida si una matrícula está disponible - SIN VERIFICACIÓN (solo lectura)"""
        if not matricula or len(matricula.strip()) < 3:
            return False
        
        try:
            existe = safe_execute(self.medico_repo.matricula_exists, matricula.strip().upper())
            return not existe
        except Exception:
            return False
    
    @Slot(result=list)
    def get_especialidades_disponibles(self):
        """Obtiene lista de especialidades para ComboBox - SIN VERIFICACIÓN (solo lectura)"""
        try:
            especialidades = safe_execute(self.medico_repo.get_available_specialties)
            return especialidades or []
        except Exception as e:
            self.operacionError.emit(f"Error obteniendo especialidades: {str(e)}")
            return []
    
    @Slot(result=list)
    def get_doctores_para_combobox(self):
        """Obtiene doctores formateados para ComboBox - SIN VERIFICACIÓN (solo lectura)"""
        doctores_combobox = []
        
        for doctor in self._doctores:
            doctores_combobox.append({
                'id': doctor['id'],
                'text': doctor['nombre_completo'],
                'especialidad': doctor['especialidad'],
                'matricula': doctor['matricula'],
                'data': doctor['data']
            })
        
        return doctores_combobox
    
    # ===============================
    # MÉTODOS PRIVADOS (SIN CAMBIOS)
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga datos iniciales"""
        self._set_loading(True)
        try:
            self._cargar_doctores()
            self._cargar_estadisticas_generales()
            self._cargar_especialidades()
        finally:
            self._set_loading(False)
    
    def _cargar_doctores(self):
        """Carga lista de doctores"""
        try:
            doctores = safe_execute(self.medico_repo.get_all_with_specialties)
            
            doctores_formateados = []
            for doctor in doctores or []:
                doctores_formateados.append({
                    'id': doctor['id'],
                    'nombre_completo': formatear_nombre_completo(
                        doctor['Nombre'], doctor['Apellido_Paterno'], doctor['Apellido_Materno']
                    ),
                    'especialidad': doctor['Especialidad'],
                    'matricula': doctor['Matricula'],
                    'edad': doctor['Edad'],
                    'total_servicios': doctor.get('total_servicios', 0),
                    'data': doctor
                })
            
            self._doctores = doctores_formateados
            self.doctoresChanged.emit()
            
        except Exception as e:
            print(f"⚠️ Error cargando doctores: {e}")
    
    def _cargar_estadisticas_generales(self):
        """Carga estadísticas generales"""
        try:
            stats = safe_execute(self.medico_repo.get_doctor_statistics)
            doctores_activos = safe_execute(self.medico_repo.get_most_active_doctors, 10)
            
            self._estadisticas_generales = {
                'resumen_general': stats.get('general', {}) if stats else {},
                'especialidades': stats.get('por_especialidades', []) if stats else [],
                'ultima_actualizacion': datetime.now().strftime('%H:%M:%S')
            }
            
            # Formatear doctores activos
            doctores_activos_formateados = []
            for doctor in doctores_activos or []:
                doctores_activos_formateados.append({
                    'id': doctor['id'],
                    'nombre_completo': formatear_nombre_completo(
                        doctor['Nombre'], doctor['Apellido_Paterno'], doctor['Apellido_Materno']
                    ),
                    'especialidad': doctor['Especialidad'],
                    'total_consultas': doctor.get('total_consultas', 0),
                    'pacientes_unicos': doctor.get('pacientes_unicos', 0),
                    'data': doctor
                })
            
            self._doctores_activos = doctores_activos_formateados
            
            self.estadisticasGeneralesChanged.emit()
            self.doctoresActivosChanged.emit()
            
        except Exception as e:
            print(f"⚠️ Error cargando estadísticas: {e}")
    
    def _cargar_especialidades(self):
        """Carga todas las especialidades/servicios"""
        try:
            especialidades = safe_execute(self.medico_repo.get_all_specialty_services)
            
            especialidades_formateadas = []
            for esp in especialidades or []:
                especialidades_formateadas.append({
                    'id': esp['id'],
                    'nombre': esp['Nombre'],
                    'precio_normal': esp['Precio_Normal'],
                    'precio_emergencia': esp['Precio_Emergencia'],
                    'precio_normal_formateado': formatear_precio(esp['Precio_Normal']),
                    'precio_emergencia_formateado': formatear_precio(esp['Precio_Emergencia']),
                    'doctor_nombre': esp.get('doctor_nombre', ''),
                    'doctor_especialidad': esp.get('doctor_especialidad', ''),
                    'data': esp
                })
            
            self._especialidades = especialidades_formateadas
            self.especialidadesChanged.emit()
            
        except Exception as e:
            print(f"⚠️ Error cargando especialidades: {e}")
    
    def _cargar_doctor_detalle(self, medico_id: int):
        """Carga detalle completo de un doctor"""
        try:
            doctor = safe_execute(
                self.medico_repo.get_doctor_with_consultation_history,
                medico_id
            )
            
            if doctor:
                # Enriquecer datos
                doctor_enriquecido = doctor.copy()
                doctor_enriquecido['nombre_completo'] = formatear_nombre_completo(
                    doctor['Nombre'], doctor['Apellido_Paterno'], doctor['Apellido_Materno']
                )
                
                self._doctor_actual = preparar_para_qml(doctor_enriquecido)
            else:
                self._doctor_actual = {}
            
            self.doctorActualChanged.emit()
            
        except Exception as e:
            print(f"⚠️ Error cargando doctor detalle: {e}")
            self._doctor_actual = {}
            self.doctorActualChanged.emit()
    
    def _cargar_servicios_doctor(self, medico_id: int):
        """Carga servicios de un doctor específico"""
        try:
            doctor = safe_execute(self.medico_repo.get_doctor_with_services, medico_id)
            
            if doctor and doctor.get('servicios'):
                servicios_formateados = []
                for servicio in doctor['servicios']:
                    servicios_formateados.append({
                        'id': servicio['id'],
                        'nombre': servicio['Nombre'],
                        'detalles': servicio.get('Detalles', ''),
                        'precio_normal': servicio['Precio_Normal'],
                        'precio_emergencia': servicio['Precio_Emergencia'],
                        'precio_normal_formateado': formatear_precio(servicio['Precio_Normal']),
                        'precio_emergencia_formateado': formatear_precio(servicio['Precio_Emergencia']),
                        'data': servicio
                    })
                
                self._servicios_doctor = servicios_formateados
            else:
                self._servicios_doctor = []
            
            self.serviciosDoctorChanged.emit()
            
        except Exception as e:
            print(f"⚠️ Error cargando servicios doctor: {e}")
            self._servicios_doctor = []
            self.serviciosDoctorChanged.emit()
    
    def _auto_update_doctores(self):
        """Actualización automática de doctores"""
        if not self._loading and not self._procesando_doctor:
            try:
                self._cargar_estadisticas_generales()
            except Exception as e:
                print(f"⚠️ Error en auto-update doctores: {e}")
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()
    
    def _set_procesando_doctor(self, procesando: bool):
        """Actualiza estado de procesamiento"""
        if self._procesando_doctor != procesando:
            self._procesando_doctor = procesando
            self.procesandoDoctorChanged.emit()
    
    def _set_buscando(self, buscando: bool):
        """Actualiza estado de búsqueda"""
        if self._buscando != buscando:
            self._buscando = buscando
            self.buscandoChanged.emit()
    
    def _set_generando_reporte(self, generando: bool):
        """Actualiza estado de generación de reporte"""
        if self._generando_reporte != generando:
            self._generando_reporte = generando
            self.generandoReporteChanged.emit()
    
    @Slot()
    def _actualizar_especialidades_desde_signal(self):
        """Actualiza especialidades cuando recibe señal global"""
        try:
            print("📡 MedicoModel: Recibida señal de actualización de especialidades")
            self._cargar_especialidades()
            print("✅ Especialidades actualizadas desde señal global en MedicoModel")
        except Exception as e:
            print(f"❌ Error actualizando especialidades desde señal: {e}")

    @Slot(str)
    def _manejar_actualizacion_global(self, mensaje: str):
        """Maneja actualizaciones globales de doctores"""
        try:
            print(f"📡 MedicoModel: {mensaje}")
            self.especialidadesChanged.emit()
        except Exception as e:
            print(f"❌ Error manejando actualización global: {e}")

    def emergency_disconnect(self):
        """Desconexión de emergencia para MedicoModel"""
        try:
            print("🚨 MedicoModel: Iniciando desconexión de emergencia...")
            
            # Detener timer
            if hasattr(self, 'update_timer') and self.update_timer.isActive():
                self.update_timer.stop()
                print("   ⏹️ Update timer detenido")
            
            # Establecer estado shutdown
            self._loading = False
            self._procesando_doctor = False
            self._buscando = False
            self._generando_reporte = False
            
            # Desconectar señales globales
            try:
                if hasattr(self, 'global_signals'):
                    self.global_signals.especialidadesModificadas.disconnect(self._actualizar_especialidades_desde_signal)
                    self.global_signals.doctoresNecesitaActualizacion.disconnect(self._manejar_actualizacion_global)
            except:
                pass
            
            # Desconectar todas las señales propias
            signals_to_disconnect = [
                'doctoresChanged', 'doctorActualChanged', 'especialidadesChanged',
                'estadisticasGeneralesChanged', 'doctoresActivosChanged', 'serviciosDoctorChanged',
                'doctorCreado', 'doctorActualizado', 'servicioCreado', 'servicioActualizado',
                'operacionExitosa', 'operacionError', 'loadingChanged', 'procesandoDoctorChanged',
                'buscandoChanged', 'generandoReporteChanged'
            ]
            
            for signal_name in signals_to_disconnect:
                if hasattr(self, signal_name):
                    try:
                        getattr(self, signal_name).disconnect()
                    except:
                        pass
            
            # Limpiar datos
            self._doctores = []
            self._especialidades = []
            self._estadisticas_generales = {}
            self._doctores_activos = []
            self._servicios_doctor = []
            self._doctor_actual = {}
            self._filtros_activos = {}
            self._doctor_seleccionado_id = 0
            self._usuario_actual_id = 0  # ✅ RESETEAR USUARIO
            
            self.medico_repo = None
            self.consulta_repo = None
            
            print("✅ MedicoModel: Desconexión de emergencia completada")
            
        except Exception as e:
            print(f"❌ Error en desconexión MedicoModel: {e}")

# ===============================
# REGISTRO PARA QML
# ===============================

def register_medico_model():
    """Registra el modelo para uso en QML"""
    qmlRegisterType(MedicoModel, "ClinicaModels", 1, 0, "MedicoModel")
    print("✅ MedicoModel registrado para QML con autenticación estandarizada")