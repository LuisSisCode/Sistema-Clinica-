"""
TrabajadorModel - ACTUALIZADO con autenticación estandarizada
Migrado del patrón sin autenticación al patrón de ConsultaModel
"""

from typing import List, Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtQml import qmlRegisterType

from ..repositories.trabajador_repository import TrabajadorRepository
from ..core.excepciones import ExceptionHandler, ValidationError
from ..core.Signals_manager import get_global_signals

class TrabajadorModel(QObject):
    """
    Model QObject para gestión de trabajadores en QML - ACTUALIZADO con autenticación
    Conecta la interfaz QML con el TrabajadorRepository
    """
    
    # ===============================
    # SIGNALS - Notificaciones a QML
    # ===============================
    
    # Señales para cambios en datos
    trabajadoresChanged = Signal()
    tiposTrabajadorChanged = Signal()
    estadisticasChanged = Signal()
    
    # Señales para operaciones
    trabajadorCreado = Signal(bool, str)  # success, message
    trabajadorActualizado = Signal(bool, str)
    trabajadorEliminado = Signal(bool, str)
    
    tipoTrabajadorCreado = Signal(bool, str)
    tipoTrabajadorActualizado = Signal(bool, str)
    tipoTrabajadorEliminado = Signal(bool, str)
    
    # Señales para búsquedas
    busquedaCompleta = Signal(bool, str, int)  # success, message, total
    
    # Señales para UI
    loadingChanged = Signal()
    errorOccurred = Signal(str, str)  # title, message
    successMessage = Signal(str)
    warningMessage = Signal(str)
    operacionError = Signal(str)     # Para compatibilidad
    operacionExitosa = Signal(str)   # Para compatibilidad
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # ✅ IDENTIFICADOR ÚNICO DE INSTANCIA
        import time
        self._instance_id = f"TrabajadorModel_{int(time.time() * 1000)}"
        
        # ✅ VARIABLES PRIMERO - ANTES DE LLAMAR CUALQUIER MÉTODO
        self._trabajadores: List[Dict[str, Any]] = []
        self._trabajadores_filtrados: List[Dict[str, Any]] = []
        self._tipos_trabajador: List[Dict[str, Any]] = []
        self._estadisticas: Dict[str, Any] = {}
        self._loading: bool = False
        
        # ✅ VARIABLES DE AUTENTICACIÓN Y DEBUG
        self._usuario_actual_id = 0
        self._usuario_actual_rol = ""
        self._debug_calls = []  # Log de llamadas
        
        print(f"🆔 NUEVA INSTANCIA TrabajadorModel: {self._instance_id}")
        
        # Repository en lugar de service
        self.repository = TrabajadorRepository()
        self.global_signals = get_global_signals()
        self._conectar_senales_globales()
        
        print(f"🔍 TrabajadorModel.__init__: _usuario_actual_id={self._usuario_actual_id}, _usuario_actual_rol='{self._usuario_actual_rol}'")
        
        # Filtros activos
        self._filtro_tipo: int = 0
        self._filtro_area: str = "Todos"
        self._filtro_busqueda: str = ""
        self._incluir_stats: bool = False
        
        # Configuración inicial
        self._cargar_datos_iniciales()
        print("👷‍♂️ TrabajadorModel inicializado con debug simple")

    # ===============================
    # MÉTODOS DE DEBUG
    # ===============================
    
    def _log_call(self, method_name: str, extra_info: str = ""):
        """Registra llamadas a métodos críticos"""
        import traceback
        caller = traceback.format_stack()[-3].strip()  # Quien llamó este método
        
        entry = {
            'method': method_name,
            'auth_id': self._usuario_actual_id,
            'auth_role': self._usuario_actual_rol,
            'instance_id': self._instance_id,
            'caller': caller,
            'extra': extra_info
        }
        
        self._debug_calls.append(entry)
        
        # Mantener solo últimas 10 llamadas
        if len(self._debug_calls) > 10:
            self._debug_calls.pop(0)

    # ===============================
    # MÉTODOS DE CONEXIÓN
    # ===============================
    
    def _conectar_senales_globales(self):
        """Conecta con las señales globales - CON DEBUG"""
        self._log_call("_conectar_senales_globales", "INICIO")
        
        try:
            # Conectar señales de tipos de trabajadores
            self.global_signals.tiposTrabajadoresModificados.connect(self._actualizar_tipos_trabajadores_desde_signal)
            self.global_signals.trabajadoresNecesitaActualizacion.connect(self._manejar_actualizacion_global)
            
            #print("🔗 Señales globales conectadas en TrabajadorModel")
        except Exception as e:
            print(f"❌ Error conectando señales globales: {e}")
        
        self._log_call("_conectar_senales_globales", "FIN")

    @Slot(int, str)
    def _on_usuario_autenticado_cambiado(self, usuario_id: int, usuario_rol: str):
        """Maneja cambios en el usuario autenticado desde señales globales"""
        try:
            print(f"📡 TrabajadorModel: Recibido usuario autenticado - ID: {usuario_id}, Rol: {usuario_rol}")
            self.set_usuario_actual_con_rol(usuario_id, usuario_rol)
        except Exception as e:
            print(f"❌ Error en _on_usuario_autenticado_cambiado: {e}")

    # ===============================
    # MÉTODOS DE AUTENTICACIÓN
    # ===============================
    
    @Slot(int)
    def set_usuario_actual(self, usuario_id: int):
        """Establece el usuario actual para las operaciones - MÉTODO REQUERIDO por AppController"""
        try:
            if usuario_id > 0:
                self._usuario_actual_id = usuario_id
                print(f"👤 Usuario autenticado establecido en TrabajadorModel: {usuario_id}")
                self.operacionExitosa.emit(f"Usuario {usuario_id} establecido en módulo de trabajadores")
            else:
                print(f"⚠️ ID de usuario inválido en TrabajadorModel: {usuario_id}")
                self.operacionError.emit("ID de usuario inválido")
        except Exception as e:
            print(f"❌ Error estableciendo usuario en TrabajadorModel: {e}")
            self.operacionError.emit(f"Error estableciendo usuario: {str(e)}")

    @Slot(int, str)
    def set_usuario_actual_con_rol(self, usuario_id: int, usuario_rol: str):
        """Establece usuario - VERSIÓN DEBUG ULTRA-SIMPLE"""
        self._log_call("set_usuario_actual_con_rol", f"ENTRADA: {usuario_id}, '{usuario_rol}'")
        
        try:
            print(f"🔍 set_usuario_actual_con_rol INICIO: ({usuario_id}, '{usuario_rol}')")
            print(f"🔍 ANTES: ID={self._usuario_actual_id}, Rol='{self._usuario_actual_rol}'")
            
            if usuario_id <= 0:
                print("⚠️ ID inválido")
                return
                
            if not usuario_rol or not usuario_rol.strip():
                print("⚠️ Rol vacío")
                return
            
            # ✅ ASIGNAR CON LOG INMEDIATO
            print(f"🔄 ASIGNANDO ID: {self._usuario_actual_id} → {usuario_id}")
            self._usuario_actual_id = usuario_id
            print(f"✅ ID asignado: {self._usuario_actual_id}")
            
            print(f"🔄 ASIGNANDO ROL: '{self._usuario_actual_rol}' → '{usuario_rol.strip()}'")
            self._usuario_actual_rol = usuario_rol.strip()
            print(f"✅ ROL asignado: '{self._usuario_actual_rol}'")
            
            print(f"🔍 DESPUÉS: ID={self._usuario_actual_id}, Rol='{self._usuario_actual_rol}'")
            
            # Verificar inmediatamente
            if self._usuario_actual_id != usuario_id:
                print(f"❌ ERROR: ID no coincide! Esperado: {usuario_id}, Actual: {self._usuario_actual_id}")
            
            if self._usuario_actual_rol != usuario_rol.strip():
                print(f"❌ ERROR: Rol no coincide! Esperado: '{usuario_rol.strip()}', Actual: '{self._usuario_actual_rol}'")
            
            self.operacionExitosa.emit(f"Usuario {usuario_id} ({usuario_rol}) establecido")
            
            # Verificación retardada
            QTimer.singleShot(1000, lambda: self._verificar_despues_de_1_segundo(usuario_id, usuario_rol))
            QTimer.singleShot(3000, lambda: self._verificar_despues_de_3_segundos(usuario_id, usuario_rol))
            
        except Exception as e:
            print(f"❌ Error en set_usuario_actual_con_rol: {e}")
            self.operacionError.emit(f"Error: {str(e)}")
        
        self._log_call("set_usuario_actual_con_rol", f"SALIDA: Final ID={self._usuario_actual_id}")

    def _verificar_despues_de_1_segundo(self, expected_id: int, expected_rol: str):
        """Verificación tras 1 segundo"""
        pass

    def _verificar_despues_de_3_segundos(self, expected_id: int, expected_rol: str):
        """Verificación tras 3 segundos"""
        pass

    def _verificar_autenticacion(self) -> bool:
        """Verificación de autenticación - DEBUG"""
        self._log_call("_verificar_autenticacion", f"ID={self._usuario_actual_id}")
        
        
        if self._usuario_actual_id <= 0:
            print(f"❌ Usuario no autenticado en instancia {self._instance_id}")
            print(f"📝 Últimas 5 llamadas antes del fallo:")
            for call in self._debug_calls[-5:]:
                print(f"   {call['method']}: ID={call['auth_id']} (instancia: {call.get('instance_id', 'unknown')})")
            
            self.operacionError.emit("Usuario no autenticado")
            return False
        
        print(f"✅ Usuario autenticado en instancia {self._instance_id}")
        return True

    def _es_administrador(self) -> bool:
        """Verifica si el usuario actual es administrador"""
        try:
            if hasattr(self, '_usuario_actual_rol'):
                es_admin = self._usuario_actual_rol == "Administrador"
                return es_admin
            return False
        except Exception as e:
            return False

    @Slot(result=bool)
    def esAdministrador(self) -> bool:
        """Verifica si el usuario es administrador (para QML)"""
        return self._es_administrador()

    def _puede_editar_trabajador(self, trabajador_id: int) -> bool:
        """Verifica si puede editar un trabajador específico"""
        if self._es_administrador():
            return True
        
        if self._usuario_actual_rol == "Médico":
            # Médicos pueden editar trabajadores creados hace menos de 30 días
            trabajador = self.repository.get_by_id(trabajador_id)
            if trabajador:
                from datetime import datetime, timedelta
                try:
                    # Asumir que hay campo fecha de creación o usar fecha actual como referencia
                    fecha_limite = datetime.now() - timedelta(days=30)
                    return True  # Por ahora permitir, implementar lógica de fecha si es necesario
                except:
                    return True
        
        return False

    @Slot(int, result=bool)
    def puedeEditarTrabajador(self, trabajador_id: int) -> bool:
        """Verifica permisos de edición para QML"""
        return self._puede_editar_trabajador(trabajador_id)
    
    @Property(int, notify=operacionExitosa)
    def usuario_actual_id(self):
        """Property para obtener el usuario actual"""
        return self._usuario_actual_id

    # ===============================
    # SLOTS PARA DEBUG DESDE QML
    # ===============================
    
    @Slot(result=str)
    def get_debug_info(self) -> str:
        """Info de debug para QML"""
        try:
            info = {
                'current_id': self._usuario_actual_id,
                'current_role': self._usuario_actual_rol,
                'call_count': len(self._debug_calls),
                'last_calls': self._debug_calls[-3:] if self._debug_calls else []
            }
            import json
            return json.dumps(info, indent=2)
        except Exception as e:
            return f"Error: {e}"

    @Slot()
    def force_debug_print(self):
        """Fuerza impresión de debug desde QML"""
        print(f"🔍 ESTADO ACTUAL FORZADO:")
        print(f"   ID: {self._usuario_actual_id}")
        print(f"   Rol: '{self._usuario_actual_rol}'")
        print(f"   Llamadas registradas: {len(self._debug_calls)}")

    # ===============================
    # PROPERTIES - Datos para QML
    # ===============================
   
    @Property(list, notify=trabajadoresChanged)
    def trabajadores(self) -> List[Dict[str, Any]]:
        """Lista de trabajadores para mostrar en QML"""
        return self._trabajadores_filtrados
    
    @Property('QVariantList', notify=tiposTrabajadorChanged)
    def tiposTrabajador(self):
        """Lista de tipos de trabajador - CORREGIDA para QML"""
        try:
            if not self._tipos_trabajador:
                return []
            
            # ✅ CONVERTIR EXPLÍCITAMENTE A LISTA COMPATIBLE CON QML
            tipos_compatibles = []
            for tipo in self._tipos_trabajador:
                tipo_compatible = {
                    'id': tipo.get('id', 0),
                    'Tipo': str(tipo.get('Tipo', '')),
                    'descripcion': str(tipo.get('descripcion', '')),
                    'total_trabajadores': tipo.get('total_trabajadores', 0)
                }
                tipos_compatibles.append(tipo_compatible)
            
            return tipos_compatibles
            
        except Exception as e:
            print(f"❌ Error en tiposTrabajador property: {e}")
            return []
        
    @Slot(result='QVariantList')
    def obtenerTiposTrabajadorParaQML(self):
        """Obtiene tipos de trabajador en formato QVariantList para QML - CORREGIDO"""
        try:
            print(f"🔍 obtenerTiposTrabajadorParaQML llamado")
            print(f"   Tipos en memoria: {len(self._tipos_trabajador)}")
            
            if not self._tipos_trabajador:
                print(f"⚠️ Lista vacía en memoria")
                return []
            
            # ✅ CREAR LISTA COMPATIBLE CON QML - FORMATO SIMPLIFICADO
            tipos_qml = []
            for tipo in self._tipos_trabajador:
                # Crear diccionario simple que QML pueda entender
                tipo_dict = {
                    'id': tipo.get('id', 0),
                    'Tipo': tipo.get('Tipo', ''),
                    'descripcion': tipo.get('descripcion', ''),
                    'total_trabajadores': tipo.get('total_trabajadores', 0)
                }
                tipos_qml.append(tipo_dict)
            
            print(f"✅ Retornando {len(tipos_qml)} tipos para QML")
            return tipos_qml
            
        except Exception as e:
            print(f"❌ Error en obtenerTiposTrabajadorParaQML: {e}")
            import traceback
            traceback.print_exc()
            return []

    @Slot(result=int)
    def cantidadTiposDisponibles(self) -> int:
        """Retorna la cantidad de tipos disponibles"""
        cantidad = len(self._tipos_trabajador) if self._tipos_trabajador else 0
        print(f"📊 cantidadTiposDisponibles: {cantidad}")
        return cantidad
    
    @Property('QVariantMap', notify=estadisticasChanged)
    def estadisticas(self) -> Dict[str, Any]:
        """Estadísticas de trabajadores"""
        return self._estadisticas
    
    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        """Estado de carga"""
        return self._loading
    
    @Property(int, notify=trabajadoresChanged)
    def totalTrabajadores(self) -> int:
        """Total de trabajadores filtrados"""
        return len(self._trabajadores_filtrados)
    
    @Property(str)
    def filtroTipo(self) -> str:
        """Filtro actual por tipo"""
        return str(self._filtro_tipo)
    
    @Property(str)
    def filtroArea(self) -> str:
        """Filtro actual por área"""
        return self._filtro_area
    
    @Property(str)
    def filtroBusqueda(self) -> str:
        """Texto de búsqueda actual"""
        return self._filtro_busqueda

    # ===============================
    # SLOTS PARA OPERACIONES CRUD TRABAJADORES
    # ===============================
    
    @Slot(str, str, str, int, str, str, result=bool)
    def crearTrabajador(self, nombre: str, apellido_paterno: str, 
                apellido_materno: str, tipo_trabajador_id: int,
                especialidad: str = "", matricula: str = "") -> bool:
        """Crea nuevo trabajador desde QML - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN PRIMERO
        if not self._verificar_autenticacion():
            self.trabajadorCreado.emit(False, "Usuario no autenticado")
            return False
        
        try:
            self._set_loading(True)
            
            print(f"👷‍♂️ Creando trabajador - Usuario: {self._usuario_actual_id}")
            
            trabajador_id = self.repository.create_worker(
                nombre=nombre.strip(),
                apellido_paterno=apellido_paterno.strip(),
                apellido_materno=apellido_materno.strip(),
                tipo_trabajador_id=tipo_trabajador_id,
                usuario_id=self._usuario_actual_id,  # Agregar este parámetro
                especialidad=especialidad.strip() if especialidad.strip() else None,
                matricula=matricula.strip() if matricula.strip() else None
            )
            
            if trabajador_id:
                # Carga inmediata y forzada de datos
                self._cargar_trabajadores()
                self._cargar_tipos_trabajador()
                self._cargar_estadisticas()
                
                # Forzar aplicación de filtros actuales
                self.aplicarFiltros(self._filtro_tipo, self._filtro_busqueda, 
                                self._incluir_stats, self._filtro_area)
                
                mensaje = f"Trabajador creado exitosamente - ID: {trabajador_id}"
                self.trabajadorCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)

                self.global_signals.trabajadoresNecesitaActualizacion.emit(
                    f"Trabajador creado: ID {trabajador_id}"
                )
                print(f"✅ Trabajador creado desde QML: {nombre} {apellido_paterno}, Usuario: {self._usuario_actual_id}")
                return True 
            else:
                error_msg = "Error creando trabajador"
                self.trabajadorCreado.emit(False, error_msg)
                self.errorOccurred.emit("Error de validación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.trabajadorCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, str, str, str, int, str, str, result=bool)
    def actualizarTrabajador(self, trabajador_id: int, nombre: str = "", 
                            apellido_paterno: str = "", apellido_materno: str = "",
                            tipo_trabajador_id: int = 0, especialidad: str = "", 
                            matricula: str = "") -> bool:
        """Actualiza trabajador existente - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            self.trabajadorActualizado.emit(False, "Usuario no autenticado")
            return False
        
        try:
            self._set_loading(True)
            
            print(f"🔄 Actualizando trabajador ID: {trabajador_id} por usuario: {self._usuario_actual_id}")
            
            # Preparar argumentos solo con valores no vacíos
            kwargs = {}
            if nombre.strip():
                kwargs['nombre'] = nombre.strip()
            if apellido_paterno.strip():
                kwargs['apellido_paterno'] = apellido_paterno.strip()
            if apellido_materno.strip():
                kwargs['apellido_materno'] = apellido_materno.strip()
            if tipo_trabajador_id > 0:
                kwargs['tipo_trabajador_id'] = tipo_trabajador_id
            if especialidad.strip():
                kwargs['especialidad'] = especialidad.strip()
            if matricula.strip():
                kwargs['matricula'] = matricula.strip()
            
            success = self.repository.update_worker(trabajador_id, **kwargs)
            
            if success:
                self._cargar_trabajadores()
                
                mensaje = f"Trabajador actualizado exitosamente  - ID: {trabajador_id}"
                self.trabajadorActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)

                self.global_signals.trabajadoresNecesitaActualizacion.emit(
                    f"Trabajador actualizado: ID {trabajador_id}"
                )
                
                print(f"✅ Trabajador actualizado desde QML: ID {trabajador_id}")
                return True
            else:
                error_msg = "Error actualizando trabajador"
                self.trabajadorActualizado.emit(False, error_msg)
                self.errorOccurred.emit("Error de actualización", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.trabajadorActualizado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, result=bool)
    def eliminarTrabajador(self, trabajador_id: int) -> bool:
        """Elimina trabajador desde QML - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            self.trabajadorEliminado.emit(False, "Usuario no autenticado")
            return False
        # Verificar permisos de administrador
        if not self._es_administrador():
            error_msg = "Solo administradores pueden eliminar trabajadores"
            self.trabajadorEliminado.emit(False, error_msg)
            return False
        
        try:
            self._set_loading(True)
            
            print(f"🗑️ Eliminando trabajador ID: {trabajador_id} por usuario: {self._usuario_actual_id}")
            
            # Verificar que no tenga asignaciones de laboratorio
            asignaciones = self.repository.get_worker_lab_assignments(trabajador_id)
            if asignaciones:
                self.warningMessage.emit(f"Trabajador tiene {len(asignaciones)} asignaciones de laboratorio activas")
                return False
            
            success = self.repository.delete(trabajador_id)
            
            if success:
                self._cargar_trabajadores()
                self._cargar_estadisticas()
                
                mensaje = f"Trabajador eliminado exitosamente - ID: {trabajador_id}"
                self.trabajadorEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)

                self.global_signals.trabajadoresNecesitaActualizacion.emit(
                    f"Trabajador eliminado: ID {trabajador_id}"
                )
                
                print(f"🗑️ Trabajador eliminado desde QML: ID {trabajador_id}")
                return True
            else:
                error_msg = "Error eliminando trabajador"
                self.trabajadorEliminado.emit(False, error_msg)
                self.errorOccurred.emit("Error de eliminación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.trabajadorEliminado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)

    # ===============================
    # SLOTS PARA OPERACIONES CRUD TIPOS
    # ===============================
    
    @Slot(str, result=bool)
    def crearTipoTrabajador(self, nombre: str) -> bool:
        """Crea nuevo tipo de trabajador - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            self.tipoTrabajadorCreado.emit(False, "Usuario no autenticado")
            return False
        
        try:
            self._set_loading(True)
            
            print(f"🏷️ Creando tipo trabajador - Usuario: {self._usuario_actual_id}")
            
            tipo_id = self.repository.create_worker_type(nombre.strip())
            
            if tipo_id:
                # ✅ INVALIDAR CACHÉ Y RECARGAR
                if hasattr(self.repository, 'invalidate_worker_caches'):
                    self.repository.invalidate_worker_caches()
                
                self._cargar_tipos_trabajador()
                
                # ✅ EMITIR SEÑAL GLOBAL PARA OTROS MÓDULOS
                self.global_signals.tiposTrabajadoresModificados.emit()
                
                mensaje = f"Tipo de trabajador creado exitosamente - ID: {tipo_id}"
                self.tipoTrabajadorCreado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo trabajador creado desde QML: {nombre}")
                print(f"📊 Tipos actuales: {len(self._tipos_trabajador)}")
                return True
            else:
                error_msg = "Error creando tipo de trabajador"
                self.tipoTrabajadorCreado.emit(False, error_msg)
                self.errorOccurred.emit("Error de validación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoTrabajadorCreado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, str, result=bool)
    def actualizarTipoTrabajador(self, tipo_id: int, nombre: str) -> bool:
        """Actualiza tipo de trabajador existente - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            self.tipoTrabajadorActualizado.emit(False, "Usuario no autenticado")
            return False
        
        try:
            self._set_loading(True)
            
            print(f"🔄 Actualizando tipo trabajador ID: {tipo_id} por usuario: {self._usuario_actual_id}")
            
            success = self.repository.update_worker_type(tipo_id, nombre.strip())
            
            if success:
                # ✅ INVALIDAR CACHÉ Y RECARGAR
                if hasattr(self.repository, 'invalidate_worker_caches'):
                    self.repository.invalidate_worker_caches()
                
                self._cargar_tipos_trabajador()
                
                # ✅ EMITIR SEÑAL GLOBAL
                self.global_signals.tiposTrabajadoresModificados.emit()
                
                mensaje = "Tipo actualizado exitosamente"
                self.tipoTrabajadorActualizado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo trabajador actualizado desde QML: ID {tipo_id}")
                return True
            else:
                error_msg = "Error actualizando tipo"
                self.tipoTrabajadorActualizado.emit(False, error_msg)
                self.errorOccurred.emit("Error de actualización", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoTrabajadorActualizado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)
    
    @Slot(int, result=bool)
    def eliminarTipoTrabajador(self, tipo_id: int) -> bool:
        """Elimina tipo de trabajador - ✅ CON VERIFICACIÓN DE AUTENTICACIÓN"""
        # ✅ VERIFICAR AUTENTICACIÓN
        if not self._verificar_autenticacion():
            self.tipoTrabajadorEliminado.emit(False, "Usuario no autenticado")
            return False
        
        try:
            self._set_loading(True)
            
            print(f"🗑️ Eliminando tipo trabajador ID: {tipo_id} por usuario: {self._usuario_actual_id}")
            
            # Verificar que no tenga trabajadores asociados
            trabajadores_del_tipo = self.repository.get_workers_by_type(tipo_id)
            if trabajadores_del_tipo:
                error_msg = f"Tipo tiene {len(trabajadores_del_tipo)} trabajadores asociados"
                self.warningMessage.emit(error_msg)
                self.tipoTrabajadorEliminado.emit(False, error_msg)
                return False
            
            success = self.repository.delete_worker_type(tipo_id)
            
            if success:
                # ✅ INVALIDAR CACHÉ Y RECARGAR
                if hasattr(self.repository, 'invalidate_worker_caches'):
                    self.repository.invalidate_worker_caches()
                
                self._cargar_tipos_trabajador()
                
                # ✅ EMITIR SEÑAL GLOBAL
                self.global_signals.tiposTrabajadoresModificados.emit()
                
                mensaje = "Tipo eliminado exitosamente"
                self.tipoTrabajadorEliminado.emit(True, mensaje)
                self.successMessage.emit(mensaje)
                
                print(f"✅ Tipo trabajador eliminado desde QML: ID {tipo_id}")
                return True
            else:
                error_msg = "Error eliminando tipo"
                self.tipoTrabajadorEliminado.emit(False, error_msg)
                self.errorOccurred.emit("Error de eliminación", error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado: {str(e)}"
            self.tipoTrabajadorEliminado.emit(False, error_msg)
            self.errorOccurred.emit("Error crítico", error_msg)
            return False
        finally:
            self._set_loading(False)

    # ===============================
    # SLOTS PARA BÚSQUEDA Y FILTROS
    # ===============================
    
    @Slot(int, str, bool, str)
    def aplicarFiltros(self, tipo_id: int, buscar: str, incluir_stats: bool, area: str):
        """Aplica filtros a la lista de trabajadores"""
        try:
            self._filtro_tipo = tipo_id
            self._filtro_busqueda = buscar.strip()
            self._incluir_stats = incluir_stats
            self._filtro_area = area
            
            # Filtrar datos locales
            trabajadores_filtrados = self._trabajadores.copy()
            
            # Filtro por tipo
            if tipo_id > 0:
                trabajadores_filtrados = [
                    t for t in trabajadores_filtrados
                    if t.get('Id_Tipo_Trabajador') == tipo_id
                ]
            
            # Filtro por búsqueda
            if buscar.strip():
                buscar_lower = buscar.lower()
                trabajadores_filtrados = [
                    t for t in trabajadores_filtrados
                    if (buscar_lower in t.get('Nombre', '').lower() or
                        buscar_lower in t.get('Apellido_Paterno', '').lower() or
                        buscar_lower in t.get('Apellido_Materno', '').lower() or
                        buscar_lower in t.get('tipo_nombre', '').lower())
                ]
            
            # Filtro por área
            if area and area != "Todos":
                area_lower = area.lower()
                trabajadores_filtrados = [
                    t for t in trabajadores_filtrados
                    if area_lower in t.get('tipo_nombre', '').lower()
                ]
            
            self._trabajadores_filtrados = trabajadores_filtrados
            self.trabajadoresChanged.emit()
            
            total = len(trabajadores_filtrados)
            self.busquedaCompleta.emit(True, f"Encontrados {total} trabajadores", total)
            print(f"🔍 Filtros aplicados: {total} trabajadores")
                
        except Exception as e:
            self.errorOccurred.emit("Error en filtros", f"Error aplicando filtros: {str(e)}")
    
    @Slot(str, int, result=list)
    def buscarTrabajadores(self, termino: str, limite: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda rápida de trabajadores"""
        try:
            if not termino.strip():
                return self._trabajadores
            
            trabajadores = self.repository.search_workers(termino.strip(), limite)
            print(f"🔍 Búsqueda '{termino}': {len(trabajadores)} resultados")
            return trabajadores
            
        except Exception as e:
            self.errorOccurred.emit("Error en búsqueda", f"Error buscando trabajadores: {str(e)}")
            return []
    
    @Slot(str, result=list)
    def obtenerTrabajadoresPorArea(self, area: str) -> List[Dict[str, Any]]:
        """Obtiene trabajadores por área específica"""
        try:
            if area == "Todos":
                return self._trabajadores
            
            trabajadores = self.repository.get_workers_by_type_name(area)
            print(f"🏢 Área '{area}': {len(trabajadores)} trabajadores")
            return trabajadores
            
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo trabajadores por área: {str(e)}")
            return []
    
    @Slot()
    def limpiarFiltros(self):
        """Limpia todos los filtros aplicados"""
        self._filtro_tipo = 0
        self._filtro_area = "Todos"
        self._filtro_busqueda = ""
        self._incluir_stats = False
        self._trabajadores_filtrados = self._trabajadores.copy()
        self.trabajadoresChanged.emit()
        print("🧹 Filtros limpiados")

    # ===============================
    # SLOTS PARA CONSULTAS ESPECÍFICAS
    # ===============================
    
    @Slot(int, result='QVariantMap')
    def obtenerTrabajadorPorId(self, trabajador_id: int) -> Dict[str, Any]:
        """Obtiene trabajador específico por ID"""
        try:
            trabajador = self.repository.get_worker_with_type(trabajador_id)
            return trabajador if trabajador else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo trabajador: {str(e)}")
            return {}
    
    @Slot(result=list)
    def obtenerTrabajadoresLaboratorio(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores del área de laboratorio"""
        return self.repository.get_laboratory_workers()
    
    @Slot(result=list)
    def obtenerTrabajadoresFarmacia(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores del área de farmacia"""
        return self.repository.get_pharmacy_workers()
    
    @Slot(result=list)
    def obtenerTrabajadoresEnfermeria(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores del área de enfermería"""
        return self.repository.get_nursing_staff()
    
    @Slot(result=list)
    def obtenerTrabajadoresAdministrativos(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores administrativos"""
        return self.repository.get_administrative_staff()
    
    @Slot(result=list)
    def obtenerTrabajadoresSinAsignaciones(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores sin asignaciones"""
        try:
            return self.repository.get_workers_without_assignments()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo trabajadores sin asignaciones: {str(e)}")
            return []
    
    @Slot(int, result='QVariantMap')
    def obtenerCargaTrabajo(self, trabajador_id: int) -> Dict[str, Any]:
        """Obtiene carga de trabajo de un trabajador"""
        try:
            trabajador = self.repository.get_worker_with_lab_stats(trabajador_id)
            return trabajador if trabajador else {}
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo carga de trabajo: {str(e)}")
            return {}

    # ===============================
    # SLOTS PARA RECARGA DE DATOS
    # ===============================
    
    @Slot()
    def refrescarDatosInmediato(self):
        """Método para refrescar datos inmediatamente desde QML"""
        try:
            print("🔄 Refrescando datos inmediatamente...")
            self._cargar_trabajadores()
            self._cargar_tipos_trabajador()
            
            # Aplicar filtros actuales
            self.aplicarFiltros(self._filtro_tipo, self._filtro_busqueda, 
                            self._incluir_stats, self._filtro_area)
            
            print(f"✅ Datos refrescados: {len(self._trabajadores)} trabajadores")
            
        except Exception as e:
            print(f"❌ Error refrescando datos: {e}")
            self.errorOccurred.emit("Error", f"Error refrescando datos: {str(e)}")
    
    @Slot()
    def recargarDatos(self):
        """Recarga todos los datos desde la base de datos"""
        try:
            self._set_loading(True)
            self._cargar_datos_iniciales()
            self.successMessage.emit("Datos recargados exitosamente")
            print("🔄 Datos de trabajadores recargados desde QML")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando datos: {str(e)}")
        finally:
            self._set_loading(False)
    
    @Slot()
    def recargarTrabajadores(self):
        """Recarga solo la lista de trabajadores"""
        try:
            self._cargar_trabajadores()
            print("🔄 Trabajadores recargados")
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error recargando trabajadores: {str(e)}")

    # ===============================
    # SLOTS PARA UTILIDADES
    # ===============================
    
    @Slot(result=list)
    def obtenerTiposParaComboBox(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de trabajador formateados para ComboBox"""
        try:
            tipos_formateados = []
            
            # Agregar opción "Todos"
            tipos_formateados.append({
                'id': 0,
                'text': 'Todos los tipos',
                'data': {}
            })
            
            # Agregar tipos existentes
            for tipo in self._tipos_trabajador:
                tipos_formateados.append({
                    'id': tipo.get('id', 0),
                    'text': tipo.get('Tipo', 'Sin nombre'),
                    'data': tipo
                })
            
            return tipos_formateados
            
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo tipos: {str(e)}")
            return [{'id': 0, 'text': 'Todos los tipos', 'data': {}}]
    
    @Slot(result=list)
    def obtenerAreasDisponibles(self) -> List[str]:
        """Obtiene lista de áreas disponibles para filtros"""
        return [
            "Todos",
            "Laboratorio", 
            "Farmacia", 
            "Enfermería", 
            "Administrativo", 
            "Técnico", 
            "Salud"
        ]
    
    @Slot(str, str, str, result=str)
    def formatearNombreCompleto(self, nombre: str, apellido_paterno: str, apellido_materno: str = "") -> str:
        """Formatea nombre completo del trabajador"""
        partes = [nombre.strip(), apellido_paterno.strip()]
        
        if apellido_materno and apellido_materno.strip():
            partes.append(apellido_materno.strip())
        
        return " ".join(parte for parte in partes if parte)
    
    @Slot(int, result=str)
    def obtenerNombreTipo(self, tipo_id: int) -> str:
        """Obtiene nombre del tipo por ID"""
        try:
            for tipo in self._tipos_trabajador:
                if tipo.get('id') == tipo_id:
                    return tipo.get('Tipo', 'Desconocido')
            return "Desconocido"
        except Exception:
            return "Desconocido"
        
    @Slot(result=bool)
    def hayTiposDisponibles(self) -> bool:
        """Verifica si hay tipos de trabajador disponibles"""
        return len(self._tipos_trabajador) > 0

    @Slot(result=int)
    def cantidadTipos(self) -> int:
        """Obtiene cantidad de tipos disponibles"""
        return len(self._tipos_trabajador)

    @Slot()
    def forzarActualizacionTipos(self):
        """Fuerza actualización de tipos desde QML"""
        try:
            print("🔄 Forzando actualización de tipos desde QML...")
            
            # Invalidar caché
            if hasattr(self.repository, 'invalidate_worker_caches'):
                self.repository.invalidate_worker_caches()
            
            # Recargar
            self._cargar_tipos_trabajador()
            
            print(f"✅ Tipos actualizados: {len(self._tipos_trabajador)}")
            
        except Exception as e:
            print(f"❌ Error forzando actualización: {e}")
    
    @Slot(result='QVariantMap')
    def obtenerEstadisticasCompletas(self) -> Dict[str, Any]:
        """Obtiene estadísticas completas del sistema"""
        try:
            return self.repository.get_worker_statistics()
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo estadísticas: {str(e)}")
            return {}
    
    @Slot(result='QVariantMap')
    def obtenerDistribucionCarga(self) -> Dict[str, Any]:
        """Obtiene distribución de carga de trabajo"""
        try:
            carga = self.repository.get_laboratory_workload()
            return {
                'trabajadores_laboratorio': carga,
                'total_trabajadores': len(carga),
                'con_asignaciones': len([t for t in carga if t.get('total_examenes', 0) > 0])
            }
        except Exception as e:
            self.errorOccurred.emit("Error", f"Error obteniendo distribución: {str(e)}")
            return {}

    # ===============================
    # MÉTODOS PRIVADOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga todos los datos necesarios al inicializar - CON DEBUG"""
        self._log_call("_cargar_datos_iniciales", "INICIO")
        
        try:
            self._cargar_trabajadores()
            self._cargar_tipos_trabajador()
            self._cargar_estadisticas()
            print("📊 Datos iniciales de trabajadores cargados")
        except Exception as e:
            print(f"❌ Error cargando datos iniciales: {e}")
            self.errorOccurred.emit("Error inicial", f"Error cargando datos: {str(e)}")
        
        self._log_call("_cargar_datos_iniciales", "FIN")
    
    def _cargar_trabajadores(self):
        """Carga lista de trabajadores desde el repository"""
        try:
            trabajadores = self.repository.get_all_with_types()
            
            # Agregar nombre completo
            for trabajador in trabajadores:
                trabajador['nombre_completo'] = f"{trabajador.get('Nombre', '')} {trabajador.get('Apellido_Paterno', '')} {trabajador.get('Apellido_Materno', '')}"
            
            self._trabajadores = trabajadores
            self._trabajadores_filtrados = trabajadores.copy()
            self.trabajadoresChanged.emit()
            print(f"👷‍♂️ Trabajadores cargados: {len(trabajadores)}")
                
        except Exception as e:
            print(f"❌ Error cargando trabajadores: {e}")
            self._trabajadores = []
            self._trabajadores_filtrados = []
            raise e
    
    def _cargar_tipos_trabajador(self):
        """Carga lista de tipos de trabajador desde el repository"""
        try:
            tipos = self.repository.get_all_worker_types()
            
            # ✅ VERIFICAR QUE SEA UNA LISTA VÁLIDA
            if not isinstance(tipos, list):
                print(f"⚠️ get_all_worker_types no retornó lista: {type(tipos)}")
                tipos = []
            
            self._tipos_trabajador = tipos
            
            # ✅ EMITIR SEÑAL SIEMPRE
            self.tiposTrabajadorChanged.emit()
            
            # ✅ LOG DETALLADO
            print(f"🏷️ Tipos de trabajador cargados: {len(self._tipos_trabajador)}")
            if self._tipos_trabajador:
                print(f"   Tipos: {[t.get('Tipo', 'N/A') for t in self._tipos_trabajador[:3]]}")
            else:
                print("   ⚠️ Lista de tipos está vacía")
                
        except Exception as e:
            print(f"❌ Error cargando tipos de trabajador: {e}")
            import traceback
            traceback.print_exc()
            self._tipos_trabajador = []
            # ✅ EMITIR SEÑAL INCLUSO SI FALLA (para limpiar UI)
            self.tiposTrabajadorChanged.emit()
    
    def _cargar_estadisticas(self):
        """Carga estadísticas desde el repository"""
        try:
            estadisticas = self.repository.get_worker_statistics()
            self._estadisticas = estadisticas
            self.estadisticasChanged.emit()
            print("📈 Estadísticas de trabajadores cargadas")
        except Exception as e:
            print(f"❌ Error cargando estadísticas: {e}")
            # No es crítico, continuar sin estadísticas
            self._estadisticas = {}
    
    def _set_loading(self, loading: bool):
        """Actualiza estado de carga"""
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()
    
    @Slot()
    def _actualizar_tipos_trabajadores_desde_signal(self):
        """Actualiza tipos desde señal - CON DEBUG"""
        self._log_call("_actualizar_tipos_trabajadores_desde_signal", "SIGNAL")
        
        try:
            print("📡 Actualizando tipos desde señal global")
            if hasattr(self.repository, 'invalidate_worker_caches'):
                self.repository.invalidate_worker_caches()
            self._cargar_tipos_trabajador()
        except Exception as e:
            print(f"❌ Error actualizando tipos: {e}")

    @Slot(str)
    def _manejar_actualizacion_global(self, mensaje: str):
        """Maneja actualizaciones globales - CON DEBUG"""
        self._log_call("_manejar_actualizacion_global", f"MSG: {mensaje[:30]}")
        
        try:
            print(f"📡 Manejo global: {mensaje}")
            self.tiposTrabajadorChanged.emit()
        except Exception as e:
            print(f"❌ Error manejando actualización: {e}")

    def emergency_disconnect(self):
        """Desconexión de emergencia - SIN RESETEAR AUTENTICACIÓN"""
        self._log_call("emergency_disconnect", "INICIO")
        
        try:
            print("🚨 Emergency disconnect iniciado")
            
            # Desconectar señales sin tocar autenticación
            signals_to_disconnect = [
                'trabajadoresChanged', 'tiposTrabajadorChanged', 'estadisticasChanged',
                'trabajadorCreado', 'trabajadorActualizado', 'trabajadorEliminado'
            ]
            
            for signal_name in signals_to_disconnect:
                if hasattr(self, signal_name):
                    try:
                        getattr(self, signal_name).disconnect()
                    except:
                        pass
            
            # Limpiar datos SIN tocar autenticación
            self._trabajadores = []
            self._trabajadores_filtrados = []
            self._tipos_trabajador = []
            
            # ✅ NO RESETEAR AUTENTICACIÓN EN EMERGENCY_DISCONNECT
            # self._usuario_actual_id = 0  # ← COMENTADO
            # self._usuario_actual_rol = ""  # ← COMENTADO
            
            print("✅ Emergency disconnect completado SIN resetear auth")
            
        except Exception as e:
            print(f"❌ Error en emergency disconnect: {e}")
        
        self._log_call("emergency_disconnect", "FIN")

# ===============================
# REGISTRO PARA QML
# ===============================

def register_trabajador_model():
    """Registra el TrabajadorModel para uso en QML"""
    qmlRegisterType(TrabajadorModel, "ClinicaModels", 1, 0, "TrabajadorModel")
    print("🔗 TrabajadorModel registrado para QML con autenticación estandarizada")

# Para facilitar la importación
__all__ = ['TrabajadorModel', 'register_trabajador_model']