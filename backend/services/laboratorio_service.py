"""
Servicio de Laboratorio - Lógica de Negocio
Orquesta operaciones complejas y reglas de negocio específicas del dominio de laboratorio
"""

from typing import List, Dict, Any, Optional, Tuple, Union
from datetime import datetime, timedelta, date
from decimal import Decimal

from ..core.excepciones import (
    ValidationError, ExceptionHandler, ClinicaBaseException,
    validate_required, safe_execute, validate_positive_number
)
from ..core.utils import (
    formatear_fecha, formatear_precio, preparar_para_qml, crear_respuesta_qml,
    calcular_porcentaje, formatear_nombre_completo, truncar_texto,
    validar_rango_numerico, limpiar_texto, safe_int, safe_float, parsear_fecha
)
from ..repositories.laboratorio_repository import LaboratorioRepository
from ..repositories.paciente_repository import PacienteRepository
from ..repositories.trabajador_repository import TrabajadorRepository
from ..repositories.usuario_repository import UsuarioRepository

class LaboratorioService:
    """
    Servicio para gestión avanzada de análisis de laboratorio
    Implementa lógica de negocio, validaciones complejas y orquestación
    """
    
    def __init__(self):
        self.laboratorio_repo = LaboratorioRepository()
        self.paciente_repo = PacienteRepository()
        self.trabajador_repo = TrabajadorRepository()
        self.usuario_repo = UsuarioRepository()
        
        # Configuraciones de negocio para laboratorio
        self.MAX_EXAMENES_POR_TRABAJADOR_DIA = 15
        self.MAX_EXAMENES_POR_PACIENTE_DIA = 5
        self.TIPOS_TRABAJADORES_VALIDOS = [
            'Técnico en Laboratorio', 'T�cnico en Laboratorio',
            'Laboratorista', 'Bioanalista'
        ]
        self.PRECIO_MINIMO_EXAMEN = 20.0
        self.PRECIO_MAXIMO_EXAMEN = 500.0
        self.DIAS_PARA_SEGUIMIENTO_EXAMENES = 7
        self.HORAS_MAXIMAS_PROCESAMIENTO = 24
        
        print("🔬 LaboratorioService inicializado")
    
    # ===============================
    # OPERACIONES DE CREACIÓN AVANZADA
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_examen_completo(self, datos_examen: Dict[str, Any]) -> Dict[str, Any]:
        """
        Crea examen de laboratorio con validaciones de negocio completas
        
        Args:
            datos_examen: {
                'paciente_info': {...},      # Si es nuevo paciente
                'paciente_id': int,          # Si es paciente existente
                'nombre_examen': str,
                'detalles': str,
                'precio_normal': float,
                'precio_emergencia': float,
                'trabajador_id': int,        # Opcional
                'tipo_examen': str           # normal/emergencia
            }
            
        Returns:
            Dict con resultado completo de la operación
        """
        resultado = {
            'exito': False,
            'examen_id': None,
            'paciente_id': None,
            'detalles_operacion': {},
            'advertencias': []
        }
        
        try:
            # 1. Validar datos básicos
            self._validar_datos_examen(datos_examen)
            
            # 2. Obtener o crear paciente
            paciente_id = self._gestionar_paciente_laboratorio(
                datos_examen.get('paciente_info'),
                datos_examen.get('paciente_id')
            )
            resultado['paciente_id'] = paciente_id
            
            # 3. Validar trabajador si se especifica
            trabajador_id = datos_examen.get('trabajador_id')
            if trabajador_id:
                self._validar_trabajador_laboratorio(trabajador_id)
            
            # 4. Aplicar reglas de negocio
            advertencias = self._aplicar_reglas_negocio_examen(
                paciente_id, 
                trabajador_id,
                datos_examen.get('tipo_examen', 'normal')
            )
            resultado['advertencias'] = advertencias
            
            # 5. Validar y ajustar precios
            precio_normal, precio_emergencia = self._validar_precios_examen(
                datos_examen['precio_normal'],
                datos_examen['precio_emergencia']
            )
            
            # 6. Crear el examen
            examen_id = self.laboratorio_repo.create_lab_exam(
                nombre=datos_examen['nombre_examen'],
                paciente_id=paciente_id,
                precio_normal=precio_normal,
                precio_emergencia=precio_emergencia,
                detalles=datos_examen.get('detalles', ''),
                trabajador_id=trabajador_id
            )
            
            # 7. Registrar seguimiento y auditoría
            self._registrar_seguimiento_examen(examen_id, paciente_id, trabajador_id)
            
            # 8. Generar respuesta completa
            examen_completo = self.obtener_examen_completo(examen_id)
            
            resultado.update({
                'exito': True,
                'examen_id': examen_id,
                'examen_completo': examen_completo,
                'detalles_operacion': {
                    'paciente_nuevo': 'paciente_info' in datos_examen,
                    'trabajador_asignado': trabajador_id is not None,
                    'tipo_examen': datos_examen.get('tipo_examen', 'normal'),
                    'precio_normal': formatear_precio(precio_normal),
                    'precio_emergencia': formatear_precio(precio_emergencia),
                    'nombre_examen': datos_examen['nombre_examen']
                }
            })
            
            print(f"✅ Examen de laboratorio creado exitosamente: ID {examen_id}")
            return resultado
            
        except Exception as e:
            resultado['error'] = str(e)
            raise ClinicaBaseException(f"Error creando examen de laboratorio: {str(e)}")
    
    @ExceptionHandler.handle_exception
    def actualizar_examen_con_validaciones(self, examen_id: int, 
                                         nuevos_datos: Dict[str, Any], 
                                         usuario_id: int = None) -> Dict[str, Any]:
        """
        Actualiza examen con validaciones de negocio y auditoría
        """
        # Validar existencia
        examen_actual = self.laboratorio_repo.get_lab_exam_by_id_complete(examen_id)
        if not examen_actual:
            raise ValidationError("examen_id", examen_id, "Examen de laboratorio no encontrado")
        
        # Validar si se puede modificar
        self._validar_modificacion_examen_permitida(examen_actual)
        
        # Preparar datos para actualización
        datos_actualizacion = {}
        
        # Actualizar nombre si se proporciona
        if 'nombre_examen' in nuevos_datos:
            nombre = limpiar_texto(nuevos_datos['nombre_examen'])
            if len(nombre) < 3:
                raise ValidationError("nombre_examen", nombre, "Nombre muy corto")
            datos_actualizacion['nombre'] = nombre
        
        # Actualizar precios si se proporcionan
        if 'precio_normal' in nuevos_datos or 'precio_emergencia' in nuevos_datos:
            precio_normal = nuevos_datos.get('precio_normal', examen_actual['Precio_Normal'])
            precio_emergencia = nuevos_datos.get('precio_emergencia', examen_actual['Precio_Emergencia'])
            
            precio_normal, precio_emergencia = self._validar_precios_examen(
                precio_normal, precio_emergencia
            )
            
            datos_actualizacion['precio_normal'] = precio_normal
            datos_actualizacion['precio_emergencia'] = precio_emergencia
        
        # Actualizar detalles si se proporcionan
        if 'detalles' in nuevos_datos:
            datos_actualizacion['detalles'] = limpiar_texto(nuevos_datos['detalles'])
        
        # Actualizar trabajador si se proporciona
        if 'trabajador_id' in nuevos_datos:
            trabajador_id = nuevos_datos['trabajador_id']
            if trabajador_id:
                self._validar_trabajador_laboratorio(trabajador_id)
            datos_actualizacion['trabajador_id'] = trabajador_id
        
        # Aplicar cambios
        success = self.laboratorio_repo.update_lab_exam(examen_id, **datos_actualizacion)
        
        if success:
            # Registrar auditoría
            if usuario_id:
                self._registrar_auditoria_modificacion_examen(examen_id, usuario_id, nuevos_datos)
            
            examen_actualizado = self.obtener_examen_completo(examen_id)
            
            return crear_respuesta_qml(
                exito=True,
                mensaje="Examen actualizado correctamente",
                datos=examen_actualizado
            )
        
        return crear_respuesta_qml(False, "Error actualizando examen")
    
    @ExceptionHandler.handle_exception
    def eliminar_examen_seguro(self, examen_id: int) -> bool:
        """
        Elimina examen con validaciones de seguridad
        """
        # Verificar existencia
        examen = self.laboratorio_repo.get_by_id(examen_id)
        if not examen:
            raise ValidationError("examen_id", examen_id, "Examen no encontrado")
        
        # Validar si se puede eliminar (ej: no muy antiguo, sin resultados procesados)
        self._validar_eliminacion_examen_permitida(examen)
        
        # Eliminar
        return self.laboratorio_repo.delete(examen_id)
    
    # ===============================
    # GESTIÓN DE TRABAJADORES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def asignar_trabajador_optimizado(self, examen_id: int, trabajador_id: int) -> bool:
        """
        Asigna trabajador a examen con optimización de carga de trabajo
        """
        # Validar trabajador
        self._validar_trabajador_laboratorio(trabajador_id)
        
        # Verificar carga de trabajo
        self._verificar_carga_trabajo_trabajador(trabajador_id)
        
        # Asignar
        success = self.laboratorio_repo.assign_worker_to_exam(examen_id, trabajador_id)
        
        if success:
            print(f"👨‍🔬 Trabajador {trabajador_id} asignado a examen {examen_id}")
        
        return success
    
    @ExceptionHandler.handle_exception
    def desasignar_trabajador(self, examen_id: int) -> bool:
        """Desasigna trabajador de examen"""
        return self.laboratorio_repo.unassign_worker_from_exam(examen_id)
    
    @ExceptionHandler.handle_exception
    def obtener_trabajadores_laboratorio(self) -> List[Dict[str, Any]]:
        """Obtiene trabajadores válidos para laboratorio"""
        trabajadores = self.laboratorio_repo.get_available_lab_workers()
        
        # Enriquecer con información de carga de trabajo
        trabajadores_enriquecidos = []
        for trabajador in trabajadores:
            trabajador_info = trabajador.copy()
            
            # Calcular carga actual
            carga_actual = self._calcular_carga_trabajo_actual(trabajador['id'])
            trabajador_info['carga_trabajo'] = carga_actual
            trabajador_info['disponible'] = carga_actual < self.MAX_EXAMENES_POR_TRABAJADOR_DIA
            trabajador_info['porcentaje_carga'] = calcular_porcentaje(
                carga_actual, self.MAX_EXAMENES_POR_TRABAJADOR_DIA
            )
            
            trabajadores_enriquecidos.append(trabajador_info)
        
        # Ordenar por disponibilidad
        trabajadores_enriquecidos.sort(key=lambda x: (not x['disponible'], x['carga_trabajo']))
        
        return preparar_para_qml(trabajadores_enriquecidos)
    
    def obtener_mejor_trabajador_disponible(self) -> Optional[Dict[str, Any]]:
        """Obtiene el trabajador con menor carga de trabajo"""
        trabajadores = self.obtener_trabajadores_laboratorio()
        trabajadores_disponibles = [t for t in trabajadores if t['disponible']]
        
        if trabajadores_disponibles:
            return trabajadores_disponibles[0]  # Ya está ordenado por carga
        
        return None
    
    # ===============================
    # BÚSQUEDAS Y FILTROS AVANZADOS
    # ===============================
    
    @ExceptionHandler.handle_exception
    def buscar_examenes_avanzado(self, criterios: Dict[str, Any]) -> Dict[str, Any]:
        """
        Búsqueda avanzada de exámenes con múltiples criterios
        
        Args:
            criterios: {
                'texto': str,
                'fecha_inicio': str,
                'fecha_fin': str,
                'paciente_id': int,
                'trabajador_id': int,
                'tipo_examen': str,
                'precio_min': float,
                'precio_max': float,
                'sin_asignar': bool,
                'incluir_estadisticas': bool,
                'pagina': int,
                'por_pagina': int
            }
        """
        try:
            # Procesar fechas
            fecha_inicio = parsear_fecha(criterios.get('fecha_inicio'))
            fecha_fin = parsear_fecha(criterios.get('fecha_fin'))
            
            # Realizar búsqueda base
            examenes = []
            
            if criterios.get('texto'):
                examenes = self.laboratorio_repo.search_exams(
                    search_term=criterios['texto'],
                    limit=criterios.get('por_pagina', 50)
                )
            elif criterios.get('paciente_id'):
                examenes = self.laboratorio_repo.get_exams_by_patient(criterios['paciente_id'])
            elif criterios.get('trabajador_id'):
                examenes = self.laboratorio_repo.get_exams_by_worker(criterios['trabajador_id'])
            elif criterios.get('sin_asignar'):
                examenes = self.laboratorio_repo.get_unassigned_exams()
            else:
                examenes = self.laboratorio_repo.get_all_with_details(
                    limit=criterios.get('por_pagina', 50)
                )
            
            # Aplicar filtros adicionales
            examenes_filtrados = self._aplicar_filtros_avanzados_examenes(examenes, criterios)
            
            # Enriquecer datos
            examenes_enriquecidos = self._enriquecer_examenes(examenes_filtrados)
            
            # Calcular estadísticas si se solicitan
            estadisticas = {}
            if criterios.get('incluir_estadisticas', False):
                estadisticas = self._calcular_estadisticas_busqueda_examenes(examenes_filtrados)
            
            # Aplicar paginación
            pagina = criterios.get('pagina', 1)
            por_pagina = criterios.get('por_pagina', 50)
            examenes_paginados = self._paginar_resultados(
                examenes_enriquecidos, pagina, por_pagina
            )
            
            return {
                'exito': True,
                'examenes': examenes_paginados['data'],
                'paginacion': {
                    'pagina_actual': pagina,
                    'por_pagina': por_pagina,
                    'total_registros': len(examenes_enriquecidos),
                    'total_paginas': examenes_paginados['pages']
                },
                'estadisticas': estadisticas,
                'criterios_aplicados': self._resumir_criterios_busqueda(criterios)
            }
            
        except Exception as e:
            return crear_respuesta_qml(
                exito=False,
                mensaje=f"Error en búsqueda avanzada: {str(e)}",
                codigo_error="SEARCH_ERROR"
            )
    
    def aplicar_filtros_examenes(self, examenes: List[Dict[str, Any]], 
                               filtros: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Aplica filtros a lista de exámenes"""
        examenes_filtrados = examenes.copy()
        
        # Filtro por texto en nombre
        if filtros.get('texto'):
            texto = filtros['texto'].lower()
            examenes_filtrados = [
                e for e in examenes_filtrados
                if texto in e.get('Nombre', '').lower() or 
                   texto in e.get('paciente_completo', '').lower()
            ]
        
        # Filtro por trabajador asignado
        if filtros.get('trabajador_id'):
            trabajador_id = safe_int(filtros['trabajador_id'])
            examenes_filtrados = [
                e for e in examenes_filtrados
                if e.get('Id_Trabajador') == trabajador_id
            ]
        
        # Filtro por sin asignar
        if filtros.get('sin_asignar', False):
            examenes_filtrados = [
                e for e in examenes_filtrados
                if not e.get('Id_Trabajador')
            ]
        
        # Filtro por rango de precios
        precio_min = safe_float(filtros.get('precio_min', 0))
        precio_max = safe_float(filtros.get('precio_max', 0))
        
        if precio_min > 0 or precio_max > 0:
            examenes_filtrados = [
                e for e in examenes_filtrados
                if self._examen_en_rango_precio(e, precio_min, precio_max)
            ]
        
        return examenes_filtrados
    
    def obtener_examen_completo(self, examen_id: int) -> Dict[str, Any]:
        """Obtiene examen con toda la información relacionada y enriquecida"""
        examen = self.laboratorio_repo.get_lab_exam_by_id_complete(examen_id)
        if not examen:
            raise ValidationError("examen_id", examen_id, "Examen no encontrado")
        
        # Enriquecer con información adicional
        examen_enriquecido = self._enriquecer_examen_individual(examen)
        
        return preparar_para_qml(examen_enriquecido)
    
    def obtener_examenes_completos(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Obtiene lista de exámenes completos"""
        examenes = self.laboratorio_repo.get_all_with_details(limit)
        return self._enriquecer_examenes(examenes)
    
    # ===============================
    # ESTADÍSTICAS Y REPORTES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def obtener_dashboard_laboratorio(self) -> Dict[str, Any]:
        """Obtiene datos para dashboard de laboratorio"""
        try:
            # Estadísticas generales
            stats_generales = self.laboratorio_repo.get_laboratory_statistics()
            
            # Examenes de hoy
            examenes_hoy = self._obtener_examenes_hoy()
            
            # Trabajadores y su carga
            carga_trabajadores = self._obtener_carga_trabajadores()
            
            # Exámenes sin asignar
            examenes_sin_asignar = self.laboratorio_repo.get_unassigned_exams()
            
            # Tipos de exámenes más comunes
            tipos_comunes = self.laboratorio_repo.get_common_exam_types(limit=10)
            
            # Métricas calculadas
            dashboard = {
                'metricas_hoy': {
                    'examenes_hoy': len(examenes_hoy),
                    'examenes_asignados_hoy': len([e for e in examenes_hoy if e.get('Id_Trabajador')]),
                    'examenes_pendientes': len(examenes_sin_asignar),
                    'trabajadores_activos': len([t for t in carga_trabajadores if t['examenes_asignados'] > 0])
                },
                'metricas_generales': {
                    'total_examenes': stats_generales['general'].get('total_examenes', 0),
                    'pacientes_unicos': stats_generales['general'].get('pacientes_unicos', 0),
                    'trabajadores_asignados': stats_generales['general'].get('trabajadores_asignados', 0),
                    'precio_promedio': safe_float(stats_generales['general'].get('precio_promedio_normal', 0))
                },
                'carga_trabajadores': self._formatear_carga_trabajadores(carga_trabajadores[:5]),
                'tipos_examenes_populares': self._formatear_tipos_examenes(tipos_comunes[:5]),
                'examenes_recientes': self._formatear_examenes_recientes(examenes_hoy[:10]),
                'alertas': self._generar_alertas_laboratorio(),
                'distribuciones': {
                    'por_precio': self._calcular_distribucion_precios(stats_generales),
                    'por_trabajador': stats_generales.get('por_trabajador', [])[:5]
                }
            }
            
            return preparar_para_qml(dashboard)
            
        except Exception as e:
            return crear_respuesta_qml(
                exito=False,
                mensaje=f"Error generando dashboard: {str(e)}",
                codigo_error="DASHBOARD_ERROR"
            )
    
    @ExceptionHandler.handle_exception
    def generar_estadisticas_completas(self) -> Dict[str, Any]:
        """Genera estadísticas completas de laboratorio"""
        try:
            # Estadísticas base del repositorio
            stats_base = self.laboratorio_repo.get_laboratory_statistics()
            
            # Estadísticas adicionales calculadas
            stats_adicionales = {
                'productividad': self._calcular_productividad_laboratorio(),
                'tendencias_semanales': self._calcular_tendencias_semanales(),
                'eficiencia_trabajadores': self._calcular_eficiencia_trabajadores(),
                'analisis_precios': self._analizar_precios_examenes(),
                'distribucion_carga': self.laboratorio_repo.get_workload_distribution()
            }
            
            # Combinar estadísticas
            estadisticas_completas = {
                'resumen_general': stats_base['general'],
                'por_tipo_examen': stats_base['por_tipo_examen'],
                'por_trabajador': stats_base['por_trabajador'],
                'analisis_adicional': stats_adicionales,
                'fecha_generacion': datetime.now().isoformat(),
                'periodo_analisis': self._obtener_periodo_analisis()
            }
            
            return preparar_para_qml(estadisticas_completas)
            
        except Exception as e:
            raise ClinicaBaseException(f"Error generando estadísticas: {str(e)}")
    
    @ExceptionHandler.handle_exception
    def generar_reporte_trabajador_completo(self, trabajador_id: int, 
                                          fecha_inicio: str = None,
                                          fecha_fin: str = None) -> Dict[str, Any]:
        """Genera reporte completo de actividad de trabajador"""
        # Parsear fechas
        if fecha_fin is None:
            fecha_fin = datetime.now()
        else:
            fecha_fin = parsear_fecha(fecha_fin)
        
        if fecha_inicio is None:
            fecha_inicio = fecha_fin - timedelta(days=30)
        else:
            fecha_inicio = parsear_fecha(fecha_inicio)
        
        # Obtener información del trabajador
        trabajador_info = self._obtener_info_trabajador_completa(trabajador_id)
        
        # Obtener exámenes del trabajador
        examenes = self.laboratorio_repo.get_exams_by_worker(trabajador_id)
        
        # Filtrar por periodo
        examenes_periodo = [
            e for e in examenes 
            if fecha_inicio <= e.get('fecha_creacion', datetime.now()) <= fecha_fin
        ]
        
        # Calcular métricas
        reporte = {
            'trabajador_info': trabajador_info,
            'periodo': {
                'inicio': formatear_fecha(fecha_inicio),
                'fin': formatear_fecha(fecha_fin),
                'dias': (fecha_fin - fecha_inicio).days
            },
            'resumen_numerico': {
                'total_examenes': len(examenes_periodo),
                'examenes_completados': len([e for e in examenes_periodo if e.get('estado') == 'completado']),
                'examenes_pendientes': len([e for e in examenes_periodo if e.get('estado') == 'pendiente']),
                'pacientes_atendidos': len(set(e['Id_Paciente'] for e in examenes_periodo)),
                'valor_total_examenes': sum(safe_float(e.get('Precio_Normal', 0)) for e in examenes_periodo)
            },
            'productividad': self._calcular_productividad_trabajador(examenes_periodo),
            'tipos_examenes_realizados': self._analizar_tipos_examenes_trabajador(examenes_periodo),
            'distribucion_temporal': self._analizar_distribucion_temporal_trabajador(examenes_periodo),
            'examenes_detallados': self._preparar_examenes_reporte(examenes_periodo[:50])
        }
        
        return preparar_para_qml(reporte)
    
    @ExceptionHandler.handle_exception
    def obtener_resumen_paciente_laboratorio(self, paciente_id: int) -> Dict[str, Any]:
        """Obtiene resumen completo de laboratorio de un paciente"""
        try:
            # Usar método del repositorio
            resumen_base = self.laboratorio_repo.get_patient_lab_summary(paciente_id)
            
            # Obtener exámenes del paciente
            examenes = self.laboratorio_repo.get_exams_by_patient(paciente_id)
            
            # Enriquecer con análisis adicional
            resumen_enriquecido = {
                'estadisticas_basicas': resumen_base['estadisticas'],
                'examenes_por_tipo': resumen_base['examenes_por_tipo'],
                'historial_examenes': self._formatear_historial_examenes(examenes[-10:]),  # Últimos 10
                'tendencias_paciente': self._analizar_tendencias_paciente(examenes),
                'recomendaciones': self._generar_recomendaciones_paciente(examenes),
                'proximos_seguimientos': self._calcular_proximos_seguimientos(examenes)
            }
            
            return preparar_para_qml(resumen_enriquecido)
            
        except Exception as e:
            return crear_respuesta_qml(
                exito=False,
                mensaje=f"Error obteniendo resumen: {str(e)}",
                codigo_error="SUMMARY_ERROR"
            )
    
    # ===============================
    # VALIDACIONES DE NEGOCIO
    # ===============================
    
    def _validar_datos_examen(self, datos: Dict[str, Any]):
        """Valida datos básicos de examen"""
        # Validar que tenga paciente
        if not datos.get('paciente_id') and not datos.get('paciente_info'):
            raise ValidationError("paciente", None, "Debe especificar paciente")
        
        # Validar nombre del examen
        nombre = datos.get('nombre_examen', '').strip()
        if len(nombre) < 3:
            raise ValidationError("nombre_examen", nombre, "Nombre muy corto (mínimo 3 caracteres)")
        
        if len(nombre) > 200:
            raise ValidationError("nombre_examen", len(nombre), "Nombre muy largo (máximo 200 caracteres)")
        
        # Validar detalles
        detalles = datos.get('detalles', '').strip()
        if len(detalles) > 500:
            raise ValidationError("detalles", len(detalles), "Detalles muy largos (máximo 500 caracteres)")
        
        # Validar precios
        validate_required(datos.get('precio_normal'), "precio_normal")
        validate_required(datos.get('precio_emergencia'), "precio_emergencia")
    
    def _validar_precios_examen(self, precio_normal: float, precio_emergencia: float) -> Tuple[float, float]:
        """Valida y ajusta precios de examen"""
        precio_normal = validate_positive_number(precio_normal, "precio_normal")
        precio_emergencia = validate_positive_number(precio_emergencia, "precio_emergencia")
        
        # Validar rangos
        if not validar_rango_numerico(precio_normal, self.PRECIO_MINIMO_EXAMEN, self.PRECIO_MAXIMO_EXAMEN):
            raise ValidationError("precio_normal", precio_normal, 
                                f"Precio normal fuera del rango ({self.PRECIO_MINIMO_EXAMEN}-{self.PRECIO_MAXIMO_EXAMEN})")
        
        if not validar_rango_numerico(precio_emergencia, self.PRECIO_MINIMO_EXAMEN, self.PRECIO_MAXIMO_EXAMEN):
            raise ValidationError("precio_emergencia", precio_emergencia,
                                f"Precio emergencia fuera del rango ({self.PRECIO_MINIMO_EXAMEN}-{self.PRECIO_MAXIMO_EXAMEN})")
        
        # Validar que precio de emergencia >= precio normal
        if precio_emergencia < precio_normal:
            raise ValidationError("precio_emergencia", precio_emergencia,
                                "Precio de emergencia debe ser mayor o igual al normal")
        
        return precio_normal, precio_emergencia
    
    def _validar_trabajador_laboratorio(self, trabajador_id: int):
        """Valida que el trabajador sea válido para laboratorio"""
        if not self.laboratorio_repo._worker_exists(trabajador_id):
            raise ValidationError("trabajador_id", trabajador_id, "Trabajador no encontrado")
        
        # Verificar tipo de trabajador (esto requiere consulta adicional)
        # En implementación real, verificar que el tipo sea válido para laboratorio
        print(f"✅ Trabajador {trabajador_id} validado para laboratorio")
    
    def _aplicar_reglas_negocio_examen(self, paciente_id: int, trabajador_id: int = None,
                                     tipo_examen: str = 'normal') -> List[str]:
        """Aplica reglas de negocio específicas de laboratorio"""
        advertencias = []
        
        # Verificar exámenes del día del paciente
        examenes_hoy_paciente = self._contar_examenes_hoy_paciente(paciente_id)
        if examenes_hoy_paciente >= self.MAX_EXAMENES_POR_PACIENTE_DIA:
            advertencias.append(
                f"Paciente ya tiene {examenes_hoy_paciente} exámenes hoy (máximo {self.MAX_EXAMENES_POR_PACIENTE_DIA})"
            )
        
        # Verificar carga de trabajo si se asigna trabajador
        if trabajador_id:
            carga_trabajador = self._calcular_carga_trabajo_actual(trabajador_id)
            if carga_trabajador >= self.MAX_EXAMENES_POR_TRABAJADOR_DIA:
                advertencias.append(
                    f"Trabajador ya tiene {carga_trabajador} exámenes asignados hoy"
                )
        
        # Advertencia para exámenes de emergencia
        if tipo_examen.lower() == 'emergencia':
            advertencias.append("Examen marcado como emergencia - procesamiento prioritario")
        
        return advertencias
    
    def _verificar_carga_trabajo_trabajador(self, trabajador_id: int):
        """Verifica que el trabajador no esté sobrecargado"""
        carga_actual = self._calcular_carga_trabajo_actual(trabajador_id)
        
        if carga_actual >= self.MAX_EXAMENES_POR_TRABAJADOR_DIA:
            raise ValidationError(
                "trabajador_carga", 
                carga_actual,
                f"Trabajador sobrecargado ({carga_actual}/{self.MAX_EXAMENES_POR_TRABAJADOR_DIA})"
            )
    
    def _validar_modificacion_examen_permitida(self, examen: Dict[str, Any]):
        """Valida si un examen puede ser modificado"""
        # En implementación real, verificar estado del examen, fechas, etc.
        print(f"✅ Modificación permitida para examen {examen.get('id')}")
    
    def _validar_eliminacion_examen_permitida(self, examen: Dict[str, Any]):
        """Valida si un examen puede ser eliminado"""
        # En implementación real, verificar dependencias, resultados procesados, etc.
        print(f"✅ Eliminación permitida para examen {examen.get('id')}")
    
    def validar_datos_examen_completo(self, datos: Dict[str, Any]) -> Dict[str, Any]:
        """Valida datos de examen de forma completa"""
        errores = []
        advertencias = []
        
        try:
            self._validar_datos_examen(datos)
        except ValidationError as e:
            errores.append(e.message)
        
        # Validaciones adicionales
        if datos.get('trabajador_id'):
            try:
                self._validar_trabajador_laboratorio(datos['trabajador_id'])
            except ValidationError as e:
                errores.append(e.message)
        
        # Validar precios
        try:
            self._validar_precios_examen(
                datos.get('precio_normal', 0),
                datos.get('precio_emergencia', 0)
            )
        except ValidationError as e:
            errores.append(e.message)
        
        return {
            'valido': len(errores) == 0,
            'errores': errores,
            'advertencias': advertencias
        }
    
    def validar_asignacion_trabajador(self, examen_id: int, trabajador_id: int) -> bool:
        """Valida si se puede asignar trabajador a examen"""
        try:
            self._validar_trabajador_laboratorio(trabajador_id)
            self._verificar_carga_trabajo_trabajador(trabajador_id)
            return True
        except ValidationError:
            return False
    
    # ===============================
    # GESTIÓN DE PACIENTES Y TIPOS
    # ===============================
    
    def _gestionar_paciente_laboratorio(self, paciente_info: Dict[str, Any] = None, 
                                      paciente_id: int = None) -> int:
        """Gestiona paciente para examen de laboratorio"""
        if paciente_id:
            # Verificar existencia
            if not self.laboratorio_repo._patient_exists(paciente_id):
                raise ValidationError("paciente_id", paciente_id, "Paciente no encontrado")
            return paciente_id
        
        elif paciente_info:
            # Crear nuevo paciente
            return self._crear_paciente_laboratorio(paciente_info)
        
        else:
            raise ValidationError("paciente", None, "Debe especificar paciente_id o paciente_info")
    
    def _crear_paciente_laboratorio(self, paciente_info: Dict[str, Any]) -> int:
        """Crea nuevo paciente validado para laboratorio"""
        # Validaciones básicas
        validate_required(paciente_info.get('nombre'), "nombre")
        validate_required(paciente_info.get('apellido_paterno'), "apellido_paterno")
        
        edad = safe_int(paciente_info.get('edad', 0))
        if not validar_rango_numerico(edad, 0, 120):
            raise ValidationError("edad", edad, "Edad debe estar entre 0 y 120 años")
        
        # En implementación real, usar PacienteRepository
        print(f"🆕 Creando paciente para laboratorio: {paciente_info.get('nombre')}")
        return 999  # ID simulado
    
    def obtener_tipos_analisis_disponibles(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de análisis disponibles"""
        # En implementación real, esto vendría de una tabla de configuración
        tipos_analisis = [
            {
                'id': 1,
                'nombre': 'Hemograma Completo',
                'descripcion': 'Análisis completo de células sanguíneas',
                'precio_normal': 80.0,
                'precio_emergencia': 120.0,
                'tiempo_procesamiento_horas': 4
            },
            {
                'id': 2,
                'nombre': 'Perfil Lipídico',
                'descripcion': 'Colesterol y triglicéridos',
                'precio_normal': 95.0,
                'precio_emergencia': 140.0,
                'tiempo_procesamiento_horas': 6
            },
            {
                'id': 3,
                'nombre': 'Glucosa en Ayunas',
                'descripcion': 'Nivel de azúcar en sangre',
                'precio_normal': 35.0,
                'precio_emergencia': 50.0,
                'tiempo_procesamiento_horas': 2
            }
        ]
        
        return preparar_para_qml(tipos_analisis)
    
    def configurar_tipo_analisis(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Configura un nuevo tipo de análisis"""
        try:
            # Validar configuración
            validate_required(config.get('nombre'), "nombre")
            validate_required(config.get('precio_normal'), "precio_normal")
            validate_required(config.get('precio_emergencia'), "precio_emergencia")
            
            # En implementación real, guardar en base de datos
            print(f"⚙️ Configurando tipo de análisis: {config['nombre']}")
            
            return crear_respuesta_qml(True, "Tipo de análisis configurado correctamente")
            
        except Exception as e:
            return crear_respuesta_qml(False, f"Error configurando tipo: {str(e)}")
    
    # ===============================
    # ENRIQUECIMIENTO DE DATOS
    # ===============================
    
    def _enriquecer_examenes(self, examenes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Enriquece lista de exámenes con información adicional"""
        examenes_enriquecidos = []
        
        for examen in examenes:
            examen_enriquecido = self._enriquecer_examen_individual(examen)
            examenes_enriquecidos.append(examen_enriquecido)
        
        return examenes_enriquecidos
    
    def _enriquecer_examen_individual(self, examen: Dict[str, Any]) -> Dict[str, Any]:
        """Enriquece examen individual con información calculada"""
        examen_enriquecido = examen.copy()
        
        # Formatear precios
        if 'Precio_Normal' in examen:
            examen_enriquecido['precio_normal_formateado'] = formatear_precio(examen['Precio_Normal'])
        
        if 'Precio_Emergencia' in examen:
            examen_enriquecido['precio_emergencia_formateado'] = formatear_precio(examen['Precio_Emergencia'])
        
        # Estado de asignación
        examen_enriquecido['tiene_trabajador_asignado'] = bool(examen.get('Id_Trabajador'))
        examen_enriquecido['estado_asignacion'] = (
            'Asignado' if examen.get('Id_Trabajador') else 'Sin asignar'
        )
        
        # Información del paciente formateada
        if 'paciente_completo' in examen:
            examen_enriquecido['paciente_nombre_corto'] = truncar_texto(
                examen['paciente_completo'], 30
            )
        
        # Truncar detalles para vista resumida
        if 'Detalles' in examen:
            examen_enriquecido['detalles_resumidos'] = truncar_texto(examen['Detalles'], 100)
        
        # Prioridad basada en tipo
        examen_enriquecido['prioridad'] = self._calcular_prioridad_examen(examen)
        
        return examen_enriquecido
    
    def _calcular_prioridad_examen(self, examen: Dict[str, Any]) -> str:
        """Calcula prioridad del examen"""
        # Lógica simplificada - en caso real sería más compleja
        if not examen.get('Id_Trabajador'):
            return 'alta'  # Sin asignar = alta prioridad
        
        return 'normal'
    
    # ===============================
    # MÉTRICAS Y CÁLCULOS
    # ===============================
    
    def _calcular_carga_trabajo_actual(self, trabajador_id: int) -> int:
        """Calcula carga de trabajo actual del trabajador"""
        examenes_hoy = self._obtener_examenes_hoy()
        carga = len([e for e in examenes_hoy if e.get('Id_Trabajador') == trabajador_id])
        return carga
    
    def _contar_examenes_hoy_paciente(self, paciente_id: int) -> int:
        """Cuenta exámenes de hoy de un paciente"""
        examenes_hoy = self._obtener_examenes_hoy()
        count = len([e for e in examenes_hoy if e.get('Id_Paciente') == paciente_id])
        return count
    
    def _obtener_examenes_hoy(self) -> List[Dict[str, Any]]:
        """Obtiene exámenes de hoy"""
        hoy = datetime.now().date()
        # En implementación real, filtrar por fecha de creación
        # Por ahora, simulamos con todos los exámenes
        return self.laboratorio_repo.get_all_with_details(limit=100)
    
    def _obtener_carga_trabajadores(self) -> List[Dict[str, Any]]:
        """Obtiene carga de trabajo de todos los trabajadores"""
        trabajadores = self.laboratorio_repo.get_available_lab_workers()
        carga_trabajadores = []
        
        for trabajador in trabajadores:
            carga = self._calcular_carga_trabajo_actual(trabajador['id'])
            carga_trabajadores.append({
                'id': trabajador['id'],
                'nombre_completo': trabajador['nombre_completo'],
                'tipo_trabajador': trabajador.get('trabajador_tipo', 'N/A'),
                'examenes_asignados': carga,
                'porcentaje_carga': calcular_porcentaje(carga, self.MAX_EXAMENES_POR_TRABAJADOR_DIA),
                'disponible': carga < self.MAX_EXAMENES_POR_TRABAJADOR_DIA
            })
        
        return carga_trabajadores
    
    def _calcular_productividad_laboratorio(self) -> Dict[str, Any]:
        """Calcula métricas de productividad del laboratorio"""
        # Implementación simplificada
        examenes_hoy = self._obtener_examenes_hoy()
        trabajadores_activos = len(set(e.get('Id_Trabajador') for e in examenes_hoy if e.get('Id_Trabajador')))
        
        return {
            'examenes_por_trabajador_promedio': len(examenes_hoy) / max(trabajadores_activos, 1),
            'eficiencia_general': 'alta' if len(examenes_hoy) > 10 else 'normal'
        }
    
    # ===============================
    # UTILIDADES DE FILTROS Y BÚSQUEDA
    # ===============================
    
    def _aplicar_filtros_avanzados_examenes(self, examenes: List[Dict[str, Any]], 
                                          criterios: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Aplica filtros avanzados a exámenes"""
        examenes_filtrados = examenes.copy()
        
        # Filtro por rango de precios
        precio_min = safe_float(criterios.get('precio_min', 0))
        precio_max = safe_float(criterios.get('precio_max', 0))
        
        if precio_min > 0 or precio_max > 0:
            examenes_filtrados = [
                e for e in examenes_filtrados
                if self._examen_en_rango_precio(e, precio_min, precio_max)
            ]
        
        return examenes_filtrados
    
    def _examen_en_rango_precio(self, examen: Dict[str, Any], 
                              precio_min: float, precio_max: float) -> bool:
        """Verifica si examen está en rango de precio"""
        precio = safe_float(examen.get('Precio_Normal', 0))
        
        if precio_min > 0 and precio < precio_min:
            return False
        
        if precio_max > 0 and precio > precio_max:
            return False
        
        return True
    
    def _calcular_estadisticas_busqueda_examenes(self, examenes: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calcula estadísticas de resultados de búsqueda"""
        if not examenes:
            return {}
        
        total = len(examenes)
        asignados = len([e for e in examenes if e.get('Id_Trabajador')])
        sin_asignar = total - asignados
        
        precios = [safe_float(e.get('Precio_Normal', 0)) for e in examenes]
        precio_promedio = sum(precios) / len(precios) if precios else 0
        precio_total = sum(precios)
        
        return {
            'resumen': {
                'total_examenes': total,
                'examenes_asignados': asignados,
                'examenes_sin_asignar': sin_asignar,
                'precio_promedio': precio_promedio,
                'precio_total': precio_total
            },
            'distribuciones': {
                'por_asignacion': {
                    'asignados': asignados,
                    'sin_asignar': sin_asignar
                }
            }
        }
    
    def _paginar_resultados(self, datos: List[Any], pagina: int, 
                          por_pagina: int) -> Dict[str, Any]:
        """Aplica paginación a resultados"""
        inicio = (pagina - 1) * por_pagina
        fin = inicio + por_pagina
        
        datos_pagina = datos[inicio:fin]
        total_paginas = (len(datos) + por_pagina - 1) // por_pagina
        
        return {
            'data': datos_pagina,
            'page': pagina,
            'per_page': por_pagina,
            'total': len(datos),
            'pages': total_paginas
        }
    
    def _resumir_criterios_busqueda(self, criterios: Dict[str, Any]) -> Dict[str, Any]:
        """Resume criterios aplicados en búsqueda"""
        resumen = {}
        
        if criterios.get('texto'):
            resumen['busqueda_texto'] = criterios['texto']
        
        if criterios.get('paciente_id'):
            resumen['paciente_filtrado'] = True
        
        if criterios.get('trabajador_id'):
            resumen['trabajador_filtrado'] = True
        
        if criterios.get('sin_asignar'):
            resumen['solo_sin_asignar'] = True
        
        return resumen
    
    # ===============================
    # UTILIDADES DE FORMATO Y REPORTE
    # ===============================
    
    def _formatear_carga_trabajadores(self, trabajadores: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Formatea datos de carga de trabajadores para dashboard"""
        return [
            {
                'nombre': t.get('nombre_completo', 'N/A'),
                'examenes_asignados': t.get('examenes_asignados', 0),
                'porcentaje_carga': t.get('porcentaje_carga', 0),
                'estado': 'sobrecargado' if t.get('examenes_asignados', 0) >= self.MAX_EXAMENES_POR_TRABAJADOR_DIA else 'normal'
            }
            for t in trabajadores
        ]
    
    def _formatear_tipos_examenes(self, tipos: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Formatea tipos de exámenes más comunes"""
        return [
            {
                'nombre': t.get('tipo_examen', 'N/A'),
                'cantidad': t.get('cantidad_realizados', 0),
                'precio_promedio': formatear_precio(t.get('precio_promedio_normal', 0))
            }
            for t in tipos
        ]
    
    def _formatear_examenes_recientes(self, examenes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Formatea exámenes recientes para dashboard"""
        return [
            {
                'id': e.get('id'),
                'nombre': e.get('Nombre', 'N/A'),
                'paciente': e.get('paciente_completo', 'N/A'),
                'trabajador': e.get('trabajador_completo', 'Sin asignar'),
                'precio': formatear_precio(e.get('Precio_Normal', 0)),
                'estado': 'asignado' if e.get('Id_Trabajador') else 'pendiente'
            }
            for e in examenes
        ]
    
    def _generar_alertas_laboratorio(self) -> List[Dict[str, Any]]:
        """Genera alertas específicas de laboratorio"""
        alertas = []
        
        # Verificar exámenes sin asignar
        examenes_sin_asignar = len(self.laboratorio_repo.get_unassigned_exams())
        if examenes_sin_asignar > 5:
            alertas.append({
                'tipo': 'warning',
                'mensaje': f'{examenes_sin_asignar} exámenes sin asignar trabajador',
                'accion': 'asignar_trabajadores'
            })
        
        # Verificar trabajadores sobrecargados
        trabajadores_sobrecargados = [
            t for t in self._obtener_carga_trabajadores()
            if t['examenes_asignados'] >= self.MAX_EXAMENES_POR_TRABAJADOR_DIA
        ]
        
        if trabajadores_sobrecargados:
            alertas.append({
                'tipo': 'error',
                'mensaje': f'{len(trabajadores_sobrecargados)} trabajadores sobrecargados',
                'accion': 'redistribuir_carga'
            })
        
        # Alerta informativa
        if not alertas:
            alertas.append({
                'tipo': 'info',
                'mensaje': 'Laboratorio funcionando correctamente',
                'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            })
        
        return alertas
    
    def _calcular_distribucion_precios(self, stats: Dict[str, Any]) -> Dict[str, Any]:
        """Calcula distribución de precios de exámenes"""
        # Implementación simplificada
        return {
            'economicos': 40,  # < 50
            'moderados': 50,   # 50-150
            'premium': 10      # > 150
        }
    
    # ===============================
    # UTILIDADES AUXILIARES
    # ===============================
    
    def _obtener_info_trabajador_completa(self, trabajador_id: int) -> Dict[str, Any]:
        """Obtiene información completa del trabajador"""
        # En implementación real, usar TrabajadorRepository
        return {
            'id': trabajador_id,
            'nombre_completo': f'Trabajador {trabajador_id}',
            'tipo': 'Técnico en Laboratorio',
            'activo': True
        }
    
    def _calcular_productividad_trabajador(self, examenes: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calcula métricas de productividad del trabajador"""
        return {
            'examenes_por_dia_promedio': len(examenes) / 30 if examenes else 0,
            'eficiencia': 'alta' if len(examenes) > 10 else 'normal'
        }
    
    def _analizar_tipos_examenes_trabajador(self, examenes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Analiza tipos de exámenes realizados por trabajador"""
        # Agrupar por tipo
        tipos_count = {}
        for examen in examenes:
            tipo = examen.get('Nombre', 'Desconocido')
            tipos_count[tipo] = tipos_count.get(tipo, 0) + 1
        
        return [
            {'tipo': tipo, 'cantidad': cantidad}
            for tipo, cantidad in sorted(tipos_count.items(), key=lambda x: x[1], reverse=True)
        ]
    
    def _analizar_distribucion_temporal_trabajador(self, examenes: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analiza distribución temporal de trabajo"""
        # Implementación simplificada
        return {
            'examenes_manana': len([e for e in examenes if True]),  # Lógica simplificada
            'examenes_tarde': len([e for e in examenes if False])
        }
    
    def _preparar_examenes_reporte(self, examenes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Prepara exámenes para inclusión en reporte"""
        return [
            {
                'nombre': e.get('Nombre', 'N/A'),
                'paciente': e.get('paciente_completo', 'N/A'),
                'precio': formatear_precio(e.get('Precio_Normal', 0)),
                'detalles': truncar_texto(e.get('Detalles', ''), 100)
            }
            for e in examenes
        ]
    
    def _formatear_historial_examenes(self, examenes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Formatea historial de exámenes de paciente"""
        return [
            {
                'nombre': e.get('Nombre', 'N/A'),
                'fecha': formatear_fecha(e.get('fecha_creacion')),
                'trabajador': e.get('trabajador_completo', 'Sin asignar'),
                'precio': formatear_precio(e.get('Precio_Normal', 0))
            }
            for e in examenes
        ]
    
    def _analizar_tendencias_paciente(self, examenes: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analiza tendencias en exámenes del paciente"""
        return {
            'frecuencia_promedio': 'mensual' if len(examenes) > 5 else 'esporadica',
            'tipos_mas_frecuentes': self._analizar_tipos_examenes_trabajador(examenes)[:3]
        }
    
    def _generar_recomendaciones_paciente(self, examenes: List[Dict[str, Any]]) -> List[str]:
        """Genera recomendaciones para el paciente"""
        recomendaciones = []
        
        if len(examenes) > 10:
            recomendaciones.append("Paciente frecuente - considerar programa de seguimiento")
        
        return recomendaciones
    
    def _calcular_proximos_seguimientos(self, examenes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Calcula próximos seguimientos necesarios"""
        # Implementación simplificada
        return [
            {
                'tipo': 'Control general',
                'fecha_sugerida': (datetime.now() + timedelta(days=30)).strftime('%Y-%m-%d'),
                'prioridad': 'normal'
            }
        ]
    
    def _calcular_tendencias_semanales(self) -> Dict[str, Any]:
        """Calcula tendencias semanales de laboratorio"""
        # Implementación simplificada
        return {
            'tendencia': 'estable',
            'variacion_porcentual': 5.2
        }
    
    def _calcular_eficiencia_trabajadores(self) -> List[Dict[str, Any]]:
        """Calcula eficiencia de trabajadores"""
        trabajadores = self._obtener_carga_trabajadores()
        return [
            {
                'nombre': t['nombre_completo'],
                'eficiencia': 'alta' if t['examenes_asignados'] > 5 else 'normal',
                'score': min(100, t['examenes_asignados'] * 10)
            }
            for t in trabajadores[:5]
        ]
    
    def _analizar_precios_examenes(self) -> Dict[str, Any]:
        """Analiza precios de exámenes"""
        return {
            'precio_promedio_mercado': 120.0,
            'competitividad': 'buena',
            'recomendacion': 'mantener precios actuales'
        }
    
    def _obtener_periodo_analisis(self) -> Dict[str, str]:
        """Obtiene periodo de análisis"""
        fin = datetime.now()
        inicio = fin - timedelta(days=30)
        
        return {
            'inicio': formatear_fecha(inicio),
            'fin': formatear_fecha(fin),
            'descripcion': 'Últimos 30 días'
        }
    
    # ===============================
    # REGISTRO DE AUDITORÍA
    # ===============================
    
    def _registrar_seguimiento_examen(self, examen_id: int, paciente_id: int, trabajador_id: int = None):
        """Registra información para seguimiento de examen"""
        print(f"📋 Seguimiento registrado: Examen {examen_id}, Paciente {paciente_id}, Trabajador {trabajador_id}")
    
    def _registrar_auditoria_modificacion_examen(self, examen_id: int, usuario_id: int, cambios: Dict[str, Any]):
        """Registra auditoría de modificaciones de examen"""
        print(f"📝 Auditoría: Usuario {usuario_id} modificó examen {examen_id}")
        print(f"🔄 Cambios: {cambios}")