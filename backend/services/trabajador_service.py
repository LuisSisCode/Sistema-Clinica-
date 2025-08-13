# backend/services/trabajador_service.py

import logging
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime

from ..repositories.trabajador_repository import TrabajadorRepository
from ..core.excepciones import (
    ValidationError, DatabaseQueryError, ExceptionHandler,
    validate_required, ClinicaBaseException
)
from ..core.config import Config
from ..core.utils import normalize_name, validate_required_string

logger = logging.getLogger(__name__)

class TrabajadorService:
    """Servicio de lógica de negocio para gestión de trabajadores"""
    
    def __init__(self):
        self.repository = TrabajadorRepository()
        logger.info("🏥 TrabajadorService inicializado")
    
    # ===============================
    # GESTIÓN DE TRABAJADORES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_trabajador(self, nombre: str, apellido_paterno: str, 
                        apellido_materno: str, tipo_trabajador_id: int) -> Dict[str, Any]:
        """
        Crea un nuevo trabajador con validaciones de negocio
        
        Args:
            nombre: Nombre del trabajador
            apellido_paterno: Apellido paterno
            apellido_materno: Apellido materno  
            tipo_trabajador_id: ID del tipo de trabajador
            
        Returns:
            Dict con resultado de la operación
        """
        try:
            # Validaciones de entrada
            self._validar_datos_trabajador(nombre, apellido_paterno, apellido_materno, tipo_trabajador_id)
            
            # Verificar que el tipo de trabajador existe y está activo
            tipo_trabajador = self.repository.get_worker_type_by_id(tipo_trabajador_id)
            if not tipo_trabajador:
                return {
                    'success': False,
                    'error': 'Tipo de trabajador no encontrado',
                    'code': 'TIPO_NOT_FOUND'
                }
            
            # Verificar duplicados (mismo nombre completo)
            if self._verificar_trabajador_duplicado(nombre, apellido_paterno, apellido_materno):
                return {
                    'success': False,
                    'error': 'Ya existe un trabajador con el mismo nombre completo',
                    'code': 'TRABAJADOR_DUPLICADO'
                }
            
            # Crear trabajador
            trabajador_id = self.repository.create_worker(
                nombre=nombre,
                apellido_paterno=apellido_paterno,
                apellido_materno=apellido_materno,
                tipo_trabajador_id=tipo_trabajador_id
            )
            
            # Obtener datos completos del trabajador creado
            trabajador_creado = self.repository.get_worker_with_type(trabajador_id)
            
            logger.info(f"👷‍♂️ Trabajador creado exitosamente: {nombre} {apellido_paterno} - ID: {trabajador_id}")
            
            return {
                'success': True,
                'data': {
                    'trabajador_id': trabajador_id,
                    'trabajador': trabajador_creado,
                    'tipo_nombre': tipo_trabajador['Tipo']
                },
                'message': f'Trabajador {nombre} {apellido_paterno} creado exitosamente'
            }
            
        except ValidationError as e:
            logger.warning(f"Validación falló al crear trabajador: {e.message}")
            return {
                'success': False,
                'error': e.message,
                'code': 'VALIDATION_ERROR',
                'details': e.details
            }
        except Exception as e:
            logger.error(f"Error creando trabajador: {str(e)}")
            return {
                'success': False,
                'error': 'Error interno al crear trabajador',
                'code': 'INTERNAL_ERROR'
            }
    
    @ExceptionHandler.handle_exception
    def actualizar_trabajador(self, trabajador_id: int, nombre: str = None,
                             apellido_paterno: str = None, apellido_materno: str = None,
                             tipo_trabajador_id: int = None) -> Dict[str, Any]:
        """
        Actualiza un trabajador existente
        
        Args:
            trabajador_id: ID del trabajador a actualizar
            nombre: Nuevo nombre (opcional)
            apellido_paterno: Nuevo apellido paterno (opcional)
            apellido_materno: Nuevo apellido materno (opcional)
            tipo_trabajador_id: Nuevo tipo (opcional)
            
        Returns:
            Dict con resultado de la operación
        """
        try:
            # Verificar que el trabajador existe
            trabajador_actual = self.repository.get_worker_with_type(trabajador_id)
            if not trabajador_actual:
                return {
                    'success': False,
                    'error': 'Trabajador no encontrado',
                    'code': 'TRABAJADOR_NOT_FOUND'
                }
            
            # Validar datos si se proporcionan
            if any([nombre, apellido_paterno, apellido_materno]):
                nombre_val = nombre or trabajador_actual['Nombre']
                apellido_p_val = apellido_paterno or trabajador_actual['Apellido_Paterno']
                apellido_m_val = apellido_materno or trabajador_actual['Apellido_Materno']
                
                self._validar_datos_trabajador(nombre_val, apellido_p_val, apellido_m_val, 
                                             tipo_trabajador_id or trabajador_actual['Id_Tipo_Trabajador'])
                
                # Verificar duplicados solo si cambió el nombre
                if (nombre_val != trabajador_actual['Nombre'] or 
                    apellido_p_val != trabajador_actual['Apellido_Paterno'] or
                    apellido_m_val != trabajador_actual['Apellido_Materno']):
                    
                    if self._verificar_trabajador_duplicado(nombre_val, apellido_p_val, apellido_m_val, trabajador_id):
                        return {
                            'success': False,
                            'error': 'Ya existe otro trabajador con el mismo nombre completo',
                            'code': 'TRABAJADOR_DUPLICADO'
                        }
            
            # Verificar tipo de trabajador si se cambió
            if tipo_trabajador_id and tipo_trabajador_id != trabajador_actual['Id_Tipo_Trabajador']:
                # Verificar restricciones de cambio de tipo
                restriccion = self._verificar_restricciones_cambio_tipo(trabajador_id, tipo_trabajador_id)
                if restriccion['tiene_restriccion']:
                    return {
                        'success': False,
                        'error': restriccion['mensaje'],
                        'code': 'CAMBIO_TIPO_RESTRINGIDO',
                        'details': restriccion['detalles']
                    }
            
            # Actualizar trabajador
            success = self.repository.update_worker(
                trabajador_id=trabajador_id,
                nombre=nombre,
                apellido_paterno=apellido_paterno,
                apellido_materno=apellido_materno,
                tipo_trabajador_id=tipo_trabajador_id
            )
            
            if not success:
                return {
                    'success': False,
                    'error': 'No se pudo actualizar el trabajador',
                    'code': 'UPDATE_FAILED'
                }
            
            # Obtener datos actualizados
            trabajador_actualizado = self.repository.get_worker_with_type(trabajador_id)
            
            logger.info(f"👷‍♂️ Trabajador actualizado: ID {trabajador_id}")
            
            return {
                'success': True,
                'data': {
                    'trabajador': trabajador_actualizado
                },
                'message': 'Trabajador actualizado exitosamente'
            }
            
        except ValidationError as e:
            logger.warning(f"Validación falló al actualizar trabajador: {e.message}")
            return {
                'success': False,
                'error': e.message,
                'code': 'VALIDATION_ERROR',
                'details': e.details
            }
        except Exception as e:
            logger.error(f"Error actualizando trabajador {trabajador_id}: {str(e)}")
            return {
                'success': False,
                'error': 'Error interno al actualizar trabajador',
                'code': 'INTERNAL_ERROR'
            }
    
    @ExceptionHandler.handle_exception
    def eliminar_trabajador(self, trabajador_id: int, forzar: bool = False) -> Dict[str, Any]:
        """
        Elimina un trabajador con validaciones de integridad
        
        Args:
            trabajador_id: ID del trabajador a eliminar
            forzar: Si True, elimina aunque tenga dependencias (con cuidado)
            
        Returns:
            Dict con resultado de la operación
        """
        try:
            # Verificar que el trabajador existe
            trabajador = self.repository.get_worker_with_type(trabajador_id)
            if not trabajador:
                return {
                    'success': False,
                    'error': 'Trabajador no encontrado',
                    'code': 'TRABAJADOR_NOT_FOUND'
                }
            
            # Verificar dependencias (asignaciones de laboratorio)
            dependencias = self._verificar_dependencias_trabajador(trabajador_id)
            
            if dependencias['tiene_dependencias'] and not forzar:
                return {
                    'success': False,
                    'error': 'No se puede eliminar trabajador con asignaciones activas',
                    'code': 'TIENE_DEPENDENCIAS',
                    'details': dependencias
                }
            
            # Si se fuerza eliminación, mostrar advertencia
            if dependencias['tiene_dependencias'] and forzar:
                logger.warning(f"🚨 ELIMINACIÓN FORZADA - Trabajador {trabajador_id} con dependencias: {dependencias}")
            
            # Eliminar trabajador
            success = self.repository.delete(trabajador_id)
            
            if not success:
                return {
                    'success': False,
                    'error': 'No se pudo eliminar el trabajador',
                    'code': 'DELETE_FAILED'
                }
            
            logger.info(f"🗑️ Trabajador eliminado: {trabajador['Nombre']} {trabajador['Apellido_Paterno']} - ID: {trabajador_id}")
            
            return {
                'success': True,
                'data': {
                    'trabajador_eliminado': trabajador,
                    'dependencias_afectadas': dependencias if forzar else None
                },
                'message': f"Trabajador {trabajador['Nombre']} {trabajador['Apellido_Paterno']} eliminado exitosamente"
            }
            
        except Exception as e:
            logger.error(f"Error eliminando trabajador {trabajador_id}: {str(e)}")
            return {
                'success': False,
                'error': 'Error interno al eliminar trabajador',
                'code': 'INTERNAL_ERROR'
            }
    
    # ===============================
    # GESTIÓN DE TIPOS DE TRABAJADORES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_tipo_trabajador(self, nombre: str) -> Dict[str, Any]:
        """
        Crea un nuevo tipo de trabajador
        
        Args:
            nombre: Nombre del tipo de trabajador
            
        Returns:
            Dict con resultado de la operación
        """
        try:
            # Validaciones
            nombre = validate_required_string(nombre, "nombre", 3)
            
            # Verificar duplicados
            if self.repository.worker_type_name_exists(nombre):
                return {
                    'success': False,
                    'error': f'Ya existe un tipo de trabajador llamado "{nombre}"',
                    'code': 'TIPO_DUPLICADO'
                }
            
            # Crear tipo
            tipo_id = self.repository.create_worker_type(nombre)
            
            # Obtener tipo creado
            tipo_creado = self.repository.get_worker_type_by_id(tipo_id)
            
            logger.info(f"👥 Tipo de trabajador creado: {nombre} - ID: {tipo_id}")
            
            return {
                'success': True,
                'data': {
                    'tipo_id': tipo_id,
                    'tipo': tipo_creado
                },
                'message': f'Tipo de trabajador "{nombre}" creado exitosamente'
            }
            
        except ValidationError as e:
            return {
                'success': False,
                'error': e.message,
                'code': 'VALIDATION_ERROR'
            }
        except Exception as e:
            logger.error(f"Error creando tipo de trabajador: {str(e)}")
            return {
                'success': False,
                'error': 'Error interno al crear tipo de trabajador',
                'code': 'INTERNAL_ERROR'
            }
    
    @ExceptionHandler.handle_exception
    def actualizar_tipo_trabajador(self, tipo_id: int, nombre: str) -> Dict[str, Any]:
        """
        Actualiza un tipo de trabajador existente
        
        Args:
            tipo_id: ID del tipo a actualizar
            nombre: Nuevo nombre del tipo
            
        Returns:
            Dict con resultado de la operación
        """
        try:
            # Validaciones
            nombre = validate_required_string(nombre, "nombre", 3)
            
            # Verificar que el tipo existe
            tipo_actual = self.repository.get_worker_type_by_id(tipo_id)
            if not tipo_actual:
                return {
                    'success': False,
                    'error': 'Tipo de trabajador no encontrado',
                    'code': 'TIPO_NOT_FOUND'
                }
            
            # Verificar duplicados (excepto el mismo)
            if nombre != tipo_actual['Tipo'] and self.repository.worker_type_name_exists(nombre):
                return {
                    'success': False,
                    'error': f'Ya existe un tipo de trabajador llamado "{nombre}"',
                    'code': 'TIPO_DUPLICADO'
                }
            
            # Actualizar tipo
            success = self.repository.update_worker_type(tipo_id, nombre)
            
            if not success:
                return {
                    'success': False,
                    'error': 'No se pudo actualizar el tipo de trabajador',
                    'code': 'UPDATE_FAILED'
                }
            
            # Obtener tipo actualizado
            tipo_actualizado = self.repository.get_worker_type_by_id(tipo_id)
            
            logger.info(f"👥 Tipo de trabajador actualizado: {nombre} - ID: {tipo_id}")
            
            return {
                'success': True,
                'data': {
                    'tipo': tipo_actualizado
                },
                'message': f'Tipo de trabajador actualizado a "{nombre}"'
            }
            
        except ValidationError as e:
            return {
                'success': False,
                'error': e.message,
                'code': 'VALIDATION_ERROR'
            }
        except Exception as e:
            logger.error(f"Error actualizando tipo de trabajador {tipo_id}: {str(e)}")
            return {
                'success': False,
                'error': 'Error interno al actualizar tipo de trabajador',
                'code': 'INTERNAL_ERROR'
            }
    
    @ExceptionHandler.handle_exception
    def eliminar_tipo_trabajador(self, tipo_id: int) -> Dict[str, Any]:
        """
        Elimina un tipo de trabajador si no tiene trabajadores asociados
        
        Args:
            tipo_id: ID del tipo a eliminar
            
        Returns:
            Dict con resultado de la operación
        """
        try:
            # Verificar que el tipo existe
            tipo = self.repository.get_worker_type_by_id(tipo_id)
            if not tipo:
                return {
                    'success': False,
                    'error': 'Tipo de trabajador no encontrado',
                    'code': 'TIPO_NOT_FOUND'
                }
            
            # Verificar trabajadores asociados
            trabajadores_asociados = self.repository.get_workers_by_type(tipo_id)
            if trabajadores_asociados:
                return {
                    'success': False,
                    'error': f'No se puede eliminar el tipo "{tipo["Tipo"]}" porque tiene {len(trabajadores_asociados)} trabajadores asociados',
                    'code': 'TIPO_CON_TRABAJADORES',
                    'details': {
                        'cantidad_trabajadores': len(trabajadores_asociados),
                        'trabajadores': [f"{t['Nombre']} {t['Apellido_Paterno']}" for t in trabajadores_asociados[:5]]  # Solo primeros 5
                    }
                }
            
            # Eliminar tipo
            success = self.repository.delete_worker_type(tipo_id)
            
            if not success:
                return {
                    'success': False,
                    'error': 'No se pudo eliminar el tipo de trabajador',
                    'code': 'DELETE_FAILED'
                }
            
            logger.info(f"🗑️ Tipo de trabajador eliminado: {tipo['Tipo']} - ID: {tipo_id}")
            
            return {
                'success': True,
                'data': {
                    'tipo_eliminado': tipo
                },
                'message': f'Tipo de trabajador "{tipo["Tipo"]}" eliminado exitosamente'
            }
            
        except Exception as e:
            logger.error(f"Error eliminando tipo de trabajador {tipo_id}: {str(e)}")
            return {
                'success': False,
                'error': 'Error interno al eliminar tipo de trabajador',
                'code': 'INTERNAL_ERROR'
            }
    
    # ===============================
    # CONSULTAS Y BÚSQUEDAS
    # ===============================
    
    @ExceptionHandler.handle_exception
    def obtener_trabajadores(self, filtros: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Obtiene lista de trabajadores con filtros opcionales
        
        Args:
            filtros: Diccionario con filtros opcionales:
                - tipo_id: Filtrar por tipo específico
                - buscar: Término de búsqueda
                - incluir_stats: Incluir estadísticas de laboratorio
                - area: Filtrar por área (laboratorio, farmacia, etc.)
                
        Returns:
            Dict con lista de trabajadores
        """
        try:
            filtros = filtros or {}
            
            # Aplicar filtros específicos
            if filtros.get('tipo_id'):
                trabajadores = self.repository.get_workers_by_type(filtros['tipo_id'])
            elif filtros.get('buscar'):
                trabajadores = self.repository.search_workers(filtros['buscar'])
            elif filtros.get('area'):
                trabajadores = self._obtener_por_area(filtros['area'])
            else:
                trabajadores = self.repository.get_all_with_types()
            
            # Agregar estadísticas si se solicita
            if filtros.get('incluir_stats'):
                for trabajador in trabajadores:
                    stats = self._obtener_estadisticas_trabajador(trabajador['id'])
                    trabajador.update(stats)
            
            return {
                'success': True,
                'data': {
                    'trabajadores': trabajadores,
                    'total': len(trabajadores),
                    'filtros_aplicados': filtros
                }
            }
            
        except Exception as e:
            logger.error(f"Error obteniendo trabajadores: {str(e)}")
            return {
                'success': False,
                'error': 'Error interno obteniendo trabajadores',
                'code': 'INTERNAL_ERROR'
            }
    
    @ExceptionHandler.handle_exception
    def obtener_tipos_trabajadores(self) -> Dict[str, Any]:
        """
        Obtiene todos los tipos de trabajadores con estadísticas
        
        Returns:
            Dict con lista de tipos
        """
        try:
            tipos = self.repository.get_all_worker_types()
            
            return {
                'success': True,
                'data': {
                    'tipos': tipos,
                    'total': len(tipos)
                }
            }
            
        except Exception as e:
            logger.error(f"Error obteniendo tipos de trabajadores: {str(e)}")
            return {
                'success': False,
                'error': 'Error interno obteniendo tipos de trabajadores',
                'code': 'INTERNAL_ERROR'
            }
    
    @ExceptionHandler.handle_exception
    def obtener_estadisticas(self) -> Dict[str, Any]:
        """
        Obtiene estadísticas completas de trabajadores
        
        Returns:
            Dict con estadísticas detalladas
        """
        try:
            stats = self.repository.get_worker_statistics()
            
            # Agregar estadísticas adicionales
            stats['trabajadores_sin_asignaciones'] = len(self.repository.get_workers_without_assignments())
            stats['carga_laboratorio'] = self.repository.get_laboratory_workload()
            
            return {
                'success': True,
                'data': stats
            }
            
        except Exception as e:
            logger.error(f"Error obteniendo estadísticas: {str(e)}")
            return {
                'success': False,
                'error': 'Error interno obteniendo estadísticas',
                'code': 'INTERNAL_ERROR'
            }
    
    # ===============================
    # VALIDACIONES DE NEGOCIO
    # ===============================
    
    def _validar_datos_trabajador(self, nombre: str, apellido_paterno: str, 
                                 apellido_materno: str, tipo_trabajador_id: int):
        """Valida los datos básicos de un trabajador"""
        # Validar strings requeridos
        validate_required_string(nombre, "nombre", 2)
        validate_required_string(apellido_paterno, "apellido_paterno", 2)
        validate_required_string(apellido_materno, "apellido_materno", 2)
        validate_required(tipo_trabajador_id, "tipo_trabajador_id")
        
        # Validaciones específicas
        if not isinstance(tipo_trabajador_id, int) or tipo_trabajador_id <= 0:
            raise ValidationError("tipo_trabajador_id", tipo_trabajador_id, "Debe ser un número entero positivo")
        
        # Validar caracteres especiales en nombres
        for campo, valor in [("nombre", nombre), ("apellido_paterno", apellido_paterno), ("apellido_materno", apellido_materno)]:
            if not valor.replace(" ", "").replace("-", "").isalpha():
                raise ValidationError(campo, valor, "Solo debe contener letras, espacios y guiones")
    
    def _verificar_trabajador_duplicado(self, nombre: str, apellido_paterno: str, 
                                       apellido_materno: str, excluir_id: int = None) -> bool:
        """Verifica si ya existe un trabajador con el mismo nombre completo"""
        trabajadores = self.repository.get_all_with_types()
        
        nombre_norm = normalize_name(nombre)
        apellido_p_norm = normalize_name(apellido_paterno)
        apellido_m_norm = normalize_name(apellido_materno)
        
        for trabajador in trabajadores:
            if excluir_id and trabajador['id'] == excluir_id:
                continue
                
            if (normalize_name(trabajador['Nombre']) == nombre_norm and
                normalize_name(trabajador['Apellido_Paterno']) == apellido_p_norm and
                normalize_name(trabajador['Apellido_Materno']) == apellido_m_norm):
                return True
        
        return False
    
    def _verificar_dependencias_trabajador(self, trabajador_id: int) -> Dict[str, Any]:
        """Verifica las dependencias de un trabajador antes de eliminar"""
        dependencias = {
            'tiene_dependencias': False,
            'detalles': {}
        }
        
        # Verificar asignaciones de laboratorio
        asignaciones_lab = self.repository.get_worker_lab_assignments(trabajador_id)
        if asignaciones_lab:
            dependencias['tiene_dependencias'] = True
            dependencias['detalles']['laboratorio'] = {
                'cantidad': len(asignaciones_lab),
                'examenes': [f"{a['Nombre']} - {a['paciente_completo']}" for a in asignaciones_lab[:3]]
            }
        
        return dependencias
    
    def _verificar_restricciones_cambio_tipo(self, trabajador_id: int, nuevo_tipo_id: int) -> Dict[str, Any]:
        """Verifica restricciones para cambiar el tipo de un trabajador"""
        restricciones = {
            'tiene_restriccion': False,
            'mensaje': '',
            'detalles': {}
        }
        
        # Obtener asignaciones actuales
        asignaciones_lab = self.repository.get_worker_lab_assignments(trabajador_id)
        
        # Si tiene asignaciones de laboratorio, verificar si el nuevo tipo es compatible
        if asignaciones_lab:
            nuevo_tipo = self.repository.get_worker_type_by_id(nuevo_tipo_id)
            if nuevo_tipo and 'Laboratorio' not in nuevo_tipo['Tipo']:
                restricciones['tiene_restriccion'] = True
                restricciones['mensaje'] = f'No se puede cambiar a "{nuevo_tipo["Tipo"]}" porque tiene {len(asignaciones_lab)} asignaciones de laboratorio activas'
                restricciones['detalles'] = {
                    'asignaciones_laboratorio': len(asignaciones_lab),
                    'nuevo_tipo': nuevo_tipo['Tipo']
                }
        
        return restricciones
    
    def _obtener_por_area(self, area: str) -> List[Dict[str, Any]]:
        """Obtiene trabajadores por área específica"""
        area_lower = area.lower()
        
        if area_lower == 'laboratorio':
            return self.repository.get_laboratory_workers()
        elif area_lower == 'farmacia':
            return self.repository.get_pharmacy_workers()
        elif area_lower == 'enfermeria':
            return self.repository.get_nursing_staff()
        elif area_lower == 'administrativo':
            return self.repository.get_administrative_staff()
        elif area_lower == 'tecnico':
            return self.repository.get_technical_staff()
        elif area_lower == 'salud':
            return self.repository.get_healthcare_professionals()
        else:
            return []
    
    def _obtener_estadisticas_trabajador(self, trabajador_id: int) -> Dict[str, Any]:
        """Obtiene estadísticas específicas de un trabajador"""
        stats = {}
        
        # Estadísticas de laboratorio
        asignaciones_lab = self.repository.get_worker_lab_assignments(trabajador_id)
        stats['total_asignaciones_laboratorio'] = len(asignaciones_lab)
        
        if asignaciones_lab:
            total_valor = sum(float(a.get('Precio_Normal', 0)) for a in asignaciones_lab)
            stats['valor_total_laboratorio'] = total_valor
            stats['promedio_por_examen'] = total_valor / len(asignaciones_lab) if asignaciones_lab else 0
        else:
            stats['valor_total_laboratorio'] = 0
            stats['promedio_por_examen'] = 0
        
        return stats
    
    # ===============================
    # UTILIDADES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def buscar_trabajadores(self, termino: str, limite: int = 50) -> Dict[str, Any]:
        """
        Búsqueda rápida de trabajadores
        
        Args:
            termino: Término de búsqueda
            limite: Límite de resultados
            
        Returns:
            Dict con resultados de búsqueda
        """
        try:
            if not termino or len(termino.strip()) < 2:
                return {
                    'success': False,
                    'error': 'El término de búsqueda debe tener al menos 2 caracteres',
                    'code': 'SEARCH_TERM_TOO_SHORT'
                }
            
            resultados = self.repository.search_workers(termino.strip(), limite)
            
            return {
                'success': True,
                'data': {
                    'trabajadores': resultados,
                    'total': len(resultados),
                    'termino_busqueda': termino.strip(),
                    'limite_aplicado': limite
                }
            }
            
        except Exception as e:
            logger.error(f"Error en búsqueda de trabajadores: {str(e)}")
            return {
                'success': False,
                'error': 'Error interno en búsqueda',
                'code': 'INTERNAL_ERROR'
            }
    
    @ExceptionHandler.handle_exception
    def validar_trabajador_existe(self, trabajador_id: int) -> Dict[str, Any]:
        """
        Valida que un trabajador existe
        
        Args:
            trabajador_id: ID del trabajador
            
        Returns:
            Dict con resultado de validación
        """
        try:
            trabajador = self.repository.get_worker_with_type(trabajador_id)
            
            if trabajador:
                return {
                    'success': True,
                    'data': {
                        'existe': True,
                        'trabajador': trabajador
                    }
                }
            else:
                return {
                    'success': True,
                    'data': {
                        'existe': False
                    }
                }
                
        except Exception as e:
            logger.error(f"Error validando existencia de trabajador {trabajador_id}: {str(e)}")
            return {
                'success': False,
                'error': 'Error interno validando trabajador',
                'code': 'INTERNAL_ERROR'
            }
    
    def invalidar_cache(self):
        """Invalida los cachés relacionados con trabajadores"""
        try:
            self.repository.invalidate_worker_caches()
            logger.info("🔄 Cache de trabajadores invalidado")
        except Exception as e:
            logger.warning(f"Error invalidando cache: {str(e)}")

# Instancia global del servicio
trabajador_service = TrabajadorService()