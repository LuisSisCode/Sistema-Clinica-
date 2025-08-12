# backend/services/doctor_service.py

import logging
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta

from ..repositories.doctor_repository import DoctorRepository
from ..repositories.consulta_repository import ConsultaRepository
from ..repositories.paciente_repository import PacienteRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, DatabaseTransactionError,
    validate_required, validate_positive_number
)
from ..core.utils import (
    formatear_nombre_completo, crear_respuesta_qml, preparar_para_qml,
    formatear_lista_para_combobox, safe_int, safe_float, safe_str,
    validar_rango_numerico, limpiar_texto, fecha_actual_str
)

logger = logging.getLogger(__name__)

class DoctorService:
    """
    Servicio de negocio para gestión de doctores y especialidades
    Capa entre QML Models y Repository con lógica de negocio compleja
    """
    
    def __init__(self):
        self.doctor_repository = DoctorRepository()
        self.consulta_repository = ConsultaRepository()
        self.paciente_repository = PacienteRepository()
        
        print("👨‍⚕️ DoctorService inicializado")
    
    # ===============================
    # GESTIÓN DE DOCTORES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_doctor_completo(self, datos_doctor: Dict[str, Any]) -> Dict[str, Any]:
        """
        Crea doctor con validaciones de negocio complejas
        
        Args:
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
        try:
            # Validaciones de negocio específicas
            self._validar_datos_doctor_completos(datos_doctor)
            
            # Crear doctor
            doctor_id = self.doctor_repository.create_doctor(
                nombre=datos_doctor['nombre'],
                apellido_paterno=datos_doctor['apellido_paterno'],
                apellido_materno=datos_doctor['apellido_materno'],
                especialidad=datos_doctor['especialidad'],
                matricula=datos_doctor['matricula'],
                edad=datos_doctor['edad']
            )
            
            # Crear servicios iniciales si se proporcionan
            servicios_creados = []
            if 'servicios_iniciales' in datos_doctor and datos_doctor['servicios_iniciales']:
                for servicio_data in datos_doctor['servicios_iniciales']:
                    servicio_id = self.doctor_repository.create_specialty_service(
                        doctor_id=doctor_id,
                        nombre=servicio_data['nombre'],
                        detalles=servicio_data.get('detalles', ''),
                        precio_normal=servicio_data['precio_normal'],
                        precio_emergencia=servicio_data['precio_emergencia']
                    )
                    servicios_creados.append(servicio_id)
            
            # Obtener doctor completo creado
            doctor_completo = self.doctor_repository.get_doctor_with_services(doctor_id)
            
            return crear_respuesta_qml(
                exito=True,
                mensaje=f"Doctor creado exitosamente: Dr. {datos_doctor['nombre']} {datos_doctor['apellido_paterno']}",
                datos={
                    'doctor': preparar_para_qml(doctor_completo),
                    'servicios_creados': len(servicios_creados)
                }
            )
            
        except ValidationError as e:
            return crear_respuesta_qml(
                exito=False,
                mensaje=f"Error de validación: {e.message}",
                codigo_error=e.error_code
            )
        except Exception as e:
            logger.error(f"Error creando doctor completo: {e}")
            return crear_respuesta_qml(
                exito=False,
                mensaje="Error interno creando doctor",
                codigo_error="DOCTOR_CREATE_ERROR"
            )
    
    @ExceptionHandler.handle_exception
    def obtener_doctor_dashboard(self, doctor_id: int) -> Dict[str, Any]:
        """
        Obtiene información completa del doctor para dashboard
        Incluye estadísticas, servicios, consultas recientes, etc.
        """
        doctor = self.doctor_repository.get_doctor_with_consultation_history(doctor_id)
        
        if not doctor:
            return crear_respuesta_qml(
                exito=False,
                mensaje="Doctor no encontrado",
                codigo_error="DOCTOR_NOT_FOUND"
            )
        
        # Calcular estadísticas adicionales
        estadisticas = self._calcular_estadisticas_doctor(doctor)
        
        # Preparar datos para QML
        datos_dashboard = {
            'doctor_info': {
                'id': doctor['id'],
                'nombre_completo': formatear_nombre_completo(
                    doctor['Nombre'], 
                    doctor['Apellido_Paterno'], 
                    doctor['Apellido_Materno']
                ),
                'especialidad': doctor['Especialidad'],
                'matricula': doctor['Matricula'],
                'edad': doctor['Edad']
            },
            'servicios': doctor.get('servicios', []),
            'estadisticas': estadisticas,
            'consultas_recientes': doctor.get('historial_consultas', [])[:10],  # Últimas 10
            'resumen': {
                'total_servicios': doctor.get('total_servicios', 0),
                'total_consultas': doctor.get('total_consultas_realizadas', 0),
                'precio_promedio': doctor.get('precio_promedio_normal', 0),
                'ultima_consulta': doctor.get('ultima_consulta', 'Sin consultas')
            }
        }
        
        return crear_respuesta_qml(
            exito=True,
            mensaje="Dashboard de doctor obtenido",
            datos=preparar_para_qml(datos_dashboard)
        )
    
    @ExceptionHandler.handle_exception
    def buscar_doctores_avanzado(self, criterios: Dict[str, Any]) -> Dict[str, Any]:
        """
        Búsqueda avanzada de doctores con múltiples criterios
        
        Args:
            criterios: {
                'texto': str (opcional),
                'especialidad': str (opcional),
                'edad_min': int (opcional),
                'edad_max': int (opcional),
                'con_servicios': bool (opcional),
                'activos_ultimo_mes': bool (opcional),
                'limit': int (opcional, default 50)
            }
        """
        resultados = []
        limit = safe_int(criterios.get('limit', 50))
        
        # Búsqueda por texto
        if criterios.get('texto'):
            resultados = self.doctor_repository.search_doctors(
                criterios['texto'], limit
            )
        else:
            resultados = self.doctor_repository.get_all_with_specialties()
        
        # Filtrar por especialidad
        if criterios.get('especialidad'):
            especialidad = criterios['especialidad'].lower()
            resultados = [
                d for d in resultados 
                if especialidad in d['Especialidad'].lower()
            ]
        
        # Filtrar por rango de edad
        if criterios.get('edad_min') or criterios.get('edad_max'):
            edad_min = safe_int(criterios.get('edad_min', 0))
            edad_max = safe_int(criterios.get('edad_max', 999))
            resultados = [
                d for d in resultados 
                if edad_min <= d['Edad'] <= edad_max
            ]
        
        # Filtrar solo doctores con servicios
        if criterios.get('con_servicios', False):
            resultados = [
                d for d in resultados 
                if d.get('total_servicios', 0) > 0
            ]
        
        # Filtrar doctores activos último mes
        if criterios.get('activos_ultimo_mes', False):
            resultados = self._filtrar_doctores_activos_recientes(resultados)
        
        # Preparar para QML
        doctores_formateados = []
        for doctor in resultados[:limit]:
            doctores_formateados.append({
                'id': doctor['id'],
                'nombre_completo': formatear_nombre_completo(
                    doctor['Nombre'], 
                    doctor['Apellido_Paterno'], 
                    doctor['Apellido_Materno']
                ),
                'especialidad': doctor['Especialidad'],
                'matricula': doctor['Matricula'],
                'edad': doctor['Edad'],
                'total_servicios': doctor.get('total_servicios', 0),
                'precio_promedio': doctor.get('precio_promedio_normal', 0)
            })
        
        return crear_respuesta_qml(
            exito=True,
            mensaje=f"Se encontraron {len(doctores_formateados)} doctores",
            datos={
                'doctores': doctores_formateados,
                'total_encontrados': len(doctores_formateados),
                'criterios_aplicados': criterios
            }
        )
    
    # ===============================
    # GESTIÓN DE ESPECIALIDADES/SERVICIOS
    # ===============================
    
    @ExceptionHandler.handle_exception
    def crear_servicio_con_validacion(self, doctor_id: int, datos_servicio: Dict[str, Any]) -> Dict[str, Any]:
        """
        Crea servicio de especialidad con validaciones de negocio
        """
        try:
            # Validaciones específicas de negocio
            self._validar_datos_servicio(datos_servicio)
            self._validar_precios_competitivos(datos_servicio)
            
            # Verificar límite de servicios por doctor
            doctor = self.doctor_repository.get_doctor_with_services(doctor_id)
            if doctor and len(doctor.get('servicios', [])) >= 10:
                return crear_respuesta_qml(
                    exito=False,
                    mensaje="El doctor ya tiene el máximo de servicios permitidos (10)",
                    codigo_error="MAX_SERVICES_REACHED"
                )
            
            # Crear servicio
            servicio_id = self.doctor_repository.create_specialty_service(
                doctor_id=doctor_id,
                nombre=datos_servicio['nombre'],
                detalles=datos_servicio.get('detalles', ''),
                precio_normal=datos_servicio['precio_normal'],
                precio_emergencia=datos_servicio['precio_emergencia']
            )
            
            return crear_respuesta_qml(
                exito=True,
                mensaje="Servicio creado exitosamente",
                datos={'servicio_id': servicio_id}
            )
            
        except ValidationError as e:
            return crear_respuesta_qml(
                exito=False,
                mensaje=f"Error de validación: {e.message}",
                codigo_error=e.error_code
            )
    
    @ExceptionHandler.handle_exception
    def obtener_servicios_para_consulta(self, doctor_id: int) -> Dict[str, Any]:
        """
        Obtiene servicios de un doctor formateados para selección en consultas
        """
        doctor = self.doctor_repository.get_doctor_with_services(doctor_id)
        
        if not doctor:
            return crear_respuesta_qml(
                exito=False,
                mensaje="Doctor no encontrado"
            )
        
        servicios = doctor.get('servicios', [])
        servicios_formateados = formatear_lista_para_combobox(
            servicios,
            key_id='id',
            key_text='Nombre'
        )
        
        # Agregar información adicional para cada servicio
        for servicio in servicios_formateados:
            datos_servicio = servicio['data']
            servicio['precio_normal'] = datos_servicio['Precio_Normal']
            servicio['precio_emergencia'] = datos_servicio['Precio_Emergencia']
            servicio['detalles'] = datos_servicio.get('Detalles', '')
        
        return crear_respuesta_qml(
            exito=True,
            mensaje="Servicios obtenidos",
            datos={
                'servicios': servicios_formateados,
                'doctor_nombre': formatear_nombre_completo(
                    doctor['Nombre'], 
                    doctor['Apellido_Paterno'], 
                    doctor['Apellido_Materno']
                )
            }
        )
    
    # ===============================
    # ESTADÍSTICAS Y REPORTES
    # ===============================
    
    @ExceptionHandler.handle_exception
    def obtener_estadisticas_generales(self) -> Dict[str, Any]:
        """Obtiene estadísticas generales de doctores para dashboard"""
        stats = self.doctor_repository.get_doctor_statistics()
        doctores_activos = self.doctor_repository.get_most_active_doctors(10)
        
        # Calcular métricas adicionales
        metricas_adicionales = self._calcular_metricas_sistema()
        
        datos_estadisticas = {
            'resumen_general': {
                'total_doctores': stats['general']['total_doctores'],
                'edad_promedio': round(stats['general']['edad_promedio'], 1),
                'especialidades_diferentes': stats['general']['especialidades_diferentes']
            },
            'especialidades': stats['por_especialidades'],
            'doctores_activos': [
                {
                    'id': d['id'],
                    'nombre_completo': formatear_nombre_completo(
                        d['Nombre'], d['Apellido_Paterno'], d['Apellido_Materno']
                    ),
                    'especialidad': d['Especialidad'],
                    'total_consultas': d['total_consultas'],
                    'pacientes_unicos': d['pacientes_unicos'],
                    'ultima_consulta': d['ultima_consulta']
                }
                for d in doctores_activos
            ],
            'metricas_sistema': metricas_adicionales
        }
        
        return crear_respuesta_qml(
            exito=True,
            mensaje="Estadísticas obtenidas",
            datos=preparar_para_qml(datos_estadisticas)
        )
    
    @ExceptionHandler.handle_exception
    def generar_reporte_doctor(self, doctor_id: int, fecha_inicio: str, fecha_fin: str) -> Dict[str, Any]:
        """
        Genera reporte detallado de un doctor en período específico
        """
        # Obtener información del doctor
        doctor = self.doctor_repository.get_doctor_with_consultation_history(doctor_id)
        
        if not doctor:
            return crear_respuesta_qml(
                exito=False,
                mensaje="Doctor no encontrado"
            )
        
        # Filtrar consultas por rango de fechas
        consultas_periodo = self._filtrar_consultas_por_periodo(
            doctor.get('historial_consultas', []),
            fecha_inicio,
            fecha_fin
        )
        
        # Calcular estadísticas del período
        estadisticas_periodo = self._calcular_estadisticas_periodo(consultas_periodo)
        
        reporte = {
            'doctor_info': {
                'nombre_completo': formatear_nombre_completo(
                    doctor['Nombre'], doctor['Apellido_Paterno'], doctor['Apellido_Materno']
                ),
                'especialidad': doctor['Especialidad'],
                'matricula': doctor['Matricula']
            },
            'periodo': {
                'fecha_inicio': fecha_inicio,
                'fecha_fin': fecha_fin
            },
            'estadisticas': estadisticas_periodo,
            'consultas_detalle': consultas_periodo,
            'servicios_utilizados': self._analizar_servicios_utilizados(consultas_periodo)
        }
        
        return crear_respuesta_qml(
            exito=True,
            mensaje="Reporte generado",
            datos=preparar_para_qml(reporte)
        )
    
    # ===============================
    # VALIDACIONES DE NEGOCIO
    # ===============================
    
    def _validar_datos_doctor_completos(self, datos: Dict[str, Any]):
        """Validaciones específicas de negocio para crear doctor"""
        # Validaciones básicas
        validate_required(datos.get('nombre'), 'nombre')
        validate_required(datos.get('apellido_paterno'), 'apellido_paterno')
        validate_required(datos.get('apellido_materno'), 'apellido_materno')
        validate_required(datos.get('especialidad'), 'especialidad')
        validate_required(datos.get('matricula'), 'matricula')
        
        # Validar edad en rango médico
        edad = safe_int(datos.get('edad', 0))
        if not validar_rango_numerico(edad, 25, 75):
            raise ValidationError("edad", edad, "Edad debe estar entre 25 y 75 años para médicos")
        
        # Validar formato de matrícula
        matricula = safe_str(datos.get('matricula', '')).strip().upper()
        if len(matricula) < 3 or len(matricula) > 20:
            raise ValidationError("matricula", matricula, "Matrícula debe tener entre 3 y 20 caracteres")
        
        # Validar especialidad conocida
        especialidades_validas = self.doctor_repository.get_available_specialties()
        especialidad = datos.get('especialidad', '').strip()
        
        # Si no está en la lista, verificar que no sea una variante
        if especialidad not in especialidades_validas:
            # Permitir nuevas especialidades pero advertir
            logger.warning(f"Nueva especialidad detectada: {especialidad}")
    
    def _validar_datos_servicio(self, datos: Dict[str, Any]):
        """Validaciones para servicios de especialidad"""
        validate_required(datos.get('nombre'), 'nombre')
        
        nombre = limpiar_texto(datos.get('nombre', ''))
        if len(nombre) < 5:
            raise ValidationError("nombre", nombre, "Nombre del servicio debe tener al menos 5 caracteres")
        
        precio_normal = safe_float(datos.get('precio_normal', 0))
        precio_emergencia = safe_float(datos.get('precio_emergencia', 0))
        
        validate_positive_number(precio_normal, 'precio_normal')
        validate_positive_number(precio_emergencia, 'precio_emergencia')
        
        if precio_emergencia < precio_normal:
            raise ValidationError("precio_emergencia", precio_emergencia, 
                                "Precio de emergencia debe ser mayor al precio normal")
        
        # Validar que los precios sean razonables
        if precio_normal > 1000:
            raise ValidationError("precio_normal", precio_normal, 
                                "Precio normal parece excesivo (>Bs. 1000)")
    
    def _validar_precios_competitivos(self, datos: Dict[str, Any]):
        """Valida que los precios sean competitivos en el mercado"""
        precio_normal = safe_float(datos.get('precio_normal', 0))
        
        # Obtener estadísticas de precios de servicios similares
        todos_servicios = self.doctor_repository.get_all_specialty_services()
        precios_similares = [
            s['Precio_Normal'] for s in todos_servicios 
            if datos.get('nombre', '').lower() in s['Nombre'].lower()
        ]
        
        if precios_similares:
            precio_promedio = sum(precios_similares) / len(precios_similares)
            
            # Advertir si el precio está muy por encima del promedio
            if precio_normal > precio_promedio * 1.5:
                logger.warning(f"Precio del servicio '{datos['nombre']}' está 50% por encima del promedio del mercado")
    
    # ===============================
    # MÉTODOS DE ANÁLISIS
    # ===============================
    
    def _calcular_estadisticas_doctor(self, doctor: Dict[str, Any]) -> Dict[str, Any]:
        """Calcula estadísticas detalladas de un doctor"""
        consultas = doctor.get('historial_consultas', [])
        servicios = doctor.get('servicios', [])
        
        # Estadísticas de consultas
        total_consultas = len(consultas)
        pacientes_unicos = len(set(c.get('paciente_completo', '') for c in consultas))
        
        # Estadísticas de servicios
        if servicios:
            precios_normales = [s['Precio_Normal'] for s in servicios]
            servicio_mas_caro = max(servicios, key=lambda x: x['Precio_Normal'])
            servicio_mas_barato = min(servicios, key=lambda x: x['Precio_Normal'])
        else:
            precios_normales = [0]
            servicio_mas_caro = servicio_mas_barato = None
        
        # Tendencia temporal
        tendencia = self._analizar_tendencia_consultas(consultas)
        
        return {
            'consultas': {
                'total': total_consultas,
                'pacientes_unicos': pacientes_unicos,
                'promedio_mensual': round(total_consultas / 12, 1),  # Aproximado
                'tendencia': tendencia
            },
            'servicios': {
                'total': len(servicios),
                'precio_promedio': round(sum(precios_normales) / len(precios_normales), 2),
                'precio_maximo': max(precios_normales),
                'precio_minimo': min(precios_normales),
                'servicio_mas_caro': servicio_mas_caro['Nombre'] if servicio_mas_caro else None,
                'servicio_mas_barato': servicio_mas_barato['Nombre'] if servicio_mas_barato else None
            }
        }
    
    def _filtrar_doctores_activos_recientes(self, doctores: List[Dict]) -> List[Dict]:
        """Filtra doctores que han tenido consultas en el último mes"""
        fecha_limite = datetime.now() - timedelta(days=30)
        doctores_activos = []
        
        for doctor in doctores:
            # Obtener historial de consultas del doctor
            doctor_completo = self.doctor_repository.get_doctor_with_consultation_history(doctor['id'])
            if doctor_completo and doctor_completo.get('historial_consultas'):
                ultima_consulta = doctor_completo['historial_consultas'][0]['Fecha']
                if isinstance(ultima_consulta, str):
                    from ..core.utils import parsear_fecha
                    ultima_consulta = parsear_fecha(ultima_consulta)
                
                if ultima_consulta and ultima_consulta >= fecha_limite:
                    doctores_activos.append(doctor)
        
        return doctores_activos
    
    def _calcular_metricas_sistema(self) -> Dict[str, Any]:
        """Calcula métricas adicionales del sistema de doctores"""
        # Utilización de servicios
        servicios = self.doctor_repository.get_all_specialty_services()
        
        # Distribución por especialidad
        especialidades = {}
        for servicio in servicios:
            esp = servicio.get('doctor_especialidad', 'Sin especialidad')
            especialidades[esp] = especialidades.get(esp, 0) + 1
        
        return {
            'total_servicios_disponibles': len(servicios),
            'especialidades_con_servicios': len(especialidades),
            'servicios_por_especialidad': especialidades,
            'precio_promedio_general': round(
                sum(s['Precio_Normal'] for s in servicios) / len(servicios), 2
            ) if servicios else 0
        }
    
    def _filtrar_consultas_por_periodo(self, consultas: List[Dict], fecha_inicio: str, fecha_fin: str) -> List[Dict]:
        """Filtra consultas por período de fechas"""
        from ..core.utils import parsear_fecha
        
        fecha_ini = parsear_fecha(fecha_inicio)
        fecha_fin_parsed = parsear_fecha(fecha_fin)
        
        if not fecha_ini or not fecha_fin_parsed:
            return consultas
        
        consultas_filtradas = []
        for consulta in consultas:
            fecha_consulta = parsear_fecha(consulta.get('Fecha', ''))
            if fecha_consulta and fecha_ini <= fecha_consulta <= fecha_fin_parsed:
                consultas_filtradas.append(consulta)
        
        return consultas_filtradas
    
    def _calcular_estadisticas_periodo(self, consultas: List[Dict]) -> Dict[str, Any]:
        """Calcula estadísticas para un período específico"""
        if not consultas:
            return {
                'total_consultas': 0,
                'pacientes_atendidos': 0,
                'servicios_utilizados': 0,
                'ingresos_estimados': 0
            }
        
        pacientes = set(c.get('paciente_completo', '') for c in consultas)
        servicios = set(c.get('servicio_nombre', '') for c in consultas)
        
        # Calcular ingresos estimados
        ingresos = sum(
            safe_float(c.get('Precio_Normal', 0)) 
            for c in consultas
        )
        
        return {
            'total_consultas': len(consultas),
            'pacientes_atendidos': len(pacientes),
            'servicios_utilizados': len(servicios),
            'ingresos_estimados': round(ingresos, 2),
            'promedio_por_consulta': round(ingresos / len(consultas), 2) if consultas else 0
        }
    
    def _analizar_servicios_utilizados(self, consultas: List[Dict]) -> List[Dict]:
        """Analiza frecuencia de uso de servicios"""
        conteo_servicios = {}
        
        for consulta in consultas:
            servicio = consulta.get('servicio_nombre', 'Sin servicio')
            conteo_servicios[servicio] = conteo_servicios.get(servicio, 0) + 1
        
        servicios_ordenados = sorted(
            conteo_servicios.items(),
            key=lambda x: x[1],
            reverse=True
        )
        
        return [
            {'nombre': servicio, 'frecuencia': frecuencia}
            for servicio, frecuencia in servicios_ordenados
        ]
    
    def _analizar_tendencia_consultas(self, consultas: List[Dict]) -> str:
        """Analiza tendencia de consultas del doctor"""
        if len(consultas) < 2:
            return "Sin datos suficientes"
        
        # Dividir en dos períodos y comparar
        mitad = len(consultas) // 2
        primer_periodo = consultas[mitad:]  # Más antiguas
        segundo_periodo = consultas[:mitad]  # Más recientes
        
        if len(segundo_periodo) > len(primer_periodo):
            return "Creciente"
        elif len(segundo_periodo) < len(primer_periodo):
            return "Decreciente"
        else:
            return "Estable"
    
    # ===============================
    # MÉTODOS DE UTILIDAD PARA QML
    # ===============================
    
    @ExceptionHandler.handle_exception
    def obtener_lista_doctores_combobox(self) -> Dict[str, Any]:
        """Obtiene lista de doctores formateada para ComboBox en QML"""
        doctores = self.doctor_repository.get_all()
        
        doctores_formateados = formatear_lista_para_combobox(
            doctores,
            key_id='id',
            key_text='Nombre'  # Se formateará más abajo
        )
        
        # Formatear texto con nombre completo
        for doctor in doctores_formateados:
            datos = doctor['data']
            doctor['text'] = formatear_nombre_completo(
                datos['Nombre'],
                datos['Apellido_Paterno'],
                datos['Apellido_Materno']
            )
            doctor['especialidad'] = datos['Especialidad']
            doctor['matricula'] = datos['Matricula']
        
        return crear_respuesta_qml(
            exito=True,
            mensaje="Lista de doctores obtenida",
            datos={'doctores': doctores_formateados}
        )
    
    @ExceptionHandler.handle_exception
    def validar_disponibilidad_matricula(self, matricula: str, doctor_id: int = None) -> Dict[str, Any]:
        """Valida si una matrícula está disponible"""
        existe = self.doctor_repository.matricula_exists(matricula)
        
        # Si se está editando un doctor, verificar que no sea la misma matrícula
        if existe and doctor_id:
            doctor_actual = self.doctor_repository.get_by_id(doctor_id)
            if doctor_actual and doctor_actual['Matricula'].upper() == matricula.upper():
                existe = False
        
        return crear_respuesta_qml(
            exito=not existe,
            mensaje="Matrícula disponible" if not existe else "Matrícula ya existe",
            datos={'disponible': not existe}
        )

# Instancia global del servicio
doctor_service = DoctorService()