from PySide6.QtCore import QObject, Property, Signal, Slot
from PySide6.QtQml import qmlRegisterType
from typing import List, Dict, Any, Optional

from ..repositories.ingreso_extra_repository import IngresoExtraRepository

class IngresoExtraModel(QObject):
    """Model QObject para gestión de Ingresos Extras"""
    
    # Señales
    ingresoExtraAgregado = Signal()
    ingresoExtraActualizado = Signal()
    ingresoExtraEliminado = Signal()
    errorOcurrido = Signal(str)
    datosCambiados = Signal()
    ingresosActualizados = Signal() 
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.repository = IngresoExtraRepository()
        self._usuario_actual_id = 0
        self._usuario_actual_rol = ""
        
        # ✅ NUEVO: Lista de ingresos
        self._ingresos = []
        
        print("💰 IngresoExtraModel inicializado")
        
        # ✅ CARGAR DATOS INICIALES
        self._cargar_datos_iniciales()
    
    # ===============================
    # PROPIEDADES PARA QML
    # ===============================
    
    @Property(int, notify=datosCambiados)
    def usuario_actual_id(self):
        return self._usuario_actual_id
    
    @Property(str, notify=datosCambiados)
    def usuario_actual_rol(self):
        return self._usuario_actual_rol
    
    @Property(list, notify=ingresosActualizados)
    def ingresos(self):
        """✅ NUEVA propiedad: Lista de ingresos para QML"""
        return self._ingresos
    
    # ===============================
    # MÉTODOS DE CARGA DE DATOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga los datos iniciales del modelo"""
        try:
            print("📊 IngresoExtraModel: Cargando datos iniciales...")
            self.cargar_ingresos()
            print("✅ IngresoExtraModel: Datos iniciales cargados")
        except Exception as e:
            error_msg = f"Error cargando datos iniciales: {str(e)}"
            print(f"❌ {error_msg}")
            self.errorOcurrido.emit(error_msg)
    
    @Slot()
    def cargar_ingresos(self):
        """✅ NUEVO: Carga todos los ingresos extras"""
        try:
            print("📋 Cargando ingresos extras desde BD...")
            
            success, result = self.repository.obtener_todos_ingresos_extras()
            
            if success:
                self._ingresos = result
                print(f"✅ Ingresos extras cargados: {len(self._ingresos)}")
                
                # Debug detallado
                if len(self._ingresos) == 0:
                    print("⚠️ La tabla IngresosExtras está vacía (sin registros)")
                else:
                    print(f"📊 Primeros ingresos:")
                    for i, ingreso in enumerate(self._ingresos[:3]):  # Mostrar primeros 3
                        print(f"   {i+1}. ID: {ingreso.get('id')}, "
                              f"Descripción: {ingreso.get('descripcion')}, "
                              f"Monto: {ingreso.get('monto')}")
                
                self.ingresosActualizados.emit()
                return True
            else:
                error_msg = f"Error al obtener ingresos: {result}"
                print(f"❌ {error_msg}")
                self.errorOcurrido.emit(error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado cargando ingresos: {str(e)}"
            print(f"❌ {error_msg}")
            self.errorOcurrido.emit(error_msg)
            return False
    
    # ===============================
    # MÉTODOS DE AUTENTICACIÓN
    # ===============================
    
    @Slot(int, str)
    def set_usuario_actual_con_rol(self, usuario_id: int, usuario_rol: str):
        """Establece el usuario autenticado actual con su rol"""
        try:
            print(f"👤 Usuario establecido en IngresoExtraModel: ID={usuario_id}, Rol={usuario_rol}")
            self._usuario_actual_id = usuario_id
            self._usuario_actual_rol = usuario_rol
            self.datosCambiados.emit()
            
            # Recargar ingresos después de establecer usuario
            self.cargar_ingresos()
            
        except Exception as e:
            error_msg = f"Error estableciendo usuario en IngresoExtraModel: {str(e)}"
            print(f"❌ {error_msg}")
            self.errorOcurrido.emit(error_msg)
    
    # ===============================
    # OPERACIONES CRUD
    # ===============================
    
    @Slot(str, float, str, result=bool)
    def agregar_ingreso_extra(self, descripcion: str, monto: float, fecha: str) -> bool:
        """✅ MEJORADO: Agrega un nuevo ingreso extra con debug"""
        try:
            print(f"➕ Intentando agregar ingreso extra:")
            print(f"   Descripción: {descripcion}")
            print(f"   Monto: {monto}")
            print(f"   Fecha: {fecha}")
            print(f"   Usuario ID: {self._usuario_actual_id}")
            
            # Validación de usuario
            if self._usuario_actual_id <= 0:
                error_msg = "Usuario no autenticado. Por favor inicie sesión."
                print(f"❌ {error_msg}")
                self.errorOcurrido.emit(error_msg)
                return False
            
            # Validación de datos
            if not descripcion or descripcion.strip() == "":
                error_msg = "La descripción es requerida"
                print(f"❌ {error_msg}")
                self.errorOcurrido.emit(error_msg)
                return False
            
            if monto <= 0:
                error_msg = "El monto debe ser mayor a 0"
                print(f"❌ {error_msg}")
                self.errorOcurrido.emit(error_msg)
                return False
            
            # Intentar agregar
            success, result = self.repository.agregar_ingreso_extra(
                descripcion.strip(), 
                monto, 
                fecha, 
                self._usuario_actual_id
            )
            
            if success:
                print(f"✅ Ingreso extra agregado exitosamente")
                # Recargar ingresos
                self.cargar_ingresos()
                self.ingresoExtraAgregado.emit()
                return True
            else:
                error_msg = f"Error al agregar ingreso: {result}"
                print(f"❌ {error_msg}")
                self.errorOcurrido.emit(error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado al agregar ingreso: {str(e)}"
            print(f"❌ {error_msg}")
            import traceback
            traceback.print_exc()
            self.errorOcurrido.emit(error_msg)
            return False
    
    @Slot(int, str, float, str, result=bool)
    def actualizar_ingreso_extra(self, id_ingreso: int, descripcion: str, monto: float, fecha: str) -> bool:
        """Actualiza un ingreso extra existente"""
        try:
            print(f"✏️ Actualizando ingreso ID: {id_ingreso}")
            
            if not descripcion or monto <= 0:
                self.errorOcurrido.emit("Descripción y monto son requeridos")
                return False
            
            success, result = self.repository.actualizar_ingreso_extra(
                id_ingreso, descripcion.strip(), monto, fecha
            )
            
            if success:
                print(f"✅ Ingreso extra actualizado ID: {id_ingreso}")
                self.cargar_ingresos()
                self.ingresoExtraActualizado.emit()
                return True
            else:
                error_msg = f"Error al actualizar ingreso: {result}"
                print(f"❌ {error_msg}")
                self.errorOcurrido.emit(error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado al actualizar ingreso: {str(e)}"
            print(f"❌ {error_msg}")
            self.errorOcurrido.emit(error_msg)
            return False
    
    @Slot(int, result=bool)
    def eliminar_ingreso_extra(self, id_ingreso: int) -> bool:
        """Elimina un ingreso extra"""
        try:
            print(f"🗑️ Eliminando ingreso ID: {id_ingreso}")
            
            success, result = self.repository.eliminar_ingreso_extra(id_ingreso)
            
            if success:
                print(f"✅ Ingreso extra eliminado ID: {id_ingreso}")
                self.cargar_ingresos()
                self.ingresoExtraEliminado.emit()
                return True
            else:
                error_msg = f"Error al eliminar ingreso: {result}"
                print(f"❌ {error_msg}")
                self.errorOcurrido.emit(error_msg)
                return False
                
        except Exception as e:
            error_msg = f"Error inesperado al eliminar ingreso: {str(e)}"
            print(f"❌ {error_msg}")
            self.errorOcurrido.emit(error_msg)
            return False
    
    # ===============================
    # CONSULTAS Y FILTROS
    # ===============================
    
    @Slot(result="QVariantList")
    def obtener_todos_ingresos_extras(self) -> List[Dict[str, Any]]:
        """Obtiene todos los ingresos extras"""
        return self._ingresos
    
    @Slot(int, int, result="QVariantList")
    def obtener_ingresos_extras_paginados(self, pagina: int, items_por_pagina: int) -> List[Dict[str, Any]]:
        """Obtiene ingresos extras paginados"""
        try:
            success, result = self.repository.obtener_ingresos_extras_paginados(
                pagina, items_por_pagina
            )
            
            if success:
                return result
            else:
                self.errorOcurrido.emit(f"Error al obtener ingresos paginados: {result}")
                return []
                
        except Exception as e:
            error_msg = f"Error inesperado al obtener ingresos paginados: {str(e)}"
            print(error_msg)
            self.errorOcurrido.emit(error_msg)
            return []
    
    @Slot(int, int, result=int)
    def contar_ingresos_extras(self, mes: int = 0, anio: int = 0) -> int:
        """Cuenta el total de ingresos extras, opcionalmente filtrados por mes y año"""
        try:
            success, result = self.repository.contar_ingresos_extras(mes, anio)
            
            if success:
                return result
            else:
                self.errorOcurrido.emit(f"Error al contar ingresos: {result}")
                return 0
                
        except Exception as e:
            error_msg = f"Error inesperado al contar ingresos: {str(e)}"
            print(error_msg)
            self.errorOcurrido.emit(error_msg)
            return 0
    
    @Slot(int, int, int, int, result="QVariantList")
    def obtener_ingresos_extras_filtrados(self, mes: int, anio: int, pagina: int, items_por_pagina: int) -> List[Dict[str, Any]]:
        """Obtiene ingresos extras filtrados por mes y año"""
        try:
            success, result = self.repository.obtener_ingresos_extras_filtrados(
                mes, anio, pagina, items_por_pagina
            )
            
            if success:
                return result
            else:
                self.errorOcurrido.emit(f"Error al obtener ingresos filtrados: {result}")
                return []
                
        except Exception as e:
            error_msg = f"Error inesperado al obtener ingresos filtrados: {str(e)}"
            print(error_msg)
            self.errorOcurrido.emit(error_msg)
            return []
    
    @Slot(int, int, result=float)
    def obtener_total_ingresos_mes(self, mes: int, anio: int) -> float:
        """Obtiene el total de ingresos extras de un mes específico"""
        try:
            success, result = self.repository.obtener_total_ingresos_mes(mes, anio)
            
            if success:
                return result
            else:
                self.errorOcurrido.emit(f"Error al obtener total de ingresos: {result}")
                return 0.0
                
        except Exception as e:
            error_msg = f"Error inesperado al obtener total de ingresos: {str(e)}"
            print(error_msg)
            self.errorOcurrido.emit(error_msg)
            return 0.0
    
    # ===============================
    # MÉTODOS AUXILIARES
    # ===============================
    
    @Slot(result=bool)
    def verificar_conexion(self) -> bool:
        """✅ NUEVO: Verifica la conexión con la base de datos"""
        try:
            print("🔍 Verificando conexión a BD...")
            result = self.repository.verificar_conexion()
            
            if result:
                print("✅ Conexión a BD: OK")
            else:
                print("❌ Conexión a BD: FALLO")
                
            return result
        except Exception as e:
            print(f"❌ Error verificando conexión: {e}")
            return False
    
    @Slot()
    def limpiar_cache(self):
        """Limpia la caché del repositorio"""
        try:
            self.repository.limpiar_cache()
            print("✅ Cache de ingresos extras limpiado")
        except Exception as e:
            print(f"❌ Error limpiando cache: {e}")
    
    @Slot()
    def refrescar(self):
        """✅ NUEVO: Refresca los datos manualmente"""
        print("🔄 Refrescando ingresos extras...")
        self.cargar_ingresos()

def register_ingreso_extra_model():
    """Registra el IngresoExtraModel para uso en QML"""
    qmlRegisterType(IngresoExtraModel, "ClinicaModels", 1, 0, "IngresoExtraModel")
    print("🔗 IngresoExtraModel registrado para QML")

# Para facilitar importación
__all__ = ['IngresoExtraModel', 'register_ingreso_extra_model']