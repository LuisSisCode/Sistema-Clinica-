"""
Servicio de lógica de negocio para gastos
Maneja validaciones complejas, reglas de negocio y coordinación entre repositories
"""

from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta, date
from decimal import Decimal, ROUND_HALF_UP
import json

from ..repositories.gasto_repository import GastoRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, safe_execute, validate_required, 
    validate_positive_number, ClinicaBaseException
)
from ..core.config import Config
from ..core.utils import (
    formatear_precio, parsear_fecha, formatear_fecha, es_fecha_valida,
    preparar_para_qml, crear_respuesta_qml, limpiar_texto,
    safe_float, safe_int, is_empty, medir_tiempo_ejecucion,
    calcular_porcentaje, fecha_actual_str, fecha_actual_hora_str
)

class GastoError(ClinicaBaseException):
    """Error específico en proceso de gastos"""
    def __init__(self, message: str, gasto_id: int = None, tipo_gasto_id: int = None):
        details = {"gasto_id": gasto_id, "tipo_gasto_id": tipo_gasto_id}
        super().__init__(message, "GASTO_ERROR", details)

class GastoService:
    """
    Servicio de lógica de negocio para gastos
    Implementa validaciones complejas y reglas de negocio
    """
    
    def __init__(self):
        self.gasto_repo = GastoRepository()
        
        # Configuraciones de negocio
        self.monto_minimo_gasto = 1.0  # Monto mínimo para registrar gasto
        self.monto_maximo_gasto = 100000.0  # Límite máximo por gasto individual
        self.dias_edicion_permitidos = 30  # Días para editar gastos después de creación
        self.limite_gastos_diarios = 50  # Máximo gastos por día por usuario
        self.presupuesto_default_mensual = 50000.0  # Presupuesto default mensual
        
        # Categorías de alerta por monto
        self.monto_alerta_media = 1000.0  # Gastos > 1000 requieren justificación
        self.monto_alerta_alta = 5000.0   # Gastos > 5000 requieren aprobación especial
        
        print("💸 GastoService inicializado con validaciones de negocio")
    
    # ===============================
    # VALIDACIONES DE NEGOCIO
    # ===============================
    
    def validar_gasto(self, gasto_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Valida un gasto con reglas de negocio
        
        Returns:
            {
                'valido': bool,
                'errores': List[str],
                'advertencias': List[str],
                'gasto_validado': Dict
            }
        """
        errores = []
        advertencias = []
        gasto_validado = {}
        
        # Extraer y validar campos básicos
        tipo_gasto_id = safe_int(gasto_data.get('tipo_gasto_id', 0))
        monto = safe_float(gasto_data.get('monto', 0))
        descripcion = gasto_data.get('descripcion', '').strip()
        fecha_gasto_str = gasto_data.get('fecha_gasto', '').strip()
        usuario_id = safe_int(gasto_data.get('usuario_id', 0))
        
        # Validación de tipo de gasto
        if tipo_gasto_id <= 0:
            errores.append("Tipo de gasto requerido")
        else:
            # Verificar que el tipo existe
            try:
                tipo_existe = safe_execute(
                    self.gasto_repo._expense_type_exists, 
                    tipo_gasto_id
                )
                if not tipo_existe:
                    errores.append("Tipo de gasto no válido")
                else:
                    gasto_validado['tipo_gasto_id'] = tipo_gasto_id
            except Exception:
                errores.append("Error validando tipo de gasto")
        
        # Validación de monto
        if monto < self.monto_minimo_gasto:
            errores.append(f"Monto mínimo: {formatear_precio(self.monto_minimo_gasto)}")
        elif monto > self.monto_maximo_gasto:
            errores.append(f"Monto excede límite máximo: {formatear_precio(self.monto_maximo_gasto)}")
        else:
            gasto_validado['monto'] = monto
            
            # Advertencias por montos altos
            if monto >= self.monto_alerta_alta:
                advertencias.append(f"Gasto muy alto ({formatear_precio(monto)}) - Requiere justificación especial")
            elif monto >= self.monto_alerta_media:
                advertencias.append(f"Gasto considerable ({formatear_precio(monto)}) - Verificar justificación")
        
        # Validación de descripción
        if not descripcion or len(descripcion) < 10:
            errores.append("Descripción debe tener al menos 10 caracteres")
        elif len(descripcion) > 500:
            errores.append("Descripción muy larga (máximo 500 caracteres)")
        else:
            gasto_validado['descripcion'] = limpiar_texto(descripcion)
        
        # Validación de fecha
        if not fecha_gasto_str:
            # Usar fecha actual si no se especifica
            gasto_validado['fecha_gasto'] = datetime.now()
            advertencias.append("Usando fecha actual para el gasto")
        elif not es_fecha_valida(fecha_gasto_str):
            errores.append("Formato de fecha inválido")
        else:
            fecha_gasto = parsear_fecha(fecha_gasto_str)
            
            # Validar que la fecha no sea futura
            if fecha_gasto.date() > date.today():
                errores.append("La fecha del gasto no puede ser futura")
            # Validar que no sea muy antigua (más de 1 año)
            elif (date.today() - fecha_gasto.date()).days > 365:
                advertencias.append("Gasto registrado con fecha muy antigua")
                gasto_validado['fecha_gasto'] = fecha_gasto
            else:
                gasto_validado['fecha_gasto'] = fecha_gasto
        
        # Validación de usuario
        if usuario_id <= 0:
            errores.append("Usuario no especificado")
        else:
            # Verificar que el usuario existe
            try:
                usuario_existe = safe_execute(
                    self.gasto_repo._user_exists, 
                    usuario_id
                )
                if not usuario_existe:
                    errores.append("Usuario no válido")
                else:
                    gasto_validado['usuario_id'] = usuario_id
            except Exception:
                errores.append("Error validando usuario")
        
        return {
            'valido': len(errores) == 0,
            'errores': errores,
            'advertencias': advertencias,
            'gasto_validado': gasto_validado
        }
    
    def validar_limite_gastos_diarios(self, usuario_id: int, fecha: datetime) -> bool:
        """Valida que el usuario no exceda el límite de gastos diarios"""
        try:
            gastos_hoy = safe_execute(
                self.gasto_repo.get_expenses_by_user,
                usuario_id,
                100
            )
            
            if gastos_hoy:
                # Filtrar gastos del día
                gastos_fecha = [
                    g for g in gastos_hoy 
                    if g.get('Fecha') and g['Fecha'].date() == fecha.date()
                ]
                
                return len(gastos_fecha) < self.limite_gastos_diarios
            
            return True
            
        except Exception:
            return True  # En caso de error, permitir el gasto
    
    def validar_presupuesto_mensual(self, tipo_gasto_id: int, monto: float, 
                                  fecha: datetime) -> Dict[str, Any]:
        """Valida gasto contra presupuesto mensual del tipo"""
        try:
            # Obtener gastos del mes para este tipo
            año = fecha.year
            mes = fecha.month
            
            gastos_mes = safe_execute(
                self.gasto_repo.get_expenses_by_type,
                tipo_gasto_id,
                1000
            )
            
            if gastos_mes:
                # Filtrar por mes actual
                gastos_mes_actual = [
                    g for g in gastos_mes 
                    if g.get('Fecha') and 
                       g['Fecha'].year == año and 
                       g['Fecha'].month == mes
                ]
                
                total_mes = sum(safe_float(g.get('Monto', 0)) for g in gastos_mes_actual)
                nuevo_total = total_mes + monto
                
                # Por ahora usar presupuesto default (en futuro puede venir de configuración)
                presupuesto_tipo = self.presupuesto_default_mensual / 6  # Dividir entre tipos comunes
                
                porcentaje_usado = (nuevo_total / presupuesto_tipo) * 100
                
                return {
                    'valido': nuevo_total <= presupuesto_tipo,
                    'total_mes_actual': total_mes,
                    'nuevo_total': nuevo_total,
                    'presupuesto': presupuesto_tipo,
                    'porcentaje_usado': porcentaje_usado,
                    'excede_presupuesto': nuevo_total > presupuesto_tipo
                }
            
            return {
                'valido': True,
                'total_mes_actual': 0,
                'nuevo_total': monto,
                'presupuesto': self.presupuesto_default_mensual / 6,
                'porcentaje_usado': (monto / (self.presupuesto_default_mensual / 6)) * 100,
                'excede_presupuesto': False
            }
            
        except Exception as e:
            print(f"⚠️ Error validando presupuesto: {e}")
            return {'valido': True}  # En caso de error, permitir el gasto
    
    # ===============================
    # GESTIÓN DE GASTOS
    # ===============================
    
    @ExceptionHandler.handle_exception
    @medir_tiempo_ejecucion
    def crear_gasto(self, tipo_gasto_id: int, monto: float, usuario_id: int,
                   descripcion: str, fecha_gasto: str = None, 
                   validar_presupuesto: bool = True) -> Dict[str, Any]:
        """
        Crea nuevo gasto con validaciones completas
        
        Args:
            tipo_gasto_id: ID del tipo de gasto
            monto: Monto del gasto
            usuario_id: ID del usuario responsable
            descripcion: Descripción del gasto
            fecha_gasto: Fecha del gasto (opcional, por defecto ahora)
            validar_presupuesto: Si validar contra presupuesto
        
        Returns:
            Información completa del gasto creado
        """
        print(f"💸 Iniciando creación de gasto - Tipo: {tipo_gasto_id}, Monto: {formatear_precio(monto)}")
        
        # 1. Preparar datos para validación
        gasto_data = {
            'tipo_gasto_id': tipo_gasto_id,
            'monto': monto,
            'descripcion': descripcion,
            'fecha_gasto': fecha_gasto or fecha_actual_str(),
            'usuario_id': usuario_id
        }
        
        # 2. Validación completa
        validacion = self.validar_gasto(gasto_data)
        
        if not validacion['valido']:
            raise GastoError(
                f"Gasto inválido: {'; '.join(validacion['errores'])}",
                tipo_gasto_id=tipo_gasto_id
            )
        
        gasto_validado = validacion['gasto_validado']
        fecha_gasto_obj = gasto_validado['fecha_gasto']
        
        # 3. Validaciones adicionales de negocio
        if not self.validar_limite_gastos_diarios(usuario_id, fecha_gasto_obj):
            raise GastoError(
                f"Límite diario de gastos excedido ({self.limite_gastos_diarios})",
                tipo_gasto_id=tipo_gasto_id
            )
        
        # 4. Validar presupuesto si se requiere
        validacion_presupuesto = {}
        if validar_presupuesto:
            validacion_presupuesto = self.validar_presupuesto_mensual(
                tipo_gasto_id, monto, fecha_gasto_obj
            )
            
            if validacion_presupuesto.get('excede_presupuesto', False):
                advertencia = f"Gasto excede presupuesto mensual ({formatear_precio(validacion_presupuesto['presupuesto'])})"
                validacion['advertencias'].append(advertencia)
                print(f"⚠️ {advertencia}")
        
        # 5. Crear en repository
        gasto_id = safe_execute(
            self.gasto_repo.create_expense,
            tipo_gasto_id,
            monto,
            usuario_id,
            fecha_gasto_obj,
            descripcion
        )
        
        if not gasto_id:
            raise GastoError("Error creando gasto en repository")
        
        # 6. Obtener gasto completo creado
        gasto_completo = safe_execute(
            self.gasto_repo.get_expense_by_id_complete,
            gasto_id
        )
        
        print(f"✅ Gasto creado exitosamente - ID: {gasto_id}, Monto: {formatear_precio(monto)}")
        
        # 7. Preparar respuesta completa
        return crear_respuesta_qml(
            True,
            f"Gasto registrado correctamente - {formatear_precio(monto)}",
            {
                'gasto': preparar_para_qml(gasto_completo),
                'validacion': validacion,
                'presupuesto': validacion_presupuesto,
                'estadisticas_impacto': self._calcular_impacto_gasto(gasto_completo)
            }
        )
    
    @ExceptionHandler.handle_exception
    def actualizar_gasto(self, gasto_id: int, **kwargs) -> Dict[str, Any]:
        """
        Actualiza gasto existente con validaciones
        
        Args:
            gasto_id: ID del gasto a actualizar
            **kwargs: Campos a actualizar (monto, tipo_gasto_id, fecha)
        """
        print(f"💸 Actualizando gasto ID: {gasto_id}")
        
        # 1. Verificar que el gasto existe y obtener datos actuales
        gasto_actual = safe_execute(
            self.gasto_repo.get_expense_by_id_complete,
            gasto_id
        )
        
        if not gasto_actual:
            raise GastoError(f"Gasto {gasto_id} no encontrado", gasto_id=gasto_id)
        
        # 2. Verificar si se puede editar (fecha de creación)
        fecha_creacion = gasto_actual.get('Fecha')
        if fecha_creacion:
            dias_desde_creacion = (datetime.now() - fecha_creacion).days
            if dias_desde_creacion > self.dias_edicion_permitidos:
                raise GastoError(
                    f"Gasto muy antiguo para editar ({dias_desde_creacion} días)",
                    gasto_id=gasto_id
                )
        
        # 3. Preparar datos actualizados
        datos_actualizacion = {}
        validaciones = []
        
        # Validar monto si se actualiza
        if 'monto' in kwargs:
            nuevo_monto = safe_float(kwargs['monto'])
            if nuevo_monto < self.monto_minimo_gasto:
                raise ValidationError("monto", nuevo_monto, f"Mínimo {formatear_precio(self.monto_minimo_gasto)}")
            elif nuevo_monto > self.monto_maximo_gasto:
                raise ValidationError("monto", nuevo_monto, f"Máximo {formatear_precio(self.monto_maximo_gasto)}")
            else:
                datos_actualizacion['monto'] = nuevo_monto
                validaciones.append(f"Monto actualizado: {formatear_precio(nuevo_monto)}")
        
        # Validar tipo de gasto si se actualiza
        if 'tipo_gasto_id' in kwargs:
            nuevo_tipo = safe_int(kwargs['tipo_gasto_id'])
            if not safe_execute(self.gasto_repo._expense_type_exists, nuevo_tipo):
                raise ValidationError("tipo_gasto_id", nuevo_tipo, "Tipo de gasto no válido")
            else:
                datos_actualizacion['tipo_gasto_id'] = nuevo_tipo
                validaciones.append(f"Tipo actualizado a ID: {nuevo_tipo}")
        
        # Validar fecha si se actualiza
        if 'fecha' in kwargs:
            nueva_fecha_str = kwargs['fecha']
            if nueva_fecha_str and es_fecha_valida(nueva_fecha_str):
                nueva_fecha = parsear_fecha(nueva_fecha_str)
                if nueva_fecha.date() <= date.today():
                    datos_actualizacion['fecha'] = nueva_fecha
                    validaciones.append(f"Fecha actualizada: {formatear_fecha(nueva_fecha)}")
                else:
                    raise ValidationError("fecha", nueva_fecha_str, "La fecha no puede ser futura")
            elif nueva_fecha_str:
                raise ValidationError("fecha", nueva_fecha_str, "Formato de fecha inválido")
        
        # 4. Actualizar en repository
        if datos_actualizacion:
            success = safe_execute(
                self.gasto_repo.update_expense,
                gasto_id,
                **datos_actualizacion
            )
            
            if not success:
                raise GastoError(f"Error actualizando gasto {gasto_id}", gasto_id=gasto_id)
        
        # 5. Obtener gasto actualizado
        gasto_actualizado = safe_execute(
            self.gasto_repo.get_expense_by_id_complete,
            gasto_id
        )
        
        print(f"✅ Gasto actualizado - ID: {gasto_id}")
        
        return crear_respuesta_qml(
            True,
            f"Gasto actualizado correctamente - {'; '.join(validaciones)}",
            {
                'gasto': preparar_para_qml(gasto_actualizado),
                'cambios': validaciones,
                'gasto_anterior': preparar_para_qml(gasto_actual)
            }
        )
    
    @ExceptionHandler.handle_exception
    def eliminar_gasto(self, gasto_id: int, usuario_id: int) -> Dict[str, Any]:
        """
        Elimina gasto con validaciones de permisos
        """
        print(f"🗑️ Eliminando gasto ID: {gasto_id}")
        
        # 1. Verificar que el gasto existe
        gasto = safe_execute(
            self.gasto_repo.get_expense_by_id_complete,
            gasto_id
        )
        
        if not gasto:
            raise GastoError(f"Gasto {gasto_id} no encontrado", gasto_id=gasto_id)
        
        # 2. Verificar permisos (solo el usuario que lo creó puede eliminarlo)
        usuario_gasto = safe_execute(
            self.gasto_repo.get_expense_user,
            gasto_id
        )
        
        if usuario_gasto and usuario_gasto.get('id') != usuario_id:
            raise GastoError(
                "Sin permisos para eliminar este gasto", 
                gasto_id=gasto_id
            )
        
        # 3. Verificar tiempo límite para eliminación
        fecha_creacion = gasto.get('Fecha')
        if fecha_creacion:
            dias_desde_creacion = (datetime.now() - fecha_creacion).days
            if dias_desde_creacion > self.dias_edicion_permitidos:
                raise GastoError(
                    f"Gasto muy antiguo para eliminar ({dias_desde_creacion} días)",
                    gasto_id=gasto_id
                )
        
        # 4. Eliminar del repository
        success = safe_execute(
            self.gasto_repo.delete,
            gasto_id
        )
        
        if not success:
            raise GastoError(f"Error eliminando gasto {gasto_id}", gasto_id=gasto_id)
        
        print(f"✅ Gasto eliminado - ID: {gasto_id}")
        
        return crear_respuesta_qml(
            True,
            f"Gasto eliminado correctamente - {formatear_precio(gasto.get('Monto', 0))}",
            {
                'gasto_eliminado': preparar_para_qml(gasto),
                'fecha_eliminacion': fecha_actual_hora_str()
            }
        )
    
    def _calcular_impacto_gasto(self, gasto: Dict[str, Any]) -> Dict[str, Any]:
        """Calcula el impacto del gasto en estadísticas"""
        try:
            monto = safe_float(gasto.get('Monto', 0))
            tipo_id = safe_int(gasto.get('tipo_id', 0))
            
            # Obtener estadísticas del tipo
            estadisticas_tipo = safe_execute(
                self.gasto_repo.get_expense_type_by_id,
                tipo_id
            )
            
            if estadisticas_tipo:
                total_tipo = safe_float(estadisticas_tipo.get('monto_total', 0))
                porcentaje_del_tipo = calcular_porcentaje(monto, total_tipo) if total_tipo > 0 else 100
                
                return {
                    'porcentaje_del_tipo': porcentaje_del_tipo,
                    'es_gasto_grande': monto >= self.monto_alerta_media,
                    'requiere_justificacion': monto >= self.monto_alerta_alta,
                    'nuevo_total_tipo': total_tipo,
                    'nuevo_total_tipo_formateado': formatear_precio(total_tipo)
                }
            
            return {}
            
        except Exception:
            return {}
    
    # ===============================
    # GESTIÓN DE TIPOS DE GASTOS
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_tipo_gasto(self, nombre: str, validar_duplicados: bool = True) -> Dict[str, Any]:
        """
        Crea nuevo tipo de gasto con validaciones
        
        Args:
            nombre: Nombre del tipo de gasto
            validar_duplicados: Si validar nombres duplicados
        """
        print(f"💰 Creando tipo de gasto: {nombre}")
        
        # 1. Validaciones básicas
        if not nombre or len(nombre.strip()) < 3:
            raise ValidationError("nombre", nombre, "Mínimo 3 caracteres")
        
        if len(nombre.strip()) > 100:
            raise ValidationError("nombre", nombre, "Máximo 100 caracteres")
        
        nombre_limpio = limpiar_texto(nombre)
        
        # 2. Validar duplicados si se requiere
        if validar_duplicados:
            existe = safe_execute(
                self.gasto_repo.expense_type_name_exists,
                nombre_limpio
            )
            
            if existe:
                raise ValidationError("nombre", nombre_limpio, "Tipo de gasto ya existe")
        
        # 3. Crear en repository
        tipo_id = safe_execute(
            self.gasto_repo.create_expense_type,
            nombre_limpio
        )
        
        if not tipo_id:
            raise GastoError(f"Error creando tipo de gasto: {nombre_limpio}")
        
        # 4. Obtener tipo creado con estadísticas
        tipo_completo = safe_execute(
            self.gasto_repo.get_expense_type_by_id,
            tipo_id
        )
        
        print(f"✅ Tipo de gasto creado - ID: {tipo_id}, Nombre: {nombre_limpio}")
        
        return crear_respuesta_qml(
            True,
            f"Tipo de gasto '{nombre_limpio}' creado correctamente",
            {
                'tipo': preparar_para_qml(tipo_completo),
                'fecha_creacion': fecha_actual_hora_str()
            }
        )
    
    @ExceptionHandler.handle_exception
    def actualizar_tipo_gasto(self, tipo_id: int, nombre: str) -> Dict[str, Any]:
        """Actualiza tipo de gasto existente"""
        print(f"💰 Actualizando tipo de gasto ID: {tipo_id}")
        
        # 1. Validar que existe
        tipo_actual = safe_execute(
            self.gasto_repo.get_expense_type_by_id,
            tipo_id
        )
        
        if not tipo_actual:
            raise GastoError(f"Tipo de gasto {tipo_id} no encontrado", tipo_gasto_id=tipo_id)
        
        # 2. Validar nuevo nombre
        if not nombre or len(nombre.strip()) < 3:
            raise ValidationError("nombre", nombre, "Mínimo 3 caracteres")
        
        nombre_limpio = limpiar_texto(nombre)
        
        # 3. Verificar que no tenga gastos asociados si el cambio es muy diferente
        if nombre_limpio.lower() != tipo_actual.get('Nombre', '').lower():
            total_gastos = safe_int(tipo_actual.get('total_gastos', 0))
            if total_gastos > 0:
                print(f"⚠️ Actualizando tipo con {total_gastos} gastos asociados")
        
        # 4. Actualizar en repository
        success = safe_execute(
            self.gasto_repo.update_expense_type,
            tipo_id,
            nombre_limpio
        )
        
        if not success:
            raise GastoError(f"Error actualizando tipo {tipo_id}", tipo_gasto_id=tipo_id)
        
        # 5. Obtener tipo actualizado
        tipo_actualizado = safe_execute(
            self.gasto_repo.get_expense_type_by_id,
            tipo_id
        )
        
        print(f"✅ Tipo de gasto actualizado - ID: {tipo_id}")
        
        return crear_respuesta_qml(
            True,
            f"Tipo actualizado a '{nombre_limpio}'",
            {
                'tipo': preparar_para_qml(tipo_actualizado),
                'tipo_anterior': preparar_para_qml(tipo_actual)
            }
        )
    
    @ExceptionHandler.handle_exception
    def eliminar_tipo_gasto(self, tipo_id: int, forzar: bool = False) -> Dict[str, Any]:
        """
        Elimina tipo de gasto
        
        Args:
            tipo_id: ID del tipo a eliminar
            forzar: Si forzar eliminación aunque tenga gastos
        """
        print(f"🗑️ Eliminando tipo de gasto ID: {tipo_id}")
        
        # 1. Verificar que existe
        tipo = safe_execute(
            self.gasto_repo.get_expense_type_by_id,
            tipo_id
        )
        
        if not tipo:
            raise GastoError(f"Tipo de gasto {tipo_id} no encontrado", tipo_gasto_id=tipo_id)
        
        # 2. Verificar gastos asociados
        total_gastos = safe_int(tipo.get('total_gastos', 0))
        
        if total_gastos > 0 and not forzar:
            raise GastoError(
                f"Tipo tiene {total_gastos} gastos asociados. Use forzar=True para eliminar",
                tipo_gasto_id=tipo_id
            )
        
        # 3. Eliminar del repository
        success = safe_execute(
            self.gasto_repo.delete_expense_type,
            tipo_id
        )
        
        if not success:
            raise GastoError(f"Error eliminando tipo {tipo_id}", tipo_gasto_id=tipo_id)
        
        print(f"✅ Tipo de gasto eliminado - ID: {tipo_id}")
        
        return crear_respuesta_qml(
            True,
            f"Tipo '{tipo.get('Nombre', '')}' eliminado correctamente",
            {
                'tipo_eliminado': preparar_para_qml(tipo),
                'gastos_asociados': total_gastos
            }
        )
    
    # ===============================
    # BÚSQUEDAS Y FILTROS
    # ===============================
    
    @ExceptionHandler.handle_exception
    def buscar_gastos_avanzado(self, filtros: Dict[str, Any]) -> Dict[str, Any]:
        """
        Búsqueda avanzada de gastos con múltiples filtros
        
        Args:
            filtros: {
                'termino_busqueda': str,
                'tipo_gasto_id': int,
                'fecha_desde': str,
                'fecha_hasta': str,
                'monto_min': float,
                'monto_max': float,
                'usuario_id': int,
                'page': int,
                'per_page': int
            }
        """
        print(f"🔍 Búsqueda avanzada de gastos con filtros: {len(filtros)}")
        
        # Extraer filtros
        termino = filtros.get('termino_busqueda', '').strip()
        tipo_gasto_id = safe_int(filtros.get('tipo_gasto_id', 0))
        fecha_desde = filtros.get('fecha_desde', '')
        fecha_hasta = filtros.get('fecha_hasta', '')
        monto_min = safe_float(filtros.get('monto_min', 0))
        monto_max = safe_float(filtros.get('monto_max', 0))
        usuario_id = safe_int(filtros.get('usuario_id', 0))
        page = safe_int(filtros.get('page', 1))
        per_page = safe_int(filtros.get('per_page', 20))
        
        resultados = []
        total_encontrados = 0
        
        try:
            # 1. Búsqueda por término si se proporciona
            if termino:
                fecha_desde_obj = parsear_fecha(fecha_desde) if fecha_desde else None
                fecha_hasta_obj = parsear_fecha(fecha_hasta) if fecha_hasta else None
                
                gastos_termino = safe_execute(
                    self.gasto_repo.search_expenses,
                    termino,
                    fecha_desde_obj,
                    fecha_hasta_obj,
                    1000  # Límite alto para filtrar después
                )
                resultados.extend(gastos_termino or [])
            
            # 2. Búsqueda por tipo específico
            elif tipo_gasto_id > 0:
                gastos_tipo = safe_execute(
                    self.gasto_repo.get_expenses_by_type,
                    tipo_gasto_id,
                    1000
                )
                resultados.extend(gastos_tipo or [])
            
            # 3. Búsqueda por usuario
            elif usuario_id > 0:
                gastos_usuario = safe_execute(
                    self.gasto_repo.get_expenses_by_user,
                    usuario_id,
                    1000
                )
                resultados.extend(gastos_usuario or [])
            
            # 4. Búsqueda por rango de fechas
            elif fecha_desde and fecha_hasta:
                fecha_desde_obj = parsear_fecha(fecha_desde)
                fecha_hasta_obj = parsear_fecha(fecha_hasta)
                
                if fecha_desde_obj and fecha_hasta_obj:
                    gastos_fecha = safe_execute(
                        self.gasto_repo.get_expenses_by_date_range,
                        fecha_desde_obj,
                        fecha_hasta_obj
                    )
                    resultados.extend(gastos_fecha or [])
            
            # 5. Búsqueda por rango de monto
            elif monto_min > 0 or monto_max > 0:
                monto_max_busqueda = monto_max if monto_max > 0 else self.monto_maximo_gasto
                monto_min_busqueda = monto_min if monto_min > 0 else 0
                
                gastos_monto = safe_execute(
                    self.gasto_repo.get_expenses_by_amount_range,
                    monto_min_busqueda,
                    monto_max_busqueda
                )
                resultados.extend(gastos_monto or [])
            
            # 6. Sin filtros específicos, obtener recientes
            else:
                gastos_recientes = safe_execute(
                    self.gasto_repo.get_recent_expenses,
                    30  # Últimos 30 días
                )
                resultados.extend(gastos_recientes or [])
            
            # 7. Aplicar filtros adicionales a los resultados
            if resultados:
                # Filtrar por monto si se especificó
                if monto_min > 0 or monto_max > 0:
                    resultados = [
                        g for g in resultados
                        if (monto_min == 0 or safe_float(g.get('Monto', 0)) >= monto_min) and
                           (monto_max == 0 or safe_float(g.get('Monto', 0)) <= monto_max)
                    ]
                
                # Filtrar por fechas si no se usó en la búsqueda principal
                if fecha_desde and fecha_hasta and not termino:
                    fecha_desde_obj = parsear_fecha(fecha_desde)
                    fecha_hasta_obj = parsear_fecha(fecha_hasta)
                    
                    if fecha_desde_obj and fecha_hasta_obj:
                        resultados = [
                            g for g in resultados
                            if g.get('Fecha') and 
                               fecha_desde_obj.date() <= g['Fecha'].date() <= fecha_hasta_obj.date()
                        ]
            
            # 8. Preparar resultados con paginación
            total_encontrados = len(resultados)
            
            # Calcular paginación
            start_index = (page - 1) * per_page
            end_index = start_index + per_page
            resultados_pagina = resultados[start_index:end_index]
            
            # Preparar para QML
            gastos_qml = []
            for gasto in resultados_pagina:
                gasto_qml = preparar_para_qml(gasto)
                
                # Agregar campos calculados
                gasto_qml['monto_formateado'] = formatear_precio(gasto.get('Monto', 0))
                gasto_qml['fecha_formateada'] = formatear_fecha(gasto.get('Fecha'))
                
                # Clasificar por monto
                monto = safe_float(gasto.get('Monto', 0))
                if monto >= self.monto_alerta_alta:
                    gasto_qml['categoria_monto'] = 'ALTO'
                elif monto >= self.monto_alerta_media:
                    gasto_qml['categoria_monto'] = 'MEDIO'
                else:
                    gasto_qml['categoria_monto'] = 'NORMAL'
                
                gastos_qml.append(gasto_qml)
            
            return crear_respuesta_qml(
                True,
                f"Encontrados {total_encontrados} gastos",
                {
                    'gastos': gastos_qml,
                    'paginacion': {
                        'page': page,
                        'per_page': per_page,
                        'total': total_encontrados,
                        'pages': (total_encontrados + per_page - 1) // per_page,
                        'tiene_siguiente': end_index < total_encontrados,
                        'tiene_anterior': page > 1
                    },
                    'filtros_aplicados': {
                        'termino': termino,
                        'tipo_gasto_id': tipo_gasto_id,
                        'fecha_desde': fecha_desde,
                        'fecha_hasta': fecha_hasta,
                        'monto_min': monto_min,
                        'monto_max': monto_max,
                        'usuario_id': usuario_id
                    }
                }
            )
            
        except Exception as e:
            return crear_respuesta_qml(
                False,
                f"Error en búsqueda: {str(e)}",
                codigo_error="BUSQUEDA_ERROR"
            )
    
    def filtrar_gastos_por_periodo(self, periodo: str) -> List[Dict[str, Any]]:
        """
        Filtra gastos por período predefinido
        
        Args:
            periodo: 'hoy', 'semana', 'mes', 'trimestre', 'año'
        """
        hoy = date.today()
        
        if periodo == 'hoy':
            gastos = safe_execute(self.gasto_repo.get_today_expenses) or []
        elif periodo == 'semana':
            gastos = safe_execute(self.gasto_repo.get_recent_expenses, 7) or []
        elif periodo == 'mes':
            gastos = safe_execute(
                self.gasto_repo.get_gastos_del_mes, 
                hoy.year, 
                hoy.month
            ) or []
        elif periodo == 'trimestre':
            gastos = safe_execute(self.gasto_repo.get_recent_expenses, 90) or []
        elif periodo == 'año':
            gastos = safe_execute(self.gasto_repo.get_recent_expenses, 365) or []
        else:
            gastos = safe_execute(self.gasto_repo.get_recent_expenses, 30) or []
        
        # Preparar para QML
        gastos_preparados = []
        for gasto in gastos:
            gasto_qml = preparar_para_qml(gasto)
            gasto_qml['monto_formateado'] = formatear_precio(gasto.get('Monto', 0))
            gasto_qml['fecha_formateada'] = formatear_fecha(gasto.get('Fecha'))
            gastos_preparados.append(gasto_qml)
        
        return gastos_preparados
    
    # ===============================
    # REPORTES Y ESTADÍSTICAS
    # ===============================
    
    @medir_tiempo_ejecucion
    def generar_reporte_gastos_periodo(self, fecha_desde: str, fecha_hasta: str, 
                                     incluir_detalles: bool = True) -> Dict[str, Any]:
        """
        Genera reporte completo de gastos por período
        """
        try:
            print(f"📊 Generando reporte de gastos: {fecha_desde} a {fecha_hasta}")
            
            # 1. Obtener estadísticas generales
            estadisticas = safe_execute(self.gasto_repo.get_expense_statistics)
            
            # 2. Obtener gastos del período
            fecha_desde_obj = parsear_fecha(fecha_desde)
            fecha_hasta_obj = parsear_fecha(fecha_hasta)
            
            gastos_periodo = []
            if fecha_desde_obj and fecha_hasta_obj:
                gastos_periodo = safe_execute(
                    self.gasto_repo.get_expenses_by_date_range,
                    fecha_desde_obj,
                    fecha_hasta_obj
                ) or []
            
            # 3. Calcular estadísticas del período
            total_gastos = len(gastos_periodo)
            monto_total = sum(safe_float(g.get('Monto', 0)) for g in gastos_periodo)
            gasto_promedio = monto_total / total_gastos if total_gastos > 0 else 0
            
            # Agrupar por tipo
            gastos_por_tipo = {}
            for gasto in gastos_periodo:
                tipo = gasto.get('tipo_nombre', 'Sin tipo')
                if tipo not in gastos_por_tipo:
                    gastos_por_tipo[tipo] = {
                        'cantidad': 0,
                        'monto': 0.0,
                        'gastos': []
                    }
                
                gastos_por_tipo[tipo]['cantidad'] += 1
                gastos_por_tipo[tipo]['monto'] += safe_float(gasto.get('Monto', 0))
                
                if incluir_detalles:
                    gastos_por_tipo[tipo]['gastos'].append(preparar_para_qml(gasto))
            
            # Ordenar tipos por monto
            tipos_ordenados = sorted(
                gastos_por_tipo.items(),
                key=lambda x: x[1]['monto'],
                reverse=True
            )
            
            # 4. Gastos más altos del período
            gastos_altos = [
                g for g in gastos_periodo 
                if safe_float(g.get('Monto', 0)) >= self.monto_alerta_media
            ]
            gastos_altos.sort(key=lambda x: safe_float(x.get('Monto', 0)), reverse=True)
            
            # 5. Tendencias (comparar con período anterior)
            dias_periodo = (fecha_hasta_obj - fecha_desde_obj).days
            fecha_anterior_desde = fecha_desde_obj - timedelta(days=dias_periodo)
            fecha_anterior_hasta = fecha_desde_obj
            
            gastos_anterior = safe_execute(
                self.gasto_repo.get_expenses_by_date_range,
                fecha_anterior_desde,
                fecha_anterior_hasta
            ) or []
            
            monto_anterior = sum(safe_float(g.get('Monto', 0)) for g in gastos_anterior)
            
            # Calcular variación
            variacion_monto = monto_total - monto_anterior
            variacion_porcentual = ((variacion_monto / monto_anterior) * 100) if monto_anterior > 0 else 0
            
            # 6. Preparar resumen
            resumen = {
                'periodo': {
                    'fecha_desde': formatear_fecha(fecha_desde_obj),
                    'fecha_hasta': formatear_fecha(fecha_hasta_obj),
                    'dias': dias_periodo
                },
                'totales': {
                    'gastos': total_gastos,
                    'monto_total': monto_total,
                    'gasto_promedio': gasto_promedio,
                    'tipos_utilizados': len(gastos_por_tipo),
                    'monto_total_formateado': formatear_precio(monto_total),
                    'gasto_promedio_formateado': formatear_precio(gasto_promedio)
                },
                'comparacion_anterior': {
                    'monto_anterior': monto_anterior,
                    'variacion_monto': variacion_monto,
                    'variacion_porcentual': variacion_porcentual,
                    'tendencia': 'AUMENTO' if variacion_monto > 0 else 'DISMINUCION' if variacion_monto < 0 else 'ESTABLE',
                    'monto_anterior_formateado': formatear_precio(monto_anterior),
                    'variacion_formateada': formatear_precio(abs(variacion_monto))
                },
                'por_tipo': [
                    {
                        'tipo': tipo[0],
                        'cantidad': tipo[1]['cantidad'],
                        'monto': tipo[1]['monto'],
                        'porcentaje': calcular_porcentaje(tipo[1]['monto'], monto_total),
                        'monto_formateado': formatear_precio(tipo[1]['monto']),
                        'gastos': tipo[1]['gastos'] if incluir_detalles else []
                    }
                    for tipo in tipos_ordenados
                ],
                'gastos_altos': [
                    {
                        **preparar_para_qml(g),
                        'monto_formateado': formatear_precio(g.get('Monto', 0)),
                        'fecha_formateada': formatear_fecha(g.get('Fecha'))
                    }
                    for g in gastos_altos[:10]  # Top 10
                ]
            }
            
            return crear_respuesta_qml(
                True,
                f"Reporte generado: {total_gastos} gastos, {formatear_precio(monto_total)}",
                {
                    'resumen': resumen,
                    'estadisticas_globales': estadisticas,
                    'gastos_detalle': [preparar_para_qml(g) for g in gastos_periodo] if incluir_detalles else [],
                    'generado_en': fecha_actual_hora_str()
                }
            )
            
        except Exception as e:
            return crear_respuesta_qml(
                False,
                f"Error generando reporte: {str(e)}",
                codigo_error="REPORTE_ERROR"
            )
    
    def obtener_estadisticas_dashboard(self) -> Dict[str, Any]:
        """Obtiene estadísticas para el dashboard de gastos"""
        try:
            # Estadísticas generales
            stats_generales = safe_execute(self.gasto_repo.get_expense_statistics)
            
            # Estadísticas de hoy
            stats_hoy = safe_execute(self.gasto_repo.get_today_statistics)
            
            # Tendencias mensuales
            tendencias = safe_execute(self.gasto_repo.get_expense_trends, 6)
            
            # Tipos de gastos con estadísticas
            tipos_stats = safe_execute(self.gasto_repo.get_all_expense_types)
            
            # Análisis de presupuesto (usar límites default)
            presupuesto_limits = {
                'Servicios Públicos': 8000.0,
                'Personal': 30000.0,
                'Alimentación': 5000.0,
                'Mantenimiento': 10000.0,
                'Administrativos': 6000.0,
                'Suministros Médicos': 8000.0
            }
            
            analisis_presupuesto = safe_execute(
                self.gasto_repo.get_budget_analysis,
                presupuesto_limits
            )
            
            # Preparar alertas
            alertas = self._generar_alertas_dashboard(stats_hoy, analisis_presupuesto)
            
            dashboard = {
                'resumen_hoy': preparar_para_qml(stats_hoy or {}),
                'estadisticas_generales': preparar_para_qml(stats_generales or {}),
                'tendencias_mensuales': preparar_para_qml(tendencias or []),
                'tipos_gastos': preparar_para_qml(tipos_stats or []),
                'analisis_presupuesto': preparar_para_qml(analisis_presupuesto or {}),
                'alertas': alertas,
                'ultima_actualizacion': fecha_actual_hora_str()
            }
            
            return preparar_para_qml(dashboard)
            
        except Exception as e:
            print(f"❌ Error obteniendo estadísticas dashboard: {e}")
            return {}
    
    def _generar_alertas_dashboard(self, stats_hoy: Dict[str, Any], 
                                 analisis_presupuesto: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Genera alertas para el dashboard"""
        alertas = []
        
        try:
            # Alerta por gastos altos hoy
            total_hoy = safe_float(stats_hoy.get('total_gastos_hoy', 0))
            if total_hoy >= self.monto_alerta_alta:
                alertas.append({
                    'tipo': 'gasto_alto_diario',
                    'prioridad': 'alta',
                    'mensaje': f"Gastos altos hoy: {formatear_precio(total_hoy)}",
                    'icono': '💸'
                })
            
            # Alertas de presupuesto
            if analisis_presupuesto:
                gastos_tipo = analisis_presupuesto.get('gastos_por_tipo', [])
                for gasto_tipo in gastos_tipo:
                    porcentaje = safe_float(gasto_tipo.get('porcentaje_usado', 0))
                    if porcentaje >= 100:
                        alertas.append({
                            'tipo': 'presupuesto_excedido',
                            'prioridad': 'critica',
                            'mensaje': f"{gasto_tipo.get('tipo_gasto', '')} excede presupuesto ({porcentaje:.1f}%)",
                            'icono': '🚨'
                        })
                    elif porcentaje >= 90:
                        alertas.append({
                            'tipo': 'presupuesto_alto',
                            'prioridad': 'alta',
                            'mensaje': f"{gasto_tipo.get('tipo_gasto', '')} cerca del límite ({porcentaje:.1f}%)",
                            'icono': '⚠️'
                        })
            
            # Alerta por muchos gastos en un día
            gastos_hoy_count = safe_int(stats_hoy.get('gastos_hoy', 0))
            if gastos_hoy_count >= 10:
                alertas.append({
                    'tipo': 'muchos_gastos_diarios',
                    'prioridad': 'media',
                    'mensaje': f"Muchos gastos registrados hoy ({gastos_hoy_count})",
                    'icono': '📊'
                })
        
        except Exception as e:
            alertas.append({
                'tipo': 'error',
                'prioridad': 'media',
                'mensaje': f"Error generando alertas: {str(e)}",
                'icono': '❌'
            })
        
        return alertas
    
    # ===============================
    # UTILIDADES PARA QML
    # ===============================
    
    def formatear_tipos_gastos_para_combobox(self) -> List[Dict[str, Any]]:
        """Formatea tipos de gastos para ComboBox en QML"""
        try:
            tipos = safe_execute(self.gasto_repo.get_all_expense_types)
            
            if not tipos:
                return []
            
            tipos_combobox = []
            
            for tipo in tipos:
                item = {
                    'id': tipo.get('id', 0),
                    'text': tipo.get('Nombre', 'Sin nombre'),
                    'total_gastos': tipo.get('total_gastos', 0),
                    'monto_total': formatear_precio(tipo.get('monto_total', 0)),
                    'data': tipo
                }
                tipos_combobox.append(item)
            
            # Ordenar por nombre
            tipos_combobox.sort(key=lambda x: x['text'])
            
            return tipos_combobox
            
        except Exception as e:
            print(f"❌ Error formateando tipos para ComboBox: {e}")
            return []
    
    def preparar_gasto_para_qml(self, gasto_id: int) -> Dict[str, Any]:
        """Prepara datos de gasto completo para QML"""
        try:
            gasto = safe_execute(
                self.gasto_repo.get_expense_by_id_complete,
                gasto_id
            )
            
            if not gasto:
                return crear_respuesta_qml(
                    False,
                    "Gasto no encontrado",
                    codigo_error="GASTO_NOT_FOUND"
                )
            
            # Preparar datos
            gasto_qml = preparar_para_qml(gasto)
            
            # Agregar campos calculados
            gasto_qml['monto_formateado'] = formatear_precio(gasto.get('Monto', 0))
            gasto_qml['fecha_formateada'] = formatear_fecha(gasto.get('Fecha'))
            
            # Clasificación por monto
            monto = safe_float(gasto.get('Monto', 0))
            if monto >= self.monto_alerta_alta:
                gasto_qml['categoria_monto'] = 'ALTO'
                gasto_qml['requiere_justificacion'] = True
            elif monto >= self.monto_alerta_media:
                gasto_qml['categoria_monto'] = 'MEDIO'
                gasto_qml['requiere_justificacion'] = False
            else:
                gasto_qml['categoria_monto'] = 'NORMAL'
                gasto_qml['requiere_justificacion'] = False
            
            # Verificar si se puede editar
            fecha_creacion = gasto.get('Fecha')
            if fecha_creacion:
                dias_desde_creacion = (datetime.now() - fecha_creacion).days
                gasto_qml['puede_editar'] = dias_desde_creacion <= self.dias_edicion_permitidos
                gasto_qml['dias_desde_creacion'] = dias_desde_creacion
            else:
                gasto_qml['puede_editar'] = True
                gasto_qml['dias_desde_creacion'] = 0
            
            return crear_respuesta_qml(
                True,
                "Gasto obtenido correctamente",
                gasto_qml
            )
            
        except Exception as e:
            return crear_respuesta_qml(
                False,
                f"Error obteniendo gasto: {str(e)}",
                codigo_error="GASTO_ERROR"
            )
    
    def obtener_resumen_gastos_recientes(self, dias: int = 7) -> Dict[str, Any]:
        """Obtiene resumen de gastos recientes para vista rápida"""
        try:
            gastos = safe_execute(self.gasto_repo.get_recent_expenses, dias)
            
            if not gastos:
                return crear_respuesta_qml(
                    True,
                    f"Sin gastos en los últimos {dias} días",
                    {'gastos': [], 'resumen': {}}
                )
            
            # Calcular resumen
            total_gastos = len(gastos)
            monto_total = sum(safe_float(g.get('Monto', 0)) for g in gastos)
            gasto_promedio = monto_total / total_gastos
            
            # Gastos por día
            gastos_por_dia = {}
            for gasto in gastos:
                fecha = gasto.get('Fecha')
                if fecha:
                    dia = fecha.strftime('%Y-%m-%d')
                    if dia not in gastos_por_dia:
                        gastos_por_dia[dia] = {'cantidad': 0, 'monto': 0}
                    
                    gastos_por_dia[dia]['cantidad'] += 1
                    gastos_por_dia[dia]['monto'] += safe_float(gasto.get('Monto', 0))
            
            # Preparar gastos para QML
            gastos_qml = []
            for gasto in gastos[-10:]:  # Últimos 10
                gasto_qml = preparar_para_qml(gasto)
                gasto_qml['monto_formateado'] = formatear_precio(gasto.get('Monto', 0))
                gasto_qml['fecha_formateada'] = formatear_fecha(gasto.get('Fecha'))
                gastos_qml.append(gasto_qml)
            
            resumen = {
                'periodo_dias': dias,
                'total_gastos': total_gastos,
                'monto_total': monto_total,
                'gasto_promedio': gasto_promedio,
                'monto_total_formateado': formatear_precio(monto_total),
                'gasto_promedio_formateado': formatear_precio(gasto_promedio),
                'gastos_por_dia': gastos_por_dia
            }
            
            return crear_respuesta_qml(
                True,
                f"Resumen de {total_gastos} gastos en {dias} días",
                {
                    'gastos': gastos_qml,
                    'resumen': resumen
                }
            )
            
        except Exception as e:
            return crear_respuesta_qml(
                False,
                f"Error obteniendo resumen: {str(e)}",
                codigo_error="RESUMEN_ERROR"
            )