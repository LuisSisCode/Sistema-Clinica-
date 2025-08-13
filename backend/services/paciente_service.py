# backend/services/paciente_service.py

import logging
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta

from ..repositories.paciente_repository import PacienteRepository
from ..repositories.consulta_repository import ConsultaRepository
from ..repositories.laboratorio_repository import LaboratorioRepository
from ..repositories.doctor_repository import DoctorRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, DatabaseTransactionError,
    validate_required, validate_positive_number
)
from ..core.utils import (
    formatear_nombre_completo, crear_respuesta_qml, preparar_para_qml,
    formatear_lista_para_combobox, safe_int, safe_float, safe_str,
    validar_rango_numerico, limpiar_texto, fecha_actual_str,
    normalize_name, validate_age, validate_required_string,
    calculate_percentage, formatear_fecha, dias_diferencia
)

logger = logging.getLogger(__name__)

class PacienteService:
    """
    Servicio de negocio para gestión integral de pacientes
    Capa entre QML Models y Repository con lógica de negocio compleja
    """
    
    def __init__(self):
        self.paciente_repository = PacienteRepository()
        self.consulta_repository = ConsultaRepository()
        self.laboratorio_repository = LaboratorioRepository()
        self.doctor_repository = DoctorRepository()
        
        print("👥 PacienteService inicializado")
    
    # ===============================
    # GESTIÓN DE PACIENTES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_paciente_completo(self, datos_paciente: Dict[str, Any]) -> Dict[str, Any]:
        """
        Crea paciente con validaciones de negocio médicas complejas
        
        Args:
            datos_paciente: {
                'nombre': str,
                'apellido_paterno': str,
                'apellido_materno': str,
                'edad': int,
                'crear_consulta_inicial': bool (opcional),
                'datos_consulta_inicial': dict (opcional)
            }
        """
        try:
            # Validaciones de negocio específicas médicas
            self._validar_datos_paciente_completos(datos_paciente)
            
            # Verificar duplicados potenciales
            duplicados_potenciales = self._detectar_duplicados_potenciales(datos_paciente)
            if duplicados_potenciales:
                return crear_respuesta_qml(
                    exito=False,
                    mensaje="Se detectaron pacientes similares que podrían ser duplicados",
                    datos={
                        'duplicados_potenciales': duplicados_potenciales,
                        'requiere_confirmacion': True
                    },
                    codigo_error="POTENTIAL_DUPLICATES"
                )
            
            # Crear paciente
            paciente_id = self.paciente_repository.create_patient(
                nombre=datos_paciente['nombre'],
                apellido_paterno=datos_paciente['apellido_paterno'],
                apellido_materno=datos_paciente['apellido_materno'],
                edad=datos_paciente['edad']
            )
            
            # Crear consulta inicial si se solicita
            consulta_inicial_id = None
            if datos_paciente.get('crear_consulta_inicial', False) and datos_paciente.get('datos_consulta_inicial'):
                consulta_inicial_id = self._crear_consulta_inicial(
                    paciente_id, 
                    datos_paciente['datos_consulta_inicial']
                )
            
            # Obtener paciente completo creado
            paciente_completo = self.paciente_repository.get_complete_patient_record(paciente_id)
            
            return crear_respuesta_qml(
                exito=True,
                mensaje=f"Paciente creado exitosamente: {datos_paciente['nombre']} {datos_paciente['apellido_paterno']}",
                datos={
                    'paciente': preparar_para_qml(paciente_completo),
                    'consulta_inicial_creada': consulta_inicial_id is not None,
                    'consulta_inicial_id': consulta_inicial_id,
                    'grupo_etario': self.paciente_repository.get_age_group(datos_paciente['edad'])
                }
            )
            
        except ValidationError as e:
            return crear_respuesta_qml(
                exito=False,
                mensaje=f"Error de validación: {e.message}",
                codigo_error=e.error_code
            )
        except Exception as e:
            logger.error(f"Error creando paciente completo: {e}")
            return crear_respuesta_qml(
                exito=False,
                mensaje="Error interno creando paciente",
                codigo_error="PATIENT_CREATE_ERROR"
            )
    
    @ExceptionHandler.handle_exception
    def obtener_paciente_dashboard(self, paciente_id: int) -> Dict[str, Any]:
        """
        Obtiene información completa del paciente para dashboard médico
        Incluye historial, estadísticas, alertas médicas, etc.
        """
        paciente = self.paciente_repository.get_complete_patient_record(paciente_id)
        
        if not paciente:
            return crear_respuesta_qml(
                exito=False,
                mensaje="Paciente no encontrado",
                codigo_error="PATIENT_NOT_FOUND"
            )
        
        # Calcular estadísticas médicas
        estadisticas_medicas = self._calcular_estadisticas_medicas(paciente)
        
        # Generar alertas médicas
        alertas_medicas = self._generar_alertas_medicas(paciente)
        
        # Preparar datos para QML
        datos_dashboard = {
            'paciente_info': {
                'id': paciente['id'],
                'nombre_completo': formatear_nombre_completo(
                    paciente['Nombre'], 
                    paciente['Apellido_Paterno'], 
                    paciente['Apellido_Materno']
                ),
                'edad': paciente['Edad'],
                'grupo_etario': self.paciente_repository.get_age_group(paciente['Edad'])
            },
            'historial_medico': {
                'consultas': paciente.get('historial_consultas', [])[:10],  # Últimas 10
                'laboratorio': paciente.get('resultados_laboratorio', [])[:10],  # Últimos 10
                'total_consultas': paciente.get('total_consultas', 0),
                'total_laboratorio': paciente.get('total_laboratorio', 0),
                'ultima_consulta': paciente.get('ultima_consulta', 'Sin consultas')
            },
            'estadisticas_medicas': estadisticas_medicas,
            'alertas_medicas': alertas_medicas,
            'resumen_atencion': {
                'frecuencia_consultas': self._calcular_frecuencia_consultas(paciente),
                'especialidades_consultadas': self._obtener_especialidades_consultadas(paciente),
                'estado_seguimiento': self._evaluar_estado_seguimiento(paciente)
            }
        }
        
        return crear_respuesta_qml(
            exito=True,
            mensaje="Dashboard de paciente obtenido",
            datos=preparar_para_qml(datos_dashboard)
        )
    
    @ExceptionHandler.handle_exception
    def buscar_pacientes_avanzado(self, criterios: Dict[str, Any]) -> Dict[str, Any]:
        """
        Búsqueda avanzada de pacientes con múltiples criterios médicos
        
        Args:
            criterios: {
                'texto': str (opcional),
                'edad_min': int (opcional),
                'edad_max': int (opcional),
                'grupo_etario': str (opcional) - 'PEDIATRICO', 'ADULTO', 'ADULTO_MAYOR',
                'con_consultas_recientes': bool (opcional),
                'sin_seguimiento': bool (opcional),
                'con_laboratorios_pendientes': bool (opcional),
                'especialidad_consultada': str (opcional),
                'limite': int (opcional, default 50)
            }
        """
        resultados = []
        limite = safe_int(criterios.get('limite', 50))
        
        # Búsqueda por texto
        if criterios.get('texto'):
            resultados = self.paciente_repository.search_patients(
                criterios['texto'], limite
            )
        else:
            resultados = self.paciente_repository.get_all()
        
        # Filtrar por grupo etario
        if criterios.get('grupo_etario'):
            grupo = criterios['grupo_etario'].upper()
            if grupo == 'PEDIATRICO':
                resultados = [p for p in resultados if p['Edad'] <= 17]
            elif grupo == 'ADULTO':
                resultados = [p for p in resultados if 18 <= p['Edad'] <= 64]
            elif grupo == 'ADULTO_MAYOR':
                resultados = [p for p in resultados if p['Edad'] >= 65]
        
        # Filtrar por rango de edad específico
        if criterios.get('edad_min') or criterios.get('edad_max'):
            edad_min = safe_int(criterios.get('edad_min', 0))
            edad_max = safe_int(criterios.get('edad_max', 120))
            resultados = [
                p for p in resultados 
                if edad_min <= p['Edad'] <= edad_max
            ]
        
        # Filtrar pacientes con consultas recientes
        if criterios.get('con_consultas_recientes', False):
            resultados = self._filtrar_pacientes_consultas_recientes(resultados)
        
        # Filtrar pacientes sin seguimiento
        if criterios.get('sin_seguimiento', False):
            resultados = self._filtrar_pacientes_sin_seguimiento(resultados)
        
        # Filtrar por especialidad consultada
        if criterios.get('especialidad_consultada'):
            resultados = self._filtrar_por_especialidad_consultada(
                resultados, criterios['especialidad_consultada']
            )
        
        # Preparar para QML
        pacientes_formateados = []
        for paciente in resultados[:limite]:
            # Obtener información adicional
            info_adicional = self._obtener_info_adicional_paciente(paciente['id'])
            
            pacientes_formateados.append({
                'id': paciente['id'],
                'nombre_completo': formatear_nombre_completo(
                    paciente['Nombre'], 
                    paciente['Apellido_Paterno'], 
                    paciente['Apellido_Materno']
                ),
                'edad': paciente['Edad'],
                'grupo_etario': self.paciente_repository.get_age_group(paciente['Edad']),
                'total_consultas': info_adicional.get('total_consultas', 0),
                'ultima_consulta': info_adicional.get('ultima_consulta', 'Sin consultas'),
                'estado_seguimiento': info_adicional.get('estado_seguimiento', 'Sin datos')
            })
        
        return crear_respuesta_qml(
            exito=True,
            mensaje=f"Se encontraron {len(pacientes_formateados)} pacientes",
            datos={
                'pacientes': pacientes_formateados,
                'total_encontrados': len(pacientes_formateados),
                'criterios_aplicados': criterios
            }
        )
    
    # ===============================
    # GESTIÓN DE HISTORIAL MÉDICO
    # ===============================
    
    @ExceptionHandler.handle_exception
    def obtener_historial_completo(self, paciente_id: int, incluir_detalles: bool = True) -> Dict[str, Any]:
        """
        Obtiene historial médico completo del paciente organizado cronológicamente
        """
        paciente = self.paciente_repository.get_complete_patient_record(paciente_id)
        
        if not paciente:
            return crear_respuesta_qml(
                exito=False,
                mensaje="Paciente no encontrado"
            )
        
        # Organizar historial cronológicamente
        historial_organizado = self._organizar_historial_cronologico(paciente, incluir_detalles)
        
        # Generar resumen médico
        resumen_medico = self._generar_resumen_medico(paciente)
        
        return crear_respuesta_qml(
            exito=True,
            mensaje="Historial médico obtenido",
            datos={
                'paciente_info': {
                    'nombre_completo': formatear_nombre_completo(
                        paciente['Nombre'], paciente['Apellido_Paterno'], paciente['Apellido_Materno']
                    ),
                    'edad': paciente['Edad'],
                    'grupo_etario': self.paciente_repository.get_age_group(paciente['Edad'])
                },
                'historial_cronologico': historial_organizado,
                'resumen_medico': resumen_medico,
                'estadisticas': {
                    'total_eventos': len(historial_organizado),
                    'total_consultas': paciente.get('total_consultas', 0),
                    'total_laboratorio': paciente.get('total_laboratorio', 0)
                }
            }
        )
    
    @ExceptionHandler.handle_exception
    def analizar_patron_consultas(self, paciente_id: int) -> Dict[str, Any]:
        """
        Analiza patrones de consultas del paciente para insights médicos
        """
        paciente = self.paciente_repository.get_patient_with_consultations(paciente_id)
        
        if not paciente:
            return crear_respuesta_qml(
                exito=False,
                mensaje="Paciente no encontrado"
            )
        
        consultas = paciente.get('consultas', [])
        
        if not consultas:
            return crear_respuesta_qml(
                exito=True,
                mensaje="No hay consultas para analizar",
                datos={'analisis': 'Sin datos suficientes'}
            )
        
        # Análisis de patrones
        analisis = {
            'frecuencia': self._analizar_frecuencia_consultas(consultas),
            'especialidades_preferidas': self._analizar_especialidades_preferidas(consultas),
            'tendencia_temporal': self._analizar_tendencia_temporal(consultas),
            'alertas_medicas': self._detectar_alertas_patron_consultas(consultas),
            'recomendaciones': self._generar_recomendaciones_seguimiento(consultas)
        }
        
        return crear_respuesta_qml(
            exito=True,
            mensaje="Análisis de patrones completado",
            datos=preparar_para_qml(analisis)
        )
    
    # ===============================
    # ESTADÍSTICAS Y REPORTES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def obtener_estadisticas_generales(self) -> Dict[str, Any]:
        """Obtiene estadísticas generales de pacientes para dashboard administrativo"""
        stats = self.paciente_repository.get_patient_statistics()
        pacientes_frecuentes = self.paciente_repository.get_most_frequent_patients(10)
        pacientes_sin_seguimiento = self.paciente_repository.get_patients_without_recent_visits(90)
        
        # Calcular métricas adicionales
        metricas_adicionales = self._calcular_metricas_poblacion()
        
        datos_estadisticas = {
            'resumen_general': {
                'total_pacientes': stats['general']['total_pacientes'],
                'edad_promedio': round(stats['general']['edad_promedio'], 1),
                'edad_minima': stats['general']['edad_minima'],
                'edad_maxima': stats['general']['edad_maxima']
            },
            'distribucion_edades': {
                'pediatricos': stats['por_edades']['pediatricos'],
                'adultos': stats['por_edades']['adultos'],
                'adultos_mayores': stats['por_edades']['adultos_mayores']
            },
            'pacientes_frecuentes': [
                {
                    'id': p['id'],
                    'nombre_completo': formatear_nombre_completo(
                        p['Nombre'], p['Apellido_Paterno'], p['Apellido_Materno']
                    ),
                    'edad': p['Edad'],
                    'total_consultas': p['total_consultas'],
                    'ultima_consulta': formatear_fecha(p['ultima_consulta'])
                }
                for p in pacientes_frecuentes
            ],
            'alertas_seguimiento': {
                'pacientes_sin_seguimiento': len(pacientes_sin_seguimiento),
                'requieren_atencion': self._identificar_pacientes_atencion_prioritaria()
            },
            'metricas_poblacion': metricas_adicionales
        }
        
        return crear_respuesta_qml(
            exito=True,
            mensaje="Estadísticas obtenidas",
            datos=preparar_para_qml(datos_estadisticas)
        )
    
    @ExceptionHandler.handle_exception
    def generar_reporte_poblacional(self, criterios_filtro: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Genera reporte poblacional de pacientes con análisis epidemiológico
        """
        criterios = criterios_filtro or {}
        
        # Obtener pacientes según criterios
        if criterios:
            resultado_busqueda = self.buscar_pacientes_avanzado(criterios)
            pacientes = resultado_busqueda['datos']['pacientes']
        else:
            pacientes = self.paciente_repository.get_all()
        
        if not pacientes:
            return crear_respuesta_qml(
                exito=False,
                mensaje="No se encontraron pacientes con los criterios especificados"
            )
        
        # Análisis poblacional
        analisis_poblacional = {
            'demografia': self._analizar_demografia_poblacional(pacientes),
            'utilizacion_servicios': self._analizar_utilizacion_servicios(pacientes),
            'patrones_atencion': self._analizar_patrones_atencion_poblacional(pacientes),
            'indicadores_salud': self._calcular_indicadores_salud_poblacional(pacientes)
        }
        
        reporte = {
            'metadata': {
                'fecha_generacion': fecha_actual_str(),
                'total_pacientes_analizados': len(pacientes),
                'criterios_filtro': criterios
            },
            'analisis_poblacional': analisis_poblacional,
            'conclusiones': self._generar_conclusiones_poblacionales(analisis_poblacional),
            'recomendaciones': self._generar_recomendaciones_poblacionales(analisis_poblacional)
        }
        
        return crear_respuesta_qml(
            exito=True,
            mensaje="Reporte poblacional generado",
            datos=preparar_para_qml(reporte)
        )
    
    # ===============================
    # VALIDACIONES DE NEGOCIO MÉDICAS
    # ===============================
    
    def _validar_datos_paciente_completos(self, datos: Dict[str, Any]):
        """Validaciones específicas de negocio médico para crear paciente"""
        # Validaciones básicas
        validate_required(datos.get('nombre'), 'nombre')
        validate_required(datos.get('apellido_paterno'), 'apellido_paterno')
        validate_required(datos.get('apellido_materno'), 'apellido_materno')
        
        # Validar edad en rango médico válido
        edad = safe_int(datos.get('edad', 0))
        if not validar_rango_numerico(edad, 0, 120):
            raise ValidationError("edad", edad, "Edad debe estar entre 0 y 120 años")
        
        # Validaciones específicas por grupo etario
        if edad < 18:
            # Paciente pediátrico - validaciones especiales
            self._validar_paciente_pediatrico(datos)
        elif edad >= 65:
            # Adulto mayor - validaciones especiales
            self._validar_paciente_adulto_mayor(datos)
        
        # Validar nombres apropiados
        nombre = limpiar_texto(datos.get('nombre', ''))
        if len(nombre) < 2:
            raise ValidationError("nombre", nombre, "Nombre debe tener al menos 2 caracteres")
        
        # Detectar nombres potencialmente problemáticos
        nombres_problematicos = ['test', 'prueba', 'ejemplo', 'xxx', 'aaa']
        if nombre.lower() in nombres_problematicos:
            raise ValidationError("nombre", nombre, "Nombre no parece válido para un paciente")
    
    def _validar_paciente_pediatrico(self, datos: Dict[str, Any]):
        """Validaciones específicas para pacientes pediátricos"""
        edad = datos.get('edad', 0)
        
        # Log para seguimiento pediátrico
        logger.info(f"Creando paciente pediátrico de {edad} años")
        
        # Verificar que se considera protocolo pediátrico
        if 'datos_consulta_inicial' in datos:
            consulta_data = datos['datos_consulta_inicial']
            if not consulta_data.get('protocolo_pediatrico', False):
                logger.warning("Paciente pediátrico sin protocolo pediátrico especificado")
    
    def _validar_paciente_adulto_mayor(self, datos: Dict[str, Any]):
        """Validaciones específicas para adultos mayores"""
        edad = datos.get('edad', 0)
        
        # Log para seguimiento geriátrico
        logger.info(f"Creando paciente adulto mayor de {edad} años")
        
        # Sugerir evaluación geriátrica
        if edad >= 75:
            logger.info("Paciente de edad avanzada - considerar evaluación geriátrica integral")
    
    def _detectar_duplicados_potenciales(self, datos: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Detecta pacientes que podrían ser duplicados"""
        nombre = datos.get('nombre', '').strip()
        apellido_paterno = datos.get('apellido_paterno', '').strip()
        
        # Buscar pacientes con nombres similares
        pacientes_similares = self.paciente_repository.get_patients_by_name(
            nombre, apellido_paterno
        )
        
        duplicados_potenciales = []
        for paciente in pacientes_similares:
            # Calcular similitud
            similitud = self._calcular_similitud_paciente(datos, paciente)
            if similitud > 0.8:  # 80% de similitud
                duplicados_potenciales.append({
                    'paciente': paciente,
                    'similitud': similitud,
                    'diferencias': self._identificar_diferencias(datos, paciente)
                })
        
        return duplicados_potenciales
    
    # ===============================
    # MÉTODOS DE ANÁLISIS MÉDICO
    # ===============================
    
    def _calcular_estadisticas_medicas(self, paciente: Dict[str, Any]) -> Dict[str, Any]:
        """Calcula estadísticas médicas específicas del paciente"""
        consultas = paciente.get('historial_consultas', [])
        laboratorio = paciente.get('resultados_laboratorio', [])
        
        # Frecuencia de atención
        frecuencia_atencion = self._calcular_frecuencia_atencion(consultas)
        
        # Especialidades más consultadas
        especialidades = self._analizar_especialidades_consultadas(consultas)
        
        # Estado de seguimiento médico
        estado_seguimiento = self._evaluar_estado_seguimiento_medico(consultas, laboratorio)
        
        return {
            'frecuencia_atencion': frecuencia_atencion,
            'especialidades_consultadas': especialidades,
            'estado_seguimiento': estado_seguimiento,
            'indicadores_salud': {
                'total_consultas': len(consultas),
                'total_laboratorios': len(laboratorio),
                'ultima_atencion': self._obtener_ultima_atencion(consultas, laboratorio),
                'adherencia_seguimiento': self._calcular_adherencia_seguimiento(consultas)
            }
        }
    
    def _generar_alertas_medicas(self, paciente: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Genera alertas médicas basadas en el historial del paciente"""
        alertas = []
        consultas = paciente.get('historial_consultas', [])
        edad = paciente['Edad']
        
        # Alerta por falta de seguimiento
        if consultas:
            ultima_consulta = consultas[0]['Fecha']
            dias_sin_consulta = dias_diferencia(ultima_consulta, fecha_actual_str())
            
            if dias_sin_consulta > 365:
                alertas.append({
                    'tipo': 'seguimiento',
                    'prioridad': 'media',
                    'mensaje': f'Sin consultas hace {dias_sin_consulta} días',
                    'recomendacion': 'Agendar consulta de seguimiento'
                })
        else:
            alertas.append({
                'tipo': 'seguimiento',
                'prioridad': 'alta',
                'mensaje': 'Paciente sin historial de consultas',
                'recomendacion': 'Agendar consulta inicial'
            })
        
        # Alertas por grupo etario
        if edad >= 65:
            alertas.append({
                'tipo': 'preventivo',
                'prioridad': 'baja',
                'mensaje': 'Adulto mayor - requiere atención geriátrica',
                'recomendacion': 'Evaluación geriátrica integral anual'
            })
        elif edad <= 17:
            alertas.append({
                'tipo': 'preventivo',
                'prioridad': 'baja',
                'mensaje': 'Paciente pediátrico - seguir protocolo pediátrico',
                'recomendacion': 'Controles según cronograma pediátrico'
            })
        
        # Alerta por frecuencia alta de consultas
        if len(consultas) > 10:
            alertas.append({
                'tipo': 'clinico',
                'prioridad': 'media',
                'mensaje': 'Paciente con alta frecuencia de consultas',
                'recomendacion': 'Evaluar plan de manejo integral'
            })
        
        return alertas
    
    def _organizar_historial_cronologico(self, paciente: Dict[str, Any], incluir_detalles: bool) -> List[Dict[str, Any]]:
        """Organiza historial médico en orden cronológico"""
        eventos = []
        
        # Agregar consultas
        for consulta in paciente.get('historial_consultas', []):
            evento = {
                'tipo': 'consulta',
                'fecha': consulta['Fecha'],
                'titulo': f"Consulta - {consulta.get('especialidad', 'Sin especialidad')}",
                'doctor': consulta.get('doctor_completo', 'Sin doctor'),
                'detalles': consulta.get('Detalles', '') if incluir_detalles else ''
            }
            eventos.append(evento)
        
        # Agregar laboratorios
        for lab in paciente.get('resultados_laboratorio', []):
            evento = {
                'tipo': 'laboratorio',
                'fecha': lab.get('fecha_realizacion', ''),  # Asumir campo fecha
                'titulo': f"Laboratorio - {lab.get('Nombre', 'Sin nombre')}",
                'trabajador': lab.get('trabajador_encargado', 'Sin asignar'),
                'detalles': lab.get('Detalles', '') if incluir_detalles else ''
            }
            eventos.append(evento)
        
        # Ordenar por fecha (más reciente primero)
        eventos.sort(key=lambda x: x['fecha'], reverse=True)
        
        return eventos
    
    def _crear_consulta_inicial(self, paciente_id: int, datos_consulta: Dict[str, Any]) -> Optional[int]:
        """Crea consulta inicial para paciente recién registrado"""
        try:
            # Validar datos de consulta
            validate_required(datos_consulta.get('usuario_id'), 'usuario_id')
            validate_required(datos_consulta.get('especialidad_id'), 'especialidad_id')
            validate_required(datos_consulta.get('detalles'), 'detalles')
            
            # Crear consulta usando el repository de consultas
            consulta_id = self.consulta_repository.create_consultation(
                usuario_id=datos_consulta['usuario_id'],
                paciente_id=paciente_id,
                especialidad_id=datos_consulta['especialidad_id'],
                detalles=datos_consulta['detalles']
            )
            
            return consulta_id
            
        except Exception as e:
            logger.error(f"Error creando consulta inicial: {e}")
            return None
    
    # ===============================
    # ANÁLISIS POBLACIONAL
    # ===============================
    
    def _analizar_demografia_poblacional(self, pacientes: List[Dict]) -> Dict[str, Any]:
        """Analiza demografía de la población de pacientes"""
        total = len(pacientes)
        if total == 0:
            return {}
        
        # Distribución por grupos etarios
        pediatricos = sum(1 for p in pacientes if p['Edad'] <= 17)
        adultos = sum(1 for p in pacientes if 18 <= p['Edad'] <= 64)
        adultos_mayores = sum(1 for p in pacientes if p['Edad'] >= 65)
        
        # Estadísticas de edad
        edades = [p['Edad'] for p in pacientes]
        edad_promedio = sum(edades) / len(edades)
        
        return {
            'total_pacientes': total,
            'distribucion_etaria': {
                'pediatricos': {'cantidad': pediatricos, 'porcentaje': round((pediatricos/total)*100, 1)},
                'adultos': {'cantidad': adultos, 'porcentaje': round((adultos/total)*100, 1)},
                'adultos_mayores': {'cantidad': adultos_mayores, 'porcentaje': round((adultos_mayores/total)*100, 1)}
            },
            'estadisticas_edad': {
                'promedio': round(edad_promedio, 1),
                'minima': min(edades),
                'maxima': max(edades)
            }
        }
    
    def _analizar_utilizacion_servicios(self, pacientes: List[Dict]) -> Dict[str, Any]:
        """Analiza utilización de servicios médicos por la población"""
        pacientes_con_consultas = 0
        total_consultas = 0
        
        for paciente in pacientes:
            info_adicional = self._obtener_info_adicional_paciente(paciente['id'])
            consultas_paciente = info_adicional.get('total_consultas', 0)
            
            if consultas_paciente > 0:
                pacientes_con_consultas += 1
                total_consultas += consultas_paciente
        
        return {
            'pacientes_activos': {
                'cantidad': pacientes_con_consultas,
                'porcentaje': round((pacientes_con_consultas/len(pacientes))*100, 1) if pacientes else 0
            },
            'utilizacion_promedio': round(total_consultas/len(pacientes), 2) if pacientes else 0,
            'total_consultas_poblacion': total_consultas
        }
    
    # ===============================
    # MÉTODOS DE UTILIDAD PARA QML
    # ===============================
    
    @ExceptionHandler.handle_exception
    def obtener_lista_pacientes_combobox(self, incluir_estadisticas: bool = False) -> Dict[str, Any]:
        """Obtiene lista de pacientes formateada para ComboBox en QML"""
        pacientes = self.paciente_repository.get_all()
        
        pacientes_formateados = formatear_lista_para_combobox(
            pacientes,
            key_id='id',
            key_text='Nombre'  # Se formateará más abajo
        )
        
        # Formatear texto con nombre completo
        for paciente in pacientes_formateados:
            datos = paciente['data']
            paciente['text'] = formatear_nombre_completo(
                datos['Nombre'],
                datos['Apellido_Paterno'],
                datos['Apellido_Materno']
            )
            paciente['edad'] = datos['Edad']
            paciente['grupo_etario'] = self.paciente_repository.get_age_group(datos['Edad'])
            
            # Incluir estadísticas si se solicita
            if incluir_estadisticas:
                info_adicional = self._obtener_info_adicional_paciente(datos['id'])
                paciente['total_consultas'] = info_adicional.get('total_consultas', 0)
                paciente['ultima_consulta'] = info_adicional.get('ultima_consulta', 'Sin consultas')
        
        return crear_respuesta_qml(
            exito=True,
            mensaje="Lista de pacientes obtenida",
            datos={'pacientes': pacientes_formateados}
        )
    
    @ExceptionHandler.handle_exception
    def validar_edad_apropiada(self, edad: int, tipo_consulta: str = 'general') -> Dict[str, Any]:
        """Valida si la edad es apropiada para el tipo de consulta"""
        es_valida = validar_rango_numerico(edad, 0, 120)
        advertencias = []
        
        if not es_valida:
            return crear_respuesta_qml(
                exito=False,
                mensaje="Edad fuera del rango válido (0-120 años)"
            )
        
        # Advertencias específicas por tipo de consulta
        if tipo_consulta.lower() == 'pediatrica' and edad >= 18:
            advertencias.append("Edad fuera del rango pediátrico")
        elif tipo_consulta.lower() == 'geriatrica' and edad < 65:
            advertencias.append("Edad fuera del rango geriátrico")
        
        # Recomendaciones por grupo etario
        recomendaciones = []
        if edad <= 17:
            recomendaciones.append("Considerar protocolo pediátrico")
        elif edad >= 65:
            recomendaciones.append("Considerar evaluación geriátrica")
        
        return crear_respuesta_qml(
            exito=True,
            mensaje="Edad validada",
            datos={
                'edad_valida': es_valida,
                'grupo_etario': self.paciente_repository.get_age_group(edad),
                'advertencias': advertencias,
                'recomendaciones': recomendaciones
            }
        )
    
    # ===============================
    # MÉTODOS AUXILIARES PRIVADOS
    # ===============================
    
    def _obtener_info_adicional_paciente(self, paciente_id: int) -> Dict[str, Any]:
        """Obtiene información adicional de un paciente (consultas, etc.)"""
        try:
            paciente_completo = self.paciente_repository.get_patient_with_consultations(paciente_id)
            if paciente_completo:
                return {
                    'total_consultas': paciente_completo.get('total_consultas', 0),
                    'ultima_consulta': paciente_completo.get('ultima_consulta', 'Sin consultas'),
                    'estado_seguimiento': 'Activo' if paciente_completo.get('total_consultas', 0) > 0 else 'Inactivo'
                }
        except Exception:
            pass
        
        return {
            'total_consultas': 0,
            'ultima_consulta': 'Sin consultas',
            'estado_seguimiento': 'Sin datos'
        }
    
    def _calcular_similitud_paciente(self, datos_nuevos: Dict, paciente_existente: Dict) -> float:
        """Calcula similitud entre datos de paciente nuevo y existente"""
        similitud = 0.0
        criterios = 0
        
        # Comparar nombre
        if datos_nuevos.get('nombre', '').lower() == paciente_existente.get('Nombre', '').lower():
            similitud += 0.4
        criterios += 1
        
        # Comparar apellido paterno
        if datos_nuevos.get('apellido_paterno', '').lower() == paciente_existente.get('Apellido_Paterno', '').lower():
            similitud += 0.4
        criterios += 1
        
        # Comparar edad (margen de ±2 años)
        edad_nueva = datos_nuevos.get('edad', 0)
        edad_existente = paciente_existente.get('Edad', 0)
        if abs(edad_nueva - edad_existente) <= 2:
            similitud += 0.2
        criterios += 1
        
        return similitud
    
    def _identificar_diferencias(self, datos_nuevos: Dict, paciente_existente: Dict) -> List[str]:
        """Identifica diferencias entre paciente nuevo y existente"""
        diferencias = []
        
        if datos_nuevos.get('apellido_materno', '').lower() != paciente_existente.get('Apellido_Materno', '').lower():
            diferencias.append(f"Apellido materno: '{datos_nuevos.get('apellido_materno')}' vs '{paciente_existente.get('Apellido_Materno')}'")
        
        edad_diff = abs(datos_nuevos.get('edad', 0) - paciente_existente.get('Edad', 0))
        if edad_diff > 0:
            diferencias.append(f"Diferencia de edad: {edad_diff} años")
        
        return diferencias
    
    def _calcular_frecuencia_consultas(self, paciente: Dict[str, Any]) -> str:
        """Calcula frecuencia de consultas del paciente"""
        total_consultas = paciente.get('total_consultas', 0)
        
        if total_consultas == 0:
            return "Sin consultas"
        elif total_consultas <= 2:
            return "Baja frecuencia"
        elif total_consultas <= 5:
            return "Frecuencia normal"
        else:
            return "Alta frecuencia"
    
    def _obtener_especialidades_consultadas(self, paciente: Dict[str, Any]) -> List[str]:
        """Obtiene lista de especialidades consultadas por el paciente"""
        consultas = paciente.get('historial_consultas', [])
        especialidades = set()
        
        for consulta in consultas:
            especialidad = consulta.get('especialidad', 'Sin especialidad')
            especialidades.add(especialidad)
        
        return list(especialidades)
    
    def _evaluar_estado_seguimiento(self, paciente: Dict[str, Any]) -> str:
        """Evalúa estado de seguimiento del paciente"""
        total_consultas = paciente.get('total_consultas', 0)
        ultima_consulta = paciente.get('ultima_consulta')
        
        if total_consultas == 0:
            return "Sin seguimiento"
        
        if ultima_consulta:
            dias_sin_consulta = dias_diferencia(ultima_consulta, fecha_actual_str())
            if dias_sin_consulta <= 30:
                return "Seguimiento activo"
            elif dias_sin_consulta <= 90:
                return "Seguimiento regular"
            elif dias_sin_consulta <= 365:
                return "Seguimiento esporádico"
            else:
                return "Sin seguimiento reciente"
        
        return "Estado indeterminado"

# Instancia global del servicio
paciente_service = PacienteService()