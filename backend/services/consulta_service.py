"""
Servicio de Consultas Médicas - Lógica de Negocio
Orquesta operaciones complejas y reglas de negocio específicas del dominio médico
"""

from typing import List, Dict, Any, Optional, Tuple, Union
from datetime import datetime, timedelta, date
from decimal import Decimal

from ..core.excepciones import (
    ValidationError, ExceptionHandler, ClinicaBaseException,
    validate_required, safe_execute
)
from ..core.utils import (
    formatear_fecha, formatear_precio, preparar_para_qml, crear_respuesta_qml,
    calcular_porcentaje, formatear_nombre_completo, truncar_texto,
    validar_rango_numerico, limpiar_texto, safe_int, safe_float
)
from ..repositories.consulta_repository import ConsultaRepository
from ..repositories.paciente_repository import PacienteRepository
from ..repositories.doctor_repository import DoctorRepository
from ..repositories.usuario_repository import UsuarioRepository

class ConsultaService:
    """
    Servicio para gestión avanzada de consultas médicas
    Implementa lógica de negocio, validaciones complejas y orquestación
    """
    
    def __init__(self):
        self.consulta_repo = ConsultaRepository()
        self.paciente_repo = PacienteRepository()
        self.doctor_repo = DoctorRepository()
        self.usuario_repo = UsuarioRepository()
        
        # Configuraciones de negocio
        self.MAX_CONSULTAS_POR_DIA_PACIENTE = 3
        self.HORAS_MINIMAS_ENTRE_CONSULTAS = 2
        self.DIAS_PARA_SEGUIMIENTO = 30
        self.PRECIO_MINIMO_CONSULTA = 50.0
        self.PRECIO_MAXIMO_CONSULTA = 1000.0
        
        print("🩺 ConsultaService inicializado")
    
    # ===============================
    # OPERACIONES DE CREACIÓN AVANZADA
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_consulta_completa(self, datos_consulta: Dict[str, Any], 
                              usuario_id: int) -> Dict[str, Any]:
        """
        Crea consulta con validaciones de negocio completas y lógica avanzada
        
        Args:
            datos_consulta: {
                'paciente_info': {...},  # Si es nuevo paciente
                'paciente_id': int,      # Si es paciente existente
                'especialidad_id': int,
                'tipo_consulta': 'normal|emergencia',
                'detalles': str,
                'fecha': datetime (opcional)
            }
            usuario_id: ID del usuario que registra
            
        Returns:
            Dict con resultado completo de la operación
        """
        resultado = {
            'exito': False,
            'consulta_id': None,
            'paciente_id': None,
            'detalles_operacion': {},
            'advertencias': []
        }
        
        try:
            # 1. Validar datos básicos
            self._validar_datos_consulta(datos_consulta)
            
            # 2. Obtener o crear paciente
            paciente_id = self._gestionar_paciente(
                datos_consulta.get('paciente_info'),
                datos_consulta.get('paciente_id')
            )
            resultado['paciente_id'] = paciente_id
            
            # 3. Validar especialidad y doctor
            especialidad = self._validar_especialidad(datos_consulta['especialidad_id'])
            
            # 4. Aplicar reglas de negocio
            advertencias = self._aplicar_reglas_negocio_consulta(
                paciente_id, 
                datos_consulta['especialidad_id'],
                datos_consulta.get('fecha')
            )
            resultado['advertencias'] = advertencias
            
            # 5. Calcular precio según tipo
            precio_calculado = self._calcular_precio_consulta(
                especialidad,
                datos_consulta.get('tipo_consulta', 'normal')
            )
            
            # 6. Crear la consulta
            consulta_id = self.consulta_repo.create_consultation(
                usuario_id=usuario_id,
                paciente_id=paciente_id,
                especialidad_id=datos_consulta['especialidad_id'],
                detalles=datos_consulta['detalles'],
                fecha=datos_consulta.get('fecha')
            )
            
            # 7. Registrar estadísticas y seguimiento
            self._registrar_seguimiento_consulta(consulta_id, paciente_id)
            
            # 8. Generar respuesta completa
            consulta_completa = self.obtener_consulta_completa(consulta_id)
            
            resultado.update({
                'exito': True,
                'consulta_id': consulta_id,
                'precio_calculado': precio_calculado,
                'consulta_completa': consulta_completa,
                'detalles_operacion': {
                    'paciente_nuevo': 'paciente_info' in datos_consulta,
                    'tipo_consulta': datos_consulta.get('tipo_consulta', 'normal'),
                    'precio': formatear_precio(precio_calculado),
                    'especialidad': especialidad['Nombre'],
                    'doctor': especialidad.get('doctor_completo', 'N/A')
                }
            })
            
            print(f"✅ Consulta creada exitosamente: ID {consulta_id}")
            return resultado
            
        except Exception as e:
            resultado['error'] = str(e)
            raise ClinicaBaseException(f"Error creando consulta: {str(e)}")
    
    @ExceptionHandler.handle_exception
    def actualizar_consulta_con_validaciones(self, consulta_id: int, 
                                           nuevos_datos: Dict[str, Any], 
                                           usuario_id: int) -> Dict[str, Any]:
        """
        Actualiza consulta con validaciones de negocio y auditoría
        """
        # Validar existencia y permisos
        consulta_actual = self.consulta_repo.get_consultation_by_id_complete(consulta_id)
        if not consulta_actual:
            raise ValidationError("consulta_id", consulta_id, "Consulta no encontrada")
        
        # Validar si se puede modificar (ej: no muy antigua)
        self._validar_modificacion_permitida(consulta_actual)
        
        # Aplicar cambios con registro de auditoría
        success = self.consulta_repo.update_consultation(
            consulta_id=consulta_id,
            detalles=nuevos_datos.get('detalles'),
            fecha=nuevos_datos.get('fecha')
        )
        
        if success:
            # Registrar auditoría
            self._registrar_auditoria_modificacion(consulta_id, usuario_id, nuevos_datos)
            
            consulta_actualizada = self.obtener_consulta_completa(consulta_id)
            
            return crear_respuesta_qml(
                exito=True,
                mensaje="Consulta actualizada correctamente",
                datos=consulta_actualizada
            )
        
        return crear_respuesta_qml(False, "Error actualizando consulta")
    
    # ===============================
    # BÚSQUEDAS Y FILTROS AVANZADOS
    # ===============================
    
    @ExceptionHandler.handle_exception
    def buscar_consultas_avanzado(self, criterios: Dict[str, Any]) -> Dict[str, Any]:
        """
        Búsqueda avanzada con múltiples criterios y agregaciones
        
        Args:
            criterios: {
                'texto': str,
                'fecha_inicio': str,
                'fecha_fin': str,
                'doctor_id': int,
                'especialidad_id': int,
                'paciente_id': int,
                'tipo_consulta': str,
                'estado_seguimiento': str,
                'precio_min': float,
                'precio_max': float,
                'incluir_estadisticas': bool,
                'pagina': int,
                'por_pagina': int
            }
        """
        try:
            # Procesar fechas
            fecha_inicio = self._parsear_fecha_criterio(criterios.get('fecha_inicio'))
            fecha_fin = self._parsear_fecha_criterio(criterios.get('fecha_fin'))
            
            # Realizar búsqueda base
            consultas = []
            
            if criterios.get('texto'):
                consultas = self.consulta_repo.search_consultations(
                    search_term=criterios['texto'],
                    start_date=fecha_inicio,
                    end_date=fecha_fin,
                    limit=criterios.get('por_pagina', 50)
                )
            elif fecha_inicio and fecha_fin:
                consultas = self.consulta_repo.get_consultations_by_date_range(
                    fecha_inicio, fecha_fin
                )
            else:
                consultas = self.consulta_repo.get_all_with_details(
                    limit=criterios.get('por_pagina', 50)
                )
            
            # Aplicar filtros adicionales
            consultas_filtradas = self._aplicar_filtros_avanzados(consultas, criterios)
            
            # Enriquecer datos
            consultas_enriquecidas = self._enriquecer_consultas(consultas_filtradas)
            
            # Calcular estadísticas si se solicitan
            estadisticas = {}
            if criterios.get('incluir_estadisticas', False):
                estadisticas = self._calcular_estadisticas_busqueda(consultas_filtradas)
            
            # Aplicar paginación
            pagina = criterios.get('pagina', 1)
            por_pagina = criterios.get('por_pagina', 50)
            consultas_paginadas = self._paginar_resultados(
                consultas_enriquecidas, pagina, por_pagina
            )
            
            return {
                'exito': True,
                'consultas': consultas_paginadas['data'],
                'paginacion': {
                    'pagina_actual': pagina,
                    'por_pagina': por_pagina,
                    'total_registros': len(consultas_enriquecidas),
                    'total_paginas': consultas_paginadas['pages']
                },
                'estadisticas': estadisticas,
                'criterios_aplicados': self._resumir_criterios(criterios)
            }
            
        except Exception as e:
            return crear_respuesta_qml(
                exito=False,
                mensaje=f"Error en búsqueda avanzada: {str(e)}",
                codigo_error="SEARCH_ERROR"
            )
    
    def obtener_consulta_completa(self, consulta_id: int) -> Dict[str, Any]:
        """Obtiene consulta con toda la información relacionada y enriquecida"""
        consulta = self.consulta_repo.get_consultation_by_id_complete(consulta_id)
        if not consulta:
            raise ValidationError("consulta_id", consulta_id, "Consulta no encontrada")
        
        # Enriquecer con información adicional
        consulta_enriquecida = self._enriquecer_consulta_individual(consulta)
        
        return preparar_para_qml(consulta_enriquecida)
    
    # ===============================
    # ESTADÍSTICAS Y REPORTES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def generar_reporte_medico_completo(self, doctor_id: int, 
                                      fecha_inicio: datetime = None,
                                      fecha_fin: datetime = None) -> Dict[str, Any]:
        """Genera reporte completo de actividad médica"""
        if fecha_fin is None:
            fecha_fin = datetime.now()
        if fecha_inicio is None:
            fecha_inicio = fecha_fin - timedelta(days=30)
        
        # Obtener consultas del doctor
        consultas = self.consulta_repo.get_consultations_by_doctor(
            doctor_id, limit=1000
        )
        
        # Filtrar por rango de fechas
        consultas_periodo = [
            c for c in consultas 
            if fecha_inicio <= c['Fecha'] <= fecha_fin
        ]
        
        # Calcular métricas
        reporte = {
            'doctor_info': self._obtener_info_doctor(doctor_id),
            'periodo': {
                'inicio': formatear_fecha(fecha_inicio),
                'fin': formatear_fecha(fecha_fin),
                'dias': (fecha_fin - fecha_inicio).days
            },
            'resumen_numerico': {
                'total_consultas': len(consultas_periodo),
                'consultas_normales': len([c for c in consultas_periodo if 'Normal' in str(c.get('tipo', ''))]),
                'consultas_emergencia': len([c for c in consultas_periodo if 'Emergencia' in str(c.get('tipo', ''))]),
                'pacientes_unicos': len(set(c['Id_Paciente'] for c in consultas_periodo)),
                'ingresos_estimados': sum(safe_float(c.get('Precio_Normal', 0)) for c in consultas_periodo)
            },
            'tendencias': self._calcular_tendencias_doctor(consultas_periodo),
            'especialidades_mas_solicitadas': self._obtener_especialidades_top(consultas_periodo),
            'distribucion_horaria': self._analizar_distribucion_horaria(consultas_periodo),
            'consultas_detalladas': self._preparar_consultas_reporte(consultas_periodo[:50])
        }
        
        return preparar_para_qml(reporte)
    
    @ExceptionHandler.handle_exception
    def obtener_dashboard_consultas(self) -> Dict[str, Any]:
        """Obtiene datos para dashboard de consultas"""
        try:
            # Estadísticas generales
            stats_generales = self.consulta_repo.get_consultation_statistics()
            stats_hoy = self.consulta_repo.get_today_statistics()
            
            # Tendencias recientes
            tendencias = self.consulta_repo.get_consultation_trends(months=6)
            
            # Top pacientes
            pacientes_frecuentes = self.consulta_repo.get_most_frequent_patients(limit=10)
            
            # Consultas recientes
            consultas_recientes = self.consulta_repo.get_recent_consultations(days=7)
            
            # Métricas calculadas
            dashboard = {
                'metricas_hoy': {
                    'consultas_hoy': stats_hoy.get('consultas_hoy', 0),
                    'pacientes_hoy': stats_hoy.get('pacientes_hoy', 0),
                    'doctores_activos': stats_hoy.get('doctores_activos_hoy', 0)
                },
                'metricas_generales': {
                    'total_consultas': stats_generales['general'].get('total_consultas', 0),
                    'pacientes_unicos': stats_generales['general'].get('pacientes_unicos', 0),
                    'especialidades_activas': stats_generales['general'].get('especialidades_utilizadas', 0),
                    'promedio_dias_entre_consultas': safe_float(
                        stats_generales['general'].get('dias_promedio_entre_consultas', 0)
                    )
                },
                'tendencias_mensuales': self._formatear_tendencias_dashboard(tendencias),
                'top_especialidades': stats_generales.get('por_especialidad', [])[:5],
                'top_doctores': stats_generales.get('por_doctor', [])[:5],
                'pacientes_frecuentes': self._formatear_pacientes_frecuentes(pacientes_frecuentes),
                'consultas_recientes': self._formatear_consultas_recientes(consultas_recientes[:10]),
                'alertas': self._generar_alertas_dashboard()
            }
            
            return preparar_para_qml(dashboard)
            
        except Exception as e:
            return crear_respuesta_qml(
                exito=False,
                mensaje=f"Error generando dashboard: {str(e)}",
                codigo_error="DASHBOARD_ERROR"
            )
    
    # ===============================
    # VALIDACIONES DE NEGOCIO
    # ===============================
    
    def _validar_datos_consulta(self, datos: Dict[str, Any]):
        """Valida datos básicos de consulta"""
        # Validar que tenga paciente (nuevo o existente)
        if not datos.get('paciente_id') and not datos.get('paciente_info'):
            raise ValidationError("paciente", None, "Debe especificar paciente")
        
        # Validar especialidad
        validate_required(datos.get('especialidad_id'), "especialidad_id")
        
        # Validar detalles
        detalles = datos.get('detalles', '').strip()
        if len(detalles) < 10:
            raise ValidationError("detalles", detalles, "Detalles deben tener al menos 10 caracteres")
        
        if len(detalles) > 2000:
            raise ValidationError("detalles", len(detalles), "Detalles muy largos (máximo 2000 caracteres)")
        
        # Validar tipo de consulta
        tipo_consulta = datos.get('tipo_consulta', 'normal').lower()
        if tipo_consulta not in ['normal', 'emergencia']:
            raise ValidationError("tipo_consulta", tipo_consulta, "Tipo debe ser 'normal' o 'emergencia'")
    
    def _aplicar_reglas_negocio_consulta(self, paciente_id: int, especialidad_id: int, 
                                       fecha_consulta: datetime = None) -> List[str]:
        """Aplica reglas de negocio y retorna advertencias"""
        advertencias = []
        
        if fecha_consulta is None:
            fecha_consulta = datetime.now()
        
        # Verificar consultas del día del paciente
        consultas_hoy = self.consulta_repo.get_consultations_by_date(fecha_consulta)
        consultas_paciente_hoy = [c for c in consultas_hoy if c['Id_Paciente'] == paciente_id]
        
        if len(consultas_paciente_hoy) >= self.MAX_CONSULTAS_POR_DIA_PACIENTE:
            advertencias.append(
                f"Paciente ya tiene {len(consultas_paciente_hoy)} consultas hoy"
            )
        
        # Verificar tiempo entre consultas
        consultas_paciente = self.consulta_repo.get_consultations_by_patient(paciente_id, limit=5)
        if consultas_paciente:
            ultima_consulta = consultas_paciente[0]
            tiempo_desde_ultima = fecha_consulta - ultima_consulta['Fecha']
            
            if tiempo_desde_ultima.total_seconds() < (self.HORAS_MINIMAS_ENTRE_CONSULTAS * 3600):
                advertencias.append(
                    f"Menos de {self.HORAS_MINIMAS_ENTRE_CONSULTAS} horas desde la última consulta"
                )
        
        # Verificar especialidad repetida reciente
        fecha_limite = fecha_consulta - timedelta(days=7)
        consultas_especialidad_recientes = [
            c for c in consultas_paciente 
            if c['Id_Especialidad'] == especialidad_id and c['Fecha'] >= fecha_limite
        ]
        
        if consultas_especialidad_recientes:
            advertencias.append(
                "Paciente ya tuvo consulta en esta especialidad en los últimos 7 días"
            )
        
        return advertencias
    
    def _validar_especialidad(self, especialidad_id: int) -> Dict[str, Any]:
        """Valida que la especialidad existe y está activa"""
        # Esto requeriría un repository de especialidades
        # Por ahora simulamos la validación
        if not self.consulta_repo._specialty_exists(especialidad_id):
            raise ValidationError("especialidad_id", especialidad_id, "Especialidad no encontrada")
        
        # Obtener información completa de la especialidad
        # En un caso real, esto vendría del EspecialidadRepository
        return {
            'id': especialidad_id,
            'Nombre': f'Especialidad {especialidad_id}',
            'Precio_Normal': 150.0,
            'Precio_Emergencia': 250.0
        }
    
    def _calcular_precio_consulta(self, especialidad: Dict[str, Any], 
                                tipo_consulta: str) -> float:
        """Calcula precio según tipo de consulta y especialidad"""
        if tipo_consulta.lower() == 'emergencia':
            precio = safe_float(especialidad.get('Precio_Emergencia', 200.0))
        else:
            precio = safe_float(especialidad.get('Precio_Normal', 150.0))
        
        # Validar rango de precios
        if not validar_rango_numerico(precio, self.PRECIO_MINIMO_CONSULTA, self.PRECIO_MAXIMO_CONSULTA):
            raise ValidationError("precio", precio, f"Precio fuera del rango permitido ({self.PRECIO_MINIMO_CONSULTA}-{self.PRECIO_MAXIMO_CONSULTA})")
        
        return precio
    
    def _validar_modificacion_permitida(self, consulta: Dict[str, Any]):
        """Valida si una consulta puede ser modificada"""
        fecha_consulta = consulta['Fecha']
        
        # No permitir modificar consultas muy antiguas (ej: más de 30 días)
        dias_antiguedad = (datetime.now() - fecha_consulta).days
        if dias_antiguedad > 30:
            raise ValidationError(
                "fecha_consulta", 
                formatear_fecha(fecha_consulta), 
                f"No se puede modificar consulta de hace {dias_antiguedad} días"
            )
    
    # ===============================
    # GESTIÓN DE PACIENTES
    # ===============================
    
    def _gestionar_paciente(self, paciente_info: Dict[str, Any] = None, 
                          paciente_id: int = None) -> int:
        """Obtiene ID de paciente existente o crea uno nuevo"""
        if paciente_id:
            # Verificar que existe
            if not self.consulta_repo._patient_exists(paciente_id):
                raise ValidationError("paciente_id", paciente_id, "Paciente no encontrado")
            return paciente_id
        
        elif paciente_info:
            # Crear nuevo paciente
            return self._crear_paciente(paciente_info)
        
        else:
            raise ValidationError("paciente", None, "Debe especificar paciente_id o paciente_info")
    
    def _crear_paciente(self, paciente_info: Dict[str, Any]) -> int:
        """Crea nuevo paciente con validaciones"""
        # Validar datos requeridos
        validate_required(paciente_info.get('nombre'), "nombre")
        validate_required(paciente_info.get('apellido_paterno'), "apellido_paterno")
        
        edad = safe_int(paciente_info.get('edad', 0))
        if not validar_rango_numerico(edad, 0, 120):
            raise ValidationError("edad", edad, "Edad debe estar entre 0 y 120 años")
        
        # Limpiar y formatear datos
        datos_paciente = {
            'Nombre': limpiar_texto(paciente_info['nombre']),
            'Apellido_Paterno': limpiar_texto(paciente_info['apellido_paterno']),
            'Apellido_Materno': limpiar_texto(paciente_info.get('apellido_materno', '')),
            'Edad': edad
        }
        
        # Crear usando el repository de pacientes
        # Por ahora simulamos la creación
        print(f"🆕 Creando paciente: {formatear_nombre_completo(datos_paciente['Nombre'], datos_paciente['Apellido_Paterno'], datos_paciente['Apellido_Materno'])}")
        
        # En implementación real:
        # return self.paciente_repo.insert(datos_paciente)
        
        # Simulación temporal
        return 999  # ID simulado
    
    # ===============================
    # ENRIQUECIMIENTO DE DATOS
    # ===============================
    
    def _enriquecer_consultas(self, consultas: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Enriquece lista de consultas con información adicional"""
        consultas_enriquecidas = []
        
        for consulta in consultas:
            consulta_enriquecida = self._enriquecer_consulta_individual(consulta)
            consultas_enriquecidas.append(consulta_enriquecida)
        
        return consultas_enriquecidas
    
    def _enriquecer_consulta_individual(self, consulta: Dict[str, Any]) -> Dict[str, Any]:
        """Enriquece consulta individual con información calculada"""
        consulta_enriquecida = consulta.copy()
        
        # Formatear fechas para interfaz
        if 'Fecha' in consulta:
            consulta_enriquecida['fecha_formateada'] = formatear_fecha(consulta['Fecha'])
            consulta_enriquecida['fecha_relativa'] = self._calcular_fecha_relativa(consulta['Fecha'])
        
        # Formatear precios
        for campo_precio in ['Precio_Normal', 'Precio_Emergencia']:
            if campo_precio in consulta:
                consulta_enriquecida[f'{campo_precio.lower()}_formateado'] = formatear_precio(
                    consulta[campo_precio]
                )
        
        # Truncar detalles para vista resumida
        if 'Detalles' in consulta:
            consulta_enriquecida['detalles_resumidos'] = truncar_texto(consulta['Detalles'], 100)
        
        # Añadir estado de seguimiento
        consulta_enriquecida['requiere_seguimiento'] = self._evaluar_seguimiento_necesario(consulta)
        
        # Añadir indicadores de prioridad
        consulta_enriquecida['prioridad'] = self._calcular_prioridad_consulta(consulta)
        
        return consulta_enriquecida
    
    def _calcular_fecha_relativa(self, fecha: datetime) -> str:
        """Calcula descripción relativa de fecha (ej: 'hace 2 días')"""
        if not fecha:
            return "Sin fecha"
        
        diferencia = datetime.now() - fecha
        dias = diferencia.days
        
        if dias == 0:
            horas = diferencia.seconds // 3600
            if horas == 0:
                return "Hace menos de una hora"
            elif horas == 1:
                return "Hace 1 hora"
            else:
                return f"Hace {horas} horas"
        elif dias == 1:
            return "Ayer"
        elif dias < 7:
            return f"Hace {dias} días"
        elif dias < 30:
            semanas = dias // 7
            return f"Hace {semanas} semana{'s' if semanas > 1 else ''}"
        else:
            meses = dias // 30
            return f"Hace {meses} mes{'es' if meses > 1 else ''}"
    
    def _evaluar_seguimiento_necesario(self, consulta: Dict[str, Any]) -> bool:
        """Evalúa si la consulta necesita seguimiento"""
        # Lógica simplificada - en caso real sería más compleja
        fecha_consulta = consulta.get('Fecha')
        if not fecha_consulta:
            return False
        
        dias_transcurridos = (datetime.now() - fecha_consulta).days
        
        # Consultas de emergencia siempre requieren seguimiento
        if 'emergencia' in str(consulta.get('tipo', '')).lower():
            return True
        
        # Consultas recientes de ciertas especialidades
        especialidades_seguimiento = ['cardiología', 'neurología', 'oncología']
        especialidad = str(consulta.get('especialidad_nombre', '')).lower()
        
        for esp in especialidades_seguimiento:
            if esp in especialidad and dias_transcurridos <= self.DIAS_PARA_SEGUIMIENTO:
                return True
        
        return False
    
    def _calcular_prioridad_consulta(self, consulta: Dict[str, Any]) -> str:
        """Calcula prioridad de consulta para ordenamiento"""
        # Emergencias tienen prioridad alta
        if 'emergencia' in str(consulta.get('tipo', '')).lower():
            return 'alta'
        
        # Consultas que requieren seguimiento tienen prioridad media
        if self._evaluar_seguimiento_necesario(consulta):
            return 'media'
        
        return 'normal'
    
    # ===============================
    # FILTROS Y BÚSQUEDAS
    # ===============================
    
    def _aplicar_filtros_avanzados(self, consultas: List[Dict[str, Any]], 
                                 criterios: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Aplica filtros adicionales a las consultas"""
        consultas_filtradas = consultas.copy()
        
        # Filtrar por doctor
        if criterios.get('doctor_id'):
            doctor_id = safe_int(criterios['doctor_id'])
            consultas_filtradas = [
                c for c in consultas_filtradas 
                if c.get('Id_Doctor') == doctor_id
            ]
        
        # Filtrar por paciente
        if criterios.get('paciente_id'):
            paciente_id = safe_int(criterios['paciente_id'])
            consultas_filtradas = [
                c for c in consultas_filtradas 
                if c.get('Id_Paciente') == paciente_id
            ]
        
        # Filtrar por rango de precios
        precio_min = safe_float(criterios.get('precio_min'))
        precio_max = safe_float(criterios.get('precio_max'))
        
        if precio_min > 0 or precio_max > 0:
            consultas_filtradas = [
                c for c in consultas_filtradas 
                if self._consulta_en_rango_precio(c, precio_min, precio_max)
            ]
        
        return consultas_filtradas
    
    def _consulta_en_rango_precio(self, consulta: Dict[str, Any], 
                                precio_min: float, precio_max: float) -> bool:
        """Verifica si consulta está en rango de precio"""
        precio = safe_float(consulta.get('Precio_Normal', 0))
        
        if precio_min > 0 and precio < precio_min:
            return False
        
        if precio_max > 0 and precio > precio_max:
            return False
        
        return True
    
    def _parsear_fecha_criterio(self, fecha_str: str) -> Optional[datetime]:
        """Parsea fecha de criterio de búsqueda"""
        if not fecha_str:
            return None
        
        # Usar utilidad de fechas
        from ..core.utils import parsear_fecha
        return parsear_fecha(fecha_str)
    
    # ===============================
    # ESTADÍSTICAS Y MÉTRICAS
    # ===============================
    
    def _calcular_estadisticas_busqueda(self, consultas: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calcula estadísticas de los resultados de búsqueda"""
        if not consultas:
            return {}
        
        total = len(consultas)
        
        # Conteos por tipo
        normales = len([c for c in consultas if 'normal' in str(c.get('tipo', '')).lower()])
        emergencias = total - normales
        
        # Precios
        precios = [safe_float(c.get('Precio_Normal', 0)) for c in consultas]
        precio_promedio = sum(precios) / len(precios) if precios else 0
        precio_total = sum(precios)
        
        # Fechas
        fechas = [c.get('Fecha') for c in consultas if c.get('Fecha')]
        fecha_mas_antigua = min(fechas) if fechas else None
        fecha_mas_reciente = max(fechas) if fechas else None
        
        return {
            'resumen': {
                'total_consultas': total,
                'consultas_normales': normales,
                'consultas_emergencia': emergencias,
                'precio_promedio': precio_promedio,
                'precio_total': precio_total
            },
            'rangos': {
                'fecha_mas_antigua': formatear_fecha(fecha_mas_antigua) if fecha_mas_antigua else None,
                'fecha_mas_reciente': formatear_fecha(fecha_mas_reciente) if fecha_mas_reciente else None,
                'precio_minimo': min(precios) if precios else 0,
                'precio_maximo': max(precios) if precios else 0
            },
            'distribuciones': {
                'por_tipo': {
                    'normal': normales,
                    'emergencia': emergencias
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
    
    # ===============================
    # UTILIDADES DE REPORTE
    # ===============================
    
    def _formatear_tendencias_dashboard(self, tendencias: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Formatea tendencias para dashboard"""
        return [
            {
                'mes': t.get('mes_nombre', t.get('mes', '')),
                'total_consultas': t.get('total_consultas', 0),
                'pacientes_unicos': t.get('pacientes_unicos', 0),
                'precio_promedio': formatear_precio(t.get('precio_promedio', 0))
            }
            for t in tendencias
        ]
    
    def _formatear_pacientes_frecuentes(self, pacientes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Formatea pacientes frecuentes para dashboard"""
        return [
            {
                'nombre_completo': p.get('paciente_completo', 'N/A'),
                'total_consultas': p.get('total_consultas', 0),
                'ultima_consulta': formatear_fecha(p.get('ultima_consulta')),
                'especialidades_diferentes': p.get('especialidades_diferentes', 0)
            }
            for p in pacientes
        ]
    
    def _formatear_consultas_recientes(self, consultas: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Formatea consultas recientes para dashboard"""
        return [
            {
                'id': c.get('id'),
                'paciente': c.get('paciente_completo', 'N/A'),
                'especialidad': c.get('especialidad_nombre', 'N/A'),
                'fecha': formatear_fecha(c.get('Fecha')),
                'fecha_relativa': self._calcular_fecha_relativa(c.get('Fecha')),
                'detalles_resumidos': truncar_texto(c.get('Detalles', ''), 50)
            }
            for c in consultas
        ]
    
    def _generar_alertas_dashboard(self) -> List[Dict[str, Any]]:
        """Genera alertas para el dashboard"""
        alertas = []
        
        # Verificar consultas pendientes de seguimiento
        # (esto requeriría lógica más compleja en un caso real)
        
        # Ejemplo de alertas
        alertas.append({
            'tipo': 'info',
            'mensaje': 'Sistema funcionando correctamente',
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        })
        
        return alertas
    
    # ===============================
    # UTILIDADES AUXILIARES
    # ===============================
    
    def _resumir_criterios(self, criterios: Dict[str, Any]) -> Dict[str, Any]:
        """Resume criterios aplicados en búsqueda"""
        resumen = {}
        
        if criterios.get('texto'):
            resumen['busqueda_texto'] = criterios['texto']
        
        if criterios.get('fecha_inicio'):
            resumen['fecha_desde'] = criterios['fecha_inicio']
        
        if criterios.get('fecha_fin'):
            resumen['fecha_hasta'] = criterios['fecha_fin']
        
        if criterios.get('doctor_id'):
            resumen['doctor_filtrado'] = True
        
        if criterios.get('especialidad_id'):
            resumen['especialidad_filtrada'] = True
        
        return resumen
    
    def _registrar_seguimiento_consulta(self, consulta_id: int, paciente_id: int):
        """Registra información para seguimiento de consulta"""
        # En implementación real, esto podría:
        # - Crear recordatorios automáticos
        # - Programar notificaciones
        # - Actualizar historial médico
        print(f"📋 Seguimiento registrado: Consulta {consulta_id}, Paciente {paciente_id}")
    
    def _registrar_auditoria_modificacion(self, consulta_id: int, usuario_id: int, 
                                        cambios: Dict[str, Any]):
        """Registra auditoría de modificaciones"""
        # En implementación real, esto iría a una tabla de auditoría
        print(f"📝 Auditoría: Usuario {usuario_id} modificó consulta {consulta_id}")
        print(f"🔄 Cambios: {cambios}")
    
    def _obtener_info_doctor(self, doctor_id: int) -> Dict[str, Any]:
        """Obtiene información completa del doctor"""
        # En implementación real, usar DoctorRepository
        return {
            'id': doctor_id,
            'nombre_completo': f'Dr. Doctor {doctor_id}',
            'especialidad': 'Medicina General',
            'matricula': f'MAT{doctor_id:03d}'
        }
    
    def _calcular_tendencias_doctor(self, consultas: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calcula tendencias de actividad del doctor"""
        # Implementación simplificada
        return {
            'tendencia_semanal': 'estable',
            'consultas_promedio_dia': len(consultas) / 30 if consultas else 0
        }
    
    def _obtener_especialidades_top(self, consultas: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Obtiene especialidades más solicitadas"""
        # Implementación simplificada
        return [
            {'nombre': 'Medicina General', 'cantidad': len(consultas)}
        ]
    
    def _analizar_distribucion_horaria(self, consultas: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analiza distribución horaria de consultas"""
        # Implementación simplificada
        return {
            'hora_pico': '10:00-11:00',
            'consultas_manana': len([c for c in consultas if c.get('Fecha') and c['Fecha'].hour < 12]),
            'consultas_tarde': len([c for c in consultas if c.get('Fecha') and c['Fecha'].hour >= 12])
        }
    
    def _preparar_consultas_reporte(self, consultas: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Prepara consultas para inclusión en reporte"""
        return [
            {
                'fecha': formatear_fecha(c.get('Fecha')),
                'paciente': c.get('paciente_completo', 'N/A'),
                'especialidad': c.get('especialidad_nombre', 'N/A'),
                'detalles': truncar_texto(c.get('Detalles', ''), 100),
                'precio': formatear_precio(c.get('Precio_Normal', 0))
            }
            for c in consultas
        ]