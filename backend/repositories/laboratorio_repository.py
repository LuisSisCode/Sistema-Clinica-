from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ..core.cache_system import cached_query
from ..core.utils import (
    validate_required_string, validate_positive_number, safe_float
)

class LaboratorioRepository(BaseRepository):
    """Repository para gestión de Exámenes de Laboratorio con paginación SQL"""
    
    def __init__(self):
        super().__init__('Laboratorio', 'laboratorio')
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene todos los exámenes de laboratorio con información completa"""
        return self.get_all_with_details()
    
    # ===============================
    # PAGINACIÓN Y FILTROS SQL - NUEVOS MÉTODOS
    # ===============================
    
    def get_paginated_exams_with_details(self, page: int = 0, page_size: int = 20, 
                                   search_term: str = "", tipo_analisis: str = "",
                                   tipo_servicio: str = "", fecha_desde: str = "", 
                                   fecha_hasta: str = "") -> Dict[str, Any]:
        """Obtiene exámenes paginados con filtros y búsqueda SQL - CORREGIDO"""
        try:
            search_term = search_term or ""
            tipo_analisis = tipo_analisis or ""
            tipo_servicio = tipo_servicio or ""
            fecha_desde = fecha_desde or ""
            fecha_hasta = fecha_hasta or ""
            # Construir condiciones WHERE
            where_conditions = ["1=1"]  # Condición base
            params = []
            
            # Filtro por búsqueda (paciente/cédula) - MEJORADO
            if search_term.strip():
                search_pattern = f"%{search_term.strip()}%"
                where_conditions.append("""
                    (p.Nombre LIKE ? OR p.Apellido_Paterno LIKE ? OR p.Apellido_Materno LIKE ? 
                    OR p.Cedula LIKE ? OR CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) LIKE ?)
                """)
                params.extend([search_pattern] * 5)
            
            # Filtro por tipo de análisis - CORREGIDO
            if tipo_analisis.strip() and tipo_analisis != "Todos":
                where_conditions.append("ta.Nombre = ?")
                params.append(tipo_analisis.strip())
            
            # Filtro por tipo de servicio - CORREGIDO
            if tipo_servicio.strip() and tipo_servicio != "Todos":
                where_conditions.append("l.tipo = ?")
                params.append(tipo_servicio.strip())
            
            # Filtros por fecha - MEJORADOS
            if fecha_desde.strip():
                where_conditions.append("CAST(l.Fecha AS DATE) >= ?")
                params.append(fecha_desde.strip())
            
            if fecha_hasta.strip():
                where_conditions.append("CAST(l.Fecha AS DATE) <= ?")
                params.append(fecha_hasta.strip())
            
            where_clause = " AND ".join(where_conditions)
            
            # Query principal con paginación - OPTIMIZADA
            query = f"""
            SELECT l.id, l.Detalles as detalles_examen, l.tipo, l.Fecha,
                -- Paciente
                CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) as paciente,
                p.Cedula as pacienteCedula,
                p.Nombre as pacienteNombre, 
                p.Apellido_Paterno as pacienteApellidoP,
                ISNULL(p.Apellido_Materno, '') as pacienteApellidoM,
                p.id as pacienteId,
                -- Tipo de Análisis
                ta.Nombre as tipoAnalisis,
                ta.Descripcion as detalles,
                ta.Precio_Normal, ta.Precio_Emergencia,
                ta.id as tipoAnalisisId,
                -- Precio según tipo
                CASE 
                    WHEN l.tipo = 'Normal' THEN CAST(ta.Precio_Normal AS DECIMAL(10,2))
                    ELSE CAST(ta.Precio_Emergencia AS DECIMAL(10,2))
                END as precio,
                -- Trabajador (puede ser NULL)
                l.Id_Trabajador,
                CASE 
                    WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno, ' ', ISNULL(t.Apellido_Materno, ''))
                    ELSE 'Sin asignar'
                END as trabajadorAsignado,
                ISNULL(tt.Tipo, 'Sin tipo') as trabajadorTipo,
                -- Usuario registro
                CONCAT(u.Nombre, ' ', ISNULL(u.Apellido_Paterno, '')) as registradoPor,
                -- IDs para referencias
                l.Id_RegistradoPor
            FROM Laboratorio l
            INNER JOIN Pacientes p ON l.Id_Paciente = p.id
            INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
            INNER JOIN Usuario u ON l.Id_RegistradoPor = u.id
            LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
            LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
            WHERE {where_clause}
            ORDER BY l.Fecha DESC, l.id DESC
            OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
            """
            
            # Agregar parámetros de paginación
            offset = page * page_size
            params.extend([offset, page_size])
            
            # Ejecutar query
            examenes = self._execute_query(query, params)
            
            if not examenes:
                print("⚠️ No se encontraron exámenes")
                return {
                    'examenes': [],
                    'page': page,
                    'page_size': page_size,
                    'total_records': 0
                }
            
            # Procesar datos para el formato esperado por QML - NORMALIZADO
            examenes_procesados = []
            for examen in examenes:
                try:
                    # Formatear fecha
                    fecha_formateada = ""
                    if examen.get('Fecha'):
                        try:
                            if isinstance(examen['Fecha'], str):
                                fecha_formateada = examen['Fecha'][:10]  # YYYY-MM-DD
                            else:
                                fecha_formateada = examen['Fecha'].strftime('%Y-%m-%d')
                        except:
                            fecha_formateada = str(examen.get('Fecha', ''))[:10]
                    
                    examen_procesado = {
                        # IDs
                        'analisisId': str(examen.get('id', 0)),
                        'pacienteId': examen.get('pacienteId', 0),
                        'tipoAnalisisId': examen.get('tipoAnalisisId', 0),
                        
                        # Información del paciente
                        'paciente': str(examen.get('paciente', 'Paciente Desconocido')).strip(),
                        'pacienteCedula': str(examen.get('pacienteCedula', '')).strip(),
                        'pacienteNombre': str(examen.get('pacienteNombre', '')).strip(),
                        'pacienteApellidoP': str(examen.get('pacienteApellidoP', '')).strip(),
                        'pacienteApellidoM': str(examen.get('pacienteApellidoM', '')).strip(),
                        
                        # Información del análisis
                        'tipoAnalisis': str(examen.get('tipoAnalisis', 'Análisis General')).strip(),
                        'detalles': str(examen.get('detalles', '')).strip(),
                        'detallesExamen': str(examen.get('detalles_examen', '')).strip(),
                        'tipo': str(examen.get('tipo', 'Normal')).strip(),
                        
                        # Precio - CORREGIDO
                        'precio': f"{float(examen.get('precio', 0)):.2f}",
                        'precioNumerico': float(examen.get('precio', 0)),
                        
                        # Trabajador
                        'trabajadorAsignado': str(examen.get('trabajadorAsignado', 'Sin asignar')).strip(),
                        'trabajadorId': examen.get('Id_Trabajador', 0) or 0,
                        
                        # Fecha y usuario
                        'fecha': fecha_formateada,
                        'registradoPor': str(examen.get('registradoPor', 'Sistema')).strip()
                    }
                    
                    examenes_procesados.append(examen_procesado)
                    
                except Exception as e:
                    print(f"⚠️ Error procesando examen {examen.get('id', 'desconocido')}: {e}")
                    continue
            
            total_records = self.get_exam_count_with_filters(search_term, tipo_analisis, tipo_servicio, fecha_desde, fecha_hasta)
            
            return {
                'examenes': examenes_procesados,
                'page': page,
                'page_size': page_size,
                'total_records': total_records
            }
            
        except Exception as e:
            print(f"❌ Error en paginación: {e}")
            import traceback
            traceback.print_exc()
            return {
                'examenes': [],
                'page': page,
                'page_size': page_size,
                'total_records': 0,
                'error': str(e)
            }
    
    def get_exam_count_with_filters(self, search_term: str = "", tipo_analisis: str = "",
                               tipo_servicio: str = "", fecha_desde: str = "",
                               fecha_hasta: str = "") -> int:
        """Cuenta total de exámenes con filtros aplicados - CORREGIDO"""
        try:
            # Construir condiciones WHERE (igual que en get_paginated_exams_with_details)
            where_conditions = ["1=1"]
            params = []
            
            if search_term.strip():
                search_pattern = f"%{search_term.strip()}%"
                where_conditions.append("""
                    (p.Nombre LIKE ? OR p.Apellido_Paterno LIKE ? OR p.Apellido_Materno LIKE ? 
                    OR p.Cedula LIKE ? OR CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', ISNULL(p.Apellido_Materno, '')) LIKE ?)
                """)
                params.extend([search_pattern] * 5)
            
            if tipo_analisis.strip() and tipo_analisis != "Todos":
                where_conditions.append("ta.Nombre = ?")
                params.append(tipo_analisis.strip())
            
            if tipo_servicio.strip() and tipo_servicio != "Todos":
                where_conditions.append("l.tipo = ?")
                params.append(tipo_servicio.strip())
            
            if fecha_desde.strip():
                where_conditions.append("CAST(l.Fecha AS DATE) >= ?")
                params.append(fecha_desde.strip())
            
            if fecha_hasta.strip():
                where_conditions.append("CAST(l.Fecha AS DATE) <= ?")
                params.append(fecha_hasta.strip())
            
            where_clause = " AND ".join(where_conditions)
            
            query = f"""
            SELECT COUNT(*) as total
            FROM Laboratorio l
            INNER JOIN Pacientes p ON l.Id_Paciente = p.id
            INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
            INNER JOIN Usuario u ON l.Id_RegistradoPor = u.id
            LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
            LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
            WHERE {where_clause}
            """
            
            result = self._execute_query(query, params, fetch_one=True)
            count = result['total'] if result else 0
            return count
            
        except Exception as e:
            print(f"❌ Error contando exámenes: {e}")
            return 0
        
    def search_patient_by_full_name(self, nombre_completo: str, limite: int = 10) -> List[Dict[str, Any]]:
        """
        ✅ MÉTODO MEJORADO - Búsqueda más robusta por nombre completo
        
        Mejoras:
        - Búsqueda con múltiples estrategias
        - Manejo de apellidos opcionales
        - Ordenamiento por relevancia
        """
        try:
            if not nombre_completo or len(nombre_completo.strip()) < 3:
                return []
            
            nombre_limpio = nombre_completo.strip()
            print(f"🔍 Búsqueda mejorada por nombre: '{nombre_limpio}'")
            
            # ✅ ESTRATEGIA 1: Búsqueda exacta
            query_exacta = """
            SELECT TOP (?)
                id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
                CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo,
                1 as relevancia
            FROM Pacientes
            WHERE CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) = ?
            """
            
            resultados_exactos = self._execute_query(query_exacta, (limite, nombre_limpio))
            
            if resultados_exactos:
                print(f"✅ Encontradas {len(resultados_exactos)} coincidencias exactas")
                return resultados_exactos
            
            # ✅ ESTRATEGIA 2: Búsqueda con LIKE (contiene)
            query_like = """
            SELECT TOP (?)
                id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
                CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo,
                2 as relevancia
            FROM Pacientes
            WHERE CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) LIKE ?
            """
            
            pattern_like = f"%{nombre_limpio}%"
            resultados_like = self._execute_query(query_like, (limite, pattern_like))
            
            if resultados_like:
                print(f"✅ Encontradas {len(resultados_like)} coincidencias parciales")
                return resultados_like
            
            # ✅ ESTRATEGIA 3: Búsqueda por palabras individuales
            palabras = nombre_limpio.split()
            if len(palabras) >= 2:
                query_palabras = """
                SELECT TOP (?)
                    id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
                    CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo,
                    3 as relevancia
                FROM Pacientes
                WHERE Nombre LIKE ? OR Apellido_Paterno LIKE ?
                ORDER BY 
                    CASE WHEN Nombre LIKE ? THEN 1 ELSE 2 END,
                    Nombre, Apellido_Paterno
                """
                
                palabra1_pattern = f"%{palabras[0]}%"
                palabra2_pattern = f"%{palabras[1]}%" if len(palabras) > 1 else palabra1_pattern
                
                resultados_palabras = self._execute_query(query_palabras, (
                    limite, palabra1_pattern, palabra2_pattern, palabra1_pattern
                ))
                
                if resultados_palabras:
                    print(f"✅ Encontradas {len(resultados_palabras)} coincidencias por palabras")
                    return resultados_palabras
            
            print(f"❌ No se encontraron pacientes con nombre: '{nombre_limpio}'")
            return []
            
        except Exception as e:
            print(f"❌ Error en búsqueda mejorada por nombre: {e}")
            return []
    
    # ===============================
    # GESTIÓN DE TIPOS DE ANÁLISIS
    # ===============================
    
    def get_analysis_types(self) -> List[Dict[str, Any]]:
        """Obtiene tipos de análisis disponibles"""
        query = """
        SELECT id, Nombre, Descripcion, Precio_Normal, Precio_Emergencia 
        FROM Tipos_Analisis 
        ORDER BY Nombre
        """
        return self._execute_query(query)

    def get_analysis_type_by_id(self, tipo_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de análisis por ID"""
        query = "SELECT * FROM Tipos_Analisis WHERE id = ?"
        return self._execute_query(query, (tipo_id,), fetch_one=True)
    
    def _analysis_type_exists(self, tipo_id: int) -> bool:
        """Verifica si existe el tipo de análisis"""
        query = "SELECT COUNT(*) as count FROM Tipos_Analisis WHERE id = ?"
        result = self._execute_query(query, (tipo_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    # ===============================
    # GESTIÓN DE PACIENTES
    # ===============================
    
    def search_patient_by_cedula_exact(self, cedula: str) -> Optional[Dict[str, Any]]:
        """Busca paciente por cédula exacta - CORREGIDO con query directa"""
        try:
            if not cedula or len(cedula.strip()) < 5:
                return None
            
            cedula_clean = cedula.strip()
            
            # Query directa a tabla Pacientes
            query = """
            SELECT 
                id,
                Nombre,
                Apellido_Paterno,
                ISNULL(Apellido_Materno, '') as Apellido_Materno,
                Cedula,
                CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo
            FROM Pacientes
            WHERE Cedula = ?
            """
            
            result = self._execute_query(query, (cedula_clean,), fetch_one=True)
            
            if result:
                print(f"👤 Paciente encontrado por cédula: {cedula_clean} -> {result['nombre_completo']}")
                # Normalizar nombres de campos
                normalized_result = {
                    'id': result['id'],
                    'Nombre': result['Nombre'],
                    'Apellido_Paterno': result['Apellido_Paterno'],
                    'Apellido_Materno': result['Apellido_Materno'],
                    'Cedula': result['Cedula'],
                    'nombre_completo': result['nombre_completo'],
                    # Añadir aliases para compatibilidad
                    'nombre': result['Nombre'],
                    'apellido_paterno': result['Apellido_Paterno'],
                    'apellido_materno': result['Apellido_Materno']
                }
                return normalized_result
            
            return None
            
        except Exception as e:
            print(f"❌ Error buscando paciente por cédula: {e}")
            return None
    
    def search_patients_by_cedula_partial(self, cedula: str, limit: int = 5) -> List[Dict[str, Any]]:
        """Busca pacientes por cédula parcial (para sugerencias) - CORREGIDO"""
        try:
            if not cedula or len(cedula.strip()) < 3:
                return []
            
            cedula_clean = cedula.strip()
            
            # Query directa a tabla Pacientes
            query = """
            SELECT TOP (?)
                id,
                Nombre,
                Apellido_Paterno, 
                ISNULL(Apellido_Materno, '') as Apellido_Materno,
                Cedula,
                CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo
            FROM Pacientes
            WHERE Cedula LIKE ?
            ORDER BY 
                CASE WHEN Cedula = ? THEN 1 ELSE 2 END,
                Cedula
            """
            
            search_pattern = f"%{cedula_clean}%"
            return self._execute_query(query, (limit, search_pattern, cedula_clean))
            
        except Exception as e:
            print(f"❌ Error en búsqueda parcial por cédula: {e}")
            return []
    
    def buscar_o_crear_paciente_simple(self, nombre: str, apellido_paterno: str, 
                              apellido_materno: str = "", cedula: str = "") -> int:
        """
        ✅ MÉTODO CORREGIDO - Busca paciente de forma inteligente antes de crear uno nuevo
        
        Estrategia de búsqueda:
        1. Si hay cédula → buscar por cédula exacta
        2. Si no encuentra por cédula o no hay cédula → buscar por nombre completo
        3. Solo si no encuentra por ningún método → crear nuevo paciente
        """
        try:
            nombre = nombre.strip()
            apellido_paterno = apellido_paterno.strip()
            apellido_materno = apellido_materno.strip()
            cedula_clean = cedula.strip() if cedula else None
            
            # Validaciones básicas (sin cédula obligatoria)
            if not nombre or len(nombre) < 2:
                raise ValidationError("nombre", nombre, "Nombre es obligatorio")
            if not apellido_paterno or len(apellido_paterno) < 2:
                raise ValidationError("apellido_paterno", apellido_paterno, "Apellido paterno es obligatorio")
            
            print(f"🔍 Buscando paciente: {nombre} {apellido_paterno} {apellido_materno} - Cédula: {cedula_clean or 'N/A'}")
            
            # ✅ ESTRATEGIA 1: Buscar por cédula si existe y es válida
            if cedula_clean and len(cedula_clean) >= 5:
                print(f"📋 Buscando por cédula: {cedula_clean}")
                existing_patient = self.search_patient_by_cedula_exact(cedula_clean)
                if existing_patient:
                    print(f"✅ Paciente encontrado por cédula: {existing_patient['nombre_completo']} (ID: {existing_patient['id']})")
                    return existing_patient['id']
                else:
                    print(f"❌ No se encontró paciente con cédula: {cedula_clean}")
            
            # ✅ ESTRATEGIA 2: Buscar por nombre completo (NUEVA LÓGICA)
            nombre_completo_busqueda = f"{nombre} {apellido_paterno} {apellido_materno}".strip()
            print(f"👤 Buscando por nombre completo: '{nombre_completo_busqueda}'")
            
            # Usar el método existente de búsqueda por nombre
            pacientes_por_nombre = self.search_patient_by_full_name(nombre_completo_busqueda, limite=10)
            
            if pacientes_por_nombre:
                # ✅ BUSCAR COINCIDENCIA EXACTA O MUY SIMILAR
                paciente_encontrado = self._encontrar_mejor_coincidencia_nombre(
                    nombre, apellido_paterno, apellido_materno, pacientes_por_nombre
                )
                
                if paciente_encontrado:
                    print(f"✅ Paciente encontrado por nombre: {paciente_encontrado['nombre_completo']} (ID: {paciente_encontrado['id']})")
                    return paciente_encontrado['id']
            
            print(f"❌ No se encontró paciente existente")
            
            # ✅ ESTRATEGIA 3: Crear nuevo paciente solo si no se encontró por ningún método
            print(f"➕ Creando nuevo paciente: {nombre} {apellido_paterno} {apellido_materno}")
            
            query = """
            INSERT INTO Pacientes (Nombre, Apellido_Paterno, Apellido_Materno, Cedula)
            OUTPUT INSERTED.id
            VALUES (?, ?, ?, ?)
            """
            
            result = self._execute_query(query, (nombre, apellido_paterno, apellido_materno, cedula_clean), fetch_one=True)
            patient_id = result['id'] if result else None
            
            if patient_id:
                print(f"✅ Nuevo paciente creado: {nombre} {apellido_paterno} - ID: {patient_id}")
                return patient_id
            else:
                raise ValidationError("paciente", None, "Error creando paciente en base de datos")
            
        except Exception as e:
            print(f"❌ Error gestionando paciente: {e}")
            raise ValidationError("paciente", str(e), "Error creando/buscando paciente")
        
    
    # Metodo auxiliar
    def _patient_exists_by_id(self, paciente_id: int) -> bool:
        """Verifica si existe el paciente por ID - CORREGIDO: usar tabla Pacientes"""
        query = "SELECT COUNT(*) as count FROM Pacientes WHERE id = ?"
        result = self._execute_query(query, (paciente_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    # ===============================
    # CRUD ESPECÍFICO
    # ===============================
    
    def create_lab_exam(self, paciente_id: int, tipo_analisis_id: int, tipo: str = "Normal", 
                   trabajador_id: int = None, usuario_id: int = 10, detalles: str = None) -> int:
        """Crea nuevo examen de laboratorio"""
        validate_required(paciente_id, "paciente_id")
        validate_required(tipo_analisis_id, "tipo_analisis_id")
        validate_required(usuario_id, "usuario_id")
        
        # Verificar entidades
        if not self._patient_exists(paciente_id):
            raise ValidationError("paciente_id", paciente_id, "Paciente no encontrado")
        if not self._analysis_type_exists(tipo_analisis_id):
            raise ValidationError("tipo_analisis_id", tipo_analisis_id, "Tipo de análisis no encontrado")
        if trabajador_id and not self._worker_exists(trabajador_id):
            raise ValidationError("trabajador_id", trabajador_id, "Trabajador no encontrado")
        
        lab_data = {
            'Detalles': detalles or f"Examen de laboratorio",
            'tipo': tipo.capitalize(),
            'Id_Paciente': paciente_id,
            'Id_Trabajador': trabajador_id,
            'Id_Tipo_Analisis': tipo_analisis_id,
            'Fecha': datetime.now(),
            'Id_RegistradoPor': usuario_id
        }
        
        lab_id = self.insert(lab_data)
        print(f"🧪 Examen creado - ID {lab_id}")
        return lab_id
    
    def update_lab_exam(self, lab_id: int, tipo_analisis_id: int = None, 
                       tipo_servicio: str = None, trabajador_id: int = None,
                       detalles: str = None) -> bool:
        """Actualiza examen de laboratorio existente"""
        # Verificar existencia
        existing_exam = self.get_by_id(lab_id)
        if not existing_exam:
            raise ValidationError("lab_id", lab_id, "Examen de laboratorio no encontrado")
        
        update_data = {}
        
        if tipo_analisis_id is not None:
            if not self._analysis_type_exists(tipo_analisis_id):
                raise ValidationError("tipo_analisis_id", tipo_analisis_id, "Tipo de análisis no encontrado")
            update_data['Id_Tipo_Analisis'] = tipo_analisis_id
        
        if tipo_servicio is not None:
            if tipo_servicio not in ['Normal', 'Emergencia']:
                raise ValidationError("tipo_servicio", tipo_servicio, "Tipo de servicio debe ser Normal o Emergencia")
            update_data['tipo'] = tipo_servicio
        
        if trabajador_id is not None:
            if trabajador_id and not self._worker_exists(trabajador_id):
                raise ValidationError("trabajador_id", trabajador_id, "Trabajador no encontrado")
            update_data['Id_Trabajador'] = trabajador_id if trabajador_id != 0 else None
        
        if detalles is not None:
            update_data['Detalles'] = detalles.strip() if detalles else None
        
        if not update_data:
            return True
        
        success = self.update(lab_id, update_data)
        if success:
            print(f"🔬 Examen de laboratorio actualizado: ID {lab_id}")
        
        return success
    
    def assign_worker_to_exam(self, lab_id: int, trabajador_id: int) -> bool:
        """Asigna trabajador a examen de laboratorio"""
        return self.update_lab_exam(lab_id, trabajador_id=trabajador_id)
    
    def unassign_worker_from_exam(self, lab_id: int) -> bool:
        """Desasigna trabajador de examen"""
        return self.update_lab_exam(lab_id, trabajador_id=0)
    
    # ===============================
    # CONSULTAS CON RELACIONES - ACTUALIZADA (SIN EDAD)
    # ===============================
    
    @cached_query('laboratorio_completo', ttl=300)
    def get_all_with_details(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Obtiene todos los exámenes con información completa - SIN EDAD"""
        query = """
        SELECT l.id, l.Detalles as detalles_examen, l.tipo, l.Fecha,
            -- Paciente (SIN EDAD, CON CÉDULA)
            CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
            p.Cedula as paciente_cedula,
            p.Nombre as paciente_nombre, 
            p.Apellido_Paterno as paciente_apellido_p,
            p.Apellido_Materno as paciente_apellido_m,
            -- Tipo de Análisis
            ta.Nombre as tipo_analisis,
            ta.Descripcion as detalles_analisis,
            ta.Precio_Normal, ta.Precio_Emergencia,
            -- Precio según tipo
            CASE 
                WHEN l.tipo = 'Normal' THEN ta.Precio_Normal 
                ELSE ta.Precio_Emergencia 
            END as precio,
            -- Trabajador (puede ser NULL)
            l.Id_Trabajador,
            CASE 
                WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno, ' ', t.Apellido_Materno)
                ELSE 'Sin asignar'
            END as trabajador_completo,
            tt.Tipo as trabajador_tipo,
            -- Usuario registro
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as registrado_por,
            -- IDs para referencias
            l.Id_Paciente, l.Id_Tipo_Analisis, l.Id_RegistradoPor
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        INNER JOIN Usuario u ON l.Id_RegistradoPor = u.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        ORDER BY l.Fecha DESC
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        return self._execute_query(query, (limit,))
    
    def get_lab_exam_by_id_complete(self, lab_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene examen específico con información completa - SIN EDAD"""
        query = """
        SELECT l.id, l.Detalles, l.tipo, l.Fecha,
               -- Paciente (SIN EDAD)
               p.id as paciente_id,
               CONCAT(p.Nombre, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno) as paciente_completo,
               p.Nombre as paciente_nombre, p.Apellido_Paterno as paciente_apellido_p,
               p.Apellido_Materno as paciente_apellido_m,
               p.Cedula as paciente_cedula,
               -- Tipo de Análisis
               ta.id as tipo_analisis_id, ta.Nombre as tipo_analisis,
               ta.Descripcion as detalles_analisis,
               ta.Precio_Normal, ta.Precio_Emergencia,
               -- Trabajador (puede ser NULL)
               t.id as trabajador_id,
               CASE 
                   WHEN t.id IS NOT NULL THEN CONCAT(t.Nombre, ' ', t.Apellido_Paterno, ' ', t.Apellido_Materno)
                   ELSE 'Sin asignar'
               END as trabajador_completo,
               t.Nombre as trabajador_nombre, t.Apellido_Paterno as trabajador_apellido_p,
               t.Apellido_Materno as trabajador_apellido_m,
               tt.id as trabajador_tipo_id, tt.Tipo as trabajador_tipo,
               -- Usuario que registró
               u.Nombre as usuario_nombre, u.Apellido_Paterno as usuario_apellido
        FROM Laboratorio l
        INNER JOIN Pacientes p ON l.Id_Paciente = p.id
        INNER JOIN Tipos_Analisis ta ON l.Id_Tipo_Analisis = ta.id
        INNER JOIN Usuario u ON l.Id_RegistradoPor = u.id
        LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
        LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        WHERE l.id = ?
        """
        return self._execute_query(query, (lab_id,), fetch_one=True)
    
    # ===============================
    # TRABAJADORES DISPONIBLES
    # ===============================
    
    def get_available_lab_workers(self) -> List[Dict[str, Any]]:
        """
        Obtiene trabajadores disponibles para laboratorio
        CORREGIDO: Busca 'Laboratorista' en lugar de 'Laboratorio'
        """
        query = """
        SELECT t.id, 
            t.Nombre, t.Apellido_Paterno, t.Apellido_Materno,
            CONCAT(t.Nombre, ' ', t.Apellido_Paterno, ' ', t.Apellido_Materno) as nombre_completo,
            tt.Tipo as tipo_trabajador,
            COUNT(l.id) as examenes_asignados
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Laboratorio l ON t.id = l.Id_Trabajador
        WHERE tt.area_funcional = 'LABORATORIO'
        GROUP BY t.id, t.Nombre, t.Apellido_Paterno, t.Apellido_Materno, tt.Tipo
        ORDER BY examenes_asignados, t.Nombre
        """
        return self._execute_query(query)
    
    def get_exam_types_list(self) -> List[str]:
        """Obtiene lista de tipos de exámenes disponibles desde Tipos_Analisis"""
        query = "SELECT DISTINCT Nombre FROM Tipos_Analisis ORDER BY Nombre"
        result = self._execute_query(query)
        return [row['Nombre'] for row in result]
    
    # ===============================
    # ESTADÍSTICAS
    # ===============================
    
    @cached_query('stats_laboratorio', ttl=300)
    def get_laboratory_statistics(self) -> Dict[str, Any]:
        """Estadísticas completas de laboratorio"""
        # Estadísticas generales
        general_query = """
        SELECT 
            COUNT(*) as total_examenes,
            COUNT(DISTINCT Id_Paciente) as pacientes_unicos,
            COUNT(DISTINCT CASE WHEN Id_Trabajador IS NOT NULL THEN Id_Trabajador END) as trabajadores_asignados,
            COUNT(CASE WHEN Id_Trabajador IS NULL THEN 1 END) as examenes_sin_asignar,
            COUNT(CASE WHEN tipo = 'Normal' THEN 1 END) as examenes_normales,
            COUNT(CASE WHEN tipo = 'Emergencia' THEN 1 END) as examenes_emergencia
        FROM Laboratorio
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True)
        
        return {
            'general': general_stats,
            'por_tipo_analisis': [],
            'por_trabajador': []
        }
    
    def _encontrar_mejor_coincidencia_nombre(self, nombre: str, apellido_paterno: str, 
                                  apellido_materno: str, candidatos: List[Dict]) -> Optional[Dict]:
        """
        ✅ MÉTODO MEJORADO - Encuentra la mejor coincidencia por nombre entre los candidatos
        Más tolerante con coincidencias para evitar duplicados
        
        Prioridades de coincidencia:
        1. Coincidencia exacta completa
        2. Coincidencia de nombre + apellido paterno (ignorando apellido materno)
        3. Coincidencia similar con tolerancia a errores menores
        """
        if not candidatos:
            return None
        
        nombre_target = nombre.lower().strip()
        apellido_p_target = apellido_paterno.lower().strip()
        apellido_m_target = apellido_materno.lower().strip() if apellido_materno else ""
        
        print(f"🎯 Buscando mejor coincidencia para: '{nombre_target} {apellido_p_target} {apellido_m_target}'")
        
        mejor_candidato = None
        mejor_score = 0
        
        for candidato in candidatos:
            nombre_db = candidato.get('Nombre', '').lower().strip()
            apellido_p_db = candidato.get('Apellido_Paterno', '').lower().strip()
            apellido_m_db = candidato.get('Apellido_Materno', '').lower().strip() if candidato.get('Apellido_Materno') else ""
            
            score = 0
            
            # ✅ COINCIDENCIA EXACTA COMPLETA (máxima prioridad)
            if (nombre_db == nombre_target and 
                apellido_p_db == apellido_p_target and 
                apellido_m_db == apellido_m_target):
                print(f"🎯 Coincidencia exacta completa: {candidato['nombre_completo']}")
                return candidato
            
            # ✅ COINCIDENCIA NOMBRE + APELLIDO PATERNO (alta prioridad) - IGNORAR APELLIDO MATERNO
            if nombre_db == nombre_target and apellido_p_db == apellido_p_target:
                score = 95  # ✅ AUMENTADO para dar más prioridad
                print(f"🎯 Coincidencia nombre + apellido paterno: {candidato['nombre_completo']} (score: {score})")
            
            # ✅ COINCIDENCIA FLEXIBLE: nombre + apellido con tolerancia
            elif (self._nombres_similares(nombre_db, nombre_target) and 
                self._nombres_similares(apellido_p_db, apellido_p_target)):
                score = 85  # ✅ AUMENTADO para ser más tolerante
                print(f"🎯 Coincidencia similar: {candidato['nombre_completo']} (score: {score})")
            
            # ✅ NUEVA: Coincidencia solo por nombre completo concatenado
            elif self._nombres_similares(f"{nombre_db} {apellido_p_db}", f"{nombre_target} {apellido_p_target}"):
                score = 80
                print(f"🎯 Coincidencia nombre completo: {candidato['nombre_completo']} (score: {score})")
            
            # ✅ COINCIDENCIA PARCIAL (baja prioridad)
            elif (nombre_db == nombre_target or apellido_p_db == apellido_p_target):
                score = 60  # ✅ AUMENTADO ligeramente
                print(f"🎯 Coincidencia parcial: {candidato['nombre_completo']} (score: {score})")
            
            # Actualizar mejor candidato
            if score > mejor_score:
                mejor_score = score
                mejor_candidato = candidato
        
        # ✅ UMBRAL REDUCIDO para ser más tolerante
        if mejor_score >= 60:  # ✅ REDUCIDO de 70 a 60
            print(f"✅ Mejor candidato seleccionado: {mejor_candidato['nombre_completo']} (score: {mejor_score})")
            return mejor_candidato
        else:
            print(f"❌ Ningún candidato cumple el umbral mínimo (mejor score: {mejor_score})")
            return None
        
    def _nombres_similares(self, nombre1: str, nombre2: str, tolerancia: float = 0.75) -> bool:
        """
        ✅ MÉTODO MEJORADO - Compara similaridad entre nombres con tolerancia a errores menores
        Más permisivo para evitar duplicados
        """
        if not nombre1 or not nombre2:
            return False
        
        if nombre1 == nombre2:
            return True
        
        # ✅ TOLERANCIA MEJORADA para nombres con acentos o ligeras diferencias
        nombre1_norm = self._normalizar_texto_completo(nombre1)
        nombre2_norm = self._normalizar_texto_completo(nombre2)
        
        if nombre1_norm == nombre2_norm:
            return True
        
        # Similaridad simple basada en caracteres comunes
        len_max = max(len(nombre1), len(nombre2))
        len_min = min(len(nombre1), len(nombre2))
        
        if len_max == 0:
            return False
        
        # ✅ MÁS TOLERANTE: Si uno es significativamente más largo que el otro
        if len_min / len_max < 0.5:  # ✅ REDUCIDO de 0.6 a 0.5
            return False
        
        # Contar caracteres comunes en posiciones similares
        caracteres_comunes = 0
        for i in range(min(len(nombre1), len(nombre2))):
            if nombre1[i] == nombre2[i]:
                caracteres_comunes += 1
        
        ratio = caracteres_comunes / len_max
        return ratio >= tolerancia
    
    def _normalizar_texto_completo(self, texto: str) -> str:
        """
        ✅ NUEVO MÉTODO - Normalización completa de texto para comparaciones
        Elimina acentos, ñ, mayúsculas y espacios extra
        """
        if not texto:
            return ""
        
        # Diccionario de reemplazos para caracteres especiales
        reemplazos = {
            'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
            'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', 'ē': 'e', 'ĕ': 'e', 'ę': 'e', 
            'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i',
            'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o',
            'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
            'ñ': 'n', 'ň': 'n', 'ņ': 'n',
            'ç': 'c', 'ć': 'c', 'č': 'c', 'ĉ': 'c', 'ċ': 'c',
            'ß': 'ss'
        }
        
        texto_normalizado = texto.lower().strip()
        
        # Aplicar reemplazos
        for original, reemplazo in reemplazos.items():
            texto_normalizado = texto_normalizado.replace(original, reemplazo)
        
        # Limpiar espacios múltiples
        texto_normalizado = ' '.join(texto_normalizado.split())
        
        return texto_normalizado
    
    # Agregar estos métodos a la clase LaboratorioRepository después de los métodos existentes

    def buscar_paciente_unificado(self, termino_busqueda: str, limite: int = 5) -> List[Dict[str, Any]]:
        """
        Búsqueda unificada que detecta automáticamente el tipo de entrada
        
        Args:
            termino_busqueda: Término a buscar (cédula o nombre)
            limite: Máximo número de resultados
            
        Returns:
            Lista de pacientes encontrados con score de relevancia
        """
        try:
            if not termino_busqueda or len(termino_busqueda.strip()) < 2:
                return []
            
            termino_limpio = termino_busqueda.strip()
            tipo_busqueda = self._detectar_tipo_busqueda(termino_limpio)
            
            print(f"🔍 Búsqueda unificada: '{termino_limpio}' - Tipo: {tipo_busqueda}")
            
            resultados = []
            
            if tipo_busqueda == 'cedula':
                # Búsqueda por cédula
                resultados = self._buscar_por_cedula_mejorado(termino_limpio, limite)
            elif tipo_busqueda == 'nombre':
                # Búsqueda por nombre
                resultados = self._buscar_por_nombre_mejorado(termino_limpio, limite)
            elif tipo_busqueda == 'mixto':
                # Búsqueda mixta - intentar ambos métodos
                resultados_cedula = self._buscar_por_cedula_mejorado(termino_limpio, limite//2)
                resultados_nombre = self._buscar_por_nombre_mejorado(termino_limpio, limite//2)
                resultados = resultados_cedula + resultados_nombre
            
            # Ordenar por relevancia y limitar resultados
            resultados_ordenados = sorted(resultados, key=lambda x: x.get('relevancia', 999))
            return resultados_ordenados[:limite]
            
        except Exception as e:
            print(f"❌ Error en búsqueda unificada: {e}")
            return []

    def _detectar_tipo_busqueda(self, termino: str) -> str:
        """
        Detecta automáticamente si el término de búsqueda es cédula o nombre
        
        Returns:
            'cedula' si es número de cédula
            'nombre' si es texto/nombre
            'mixto' si contiene números y letras
        """
        if not termino or len(termino.strip()) < 2:
            return 'invalido'
        
        termino_limpio = termino.strip()
        
        # Verificar si es solo números (posible cédula)
        if termino_limpio.replace(' ', '').isdigit():
            return 'cedula'
        
        # Verificar si contiene solo letras y espacios (nombre)
        if all(c.isalpha() or c.isspace() for c in termino_limpio):
            return 'nombre'
        
        # Si contiene números y letras
        return 'mixto'

    def _analizar_termino_nombre(self, termino: str) -> Dict[str, str]:
        """
        Analiza un nombre completo y lo separa en componentes
        
        Returns:
            Dict con 'nombre', 'apellido_paterno', 'apellido_materno'
        """
        if not termino:
            return {'nombre': '', 'apellido_paterno': '', 'apellido_materno': ''}
        
        # Limpiar y dividir por espacios
        palabras = [p.strip().title() for p in termino.strip().split() if p.strip()]
        
        if len(palabras) == 0:
            return {'nombre': '', 'apellido_paterno': '', 'apellido_materno': ''}
        
        # Palabras conectoras que suelen ser parte de apellidos
        conectores = {'de', 'del', 'de la', 'van', 'von', 'da', 'dos', 'las', 'los', 'mc', 'mac'}
        
        # Nombres comunes que suelen ir juntos (nombres compuestos)
        nombres_compuestos_comunes = {
            'ana', 'maria', 'jose', 'juan', 'luis', 'carlos', 'miguel', 'angel',
            'pedro', 'antonio', 'francisco', 'manuel', 'rafael', 'alejandro',
            'fernando', 'ricardo', 'roberto', 'eduardo', 'daniel', 'david',
            'rosa', 'carmen', 'elena', 'laura', 'patricia', 'sandra', 'monica',
            'claudia', 'gloria', 'martha', 'teresa', 'angela', 'beatriz',
            'luz', 'esperanza', 'dolores', 'pilar', 'mercedes', 'socorro'
        }
        
        # Análisis según cantidad de palabras
        if len(palabras) == 1:
            return {
                'nombre': palabras[0],
                'apellido_paterno': '',
                'apellido_materno': ''
            }
        elif len(palabras) == 2:
            return {
                'nombre': palabras[0],
                'apellido_paterno': palabras[1],
                'apellido_materno': ''
            }
        elif len(palabras) == 3:
            # Lógica mejorada para 3 palabras
            primera = palabras[0].lower()
            segunda = palabras[1].lower()
            
            # Si las dos primeras son nombres comunes → nombre compuesto
            if (primera in nombres_compuestos_comunes and 
                segunda in nombres_compuestos_comunes):
                return {
                    'nombre': f"{palabras[0]} {palabras[1]}",
                    'apellido_paterno': palabras[2],
                    'apellido_materno': ''
                }
            else:
                # Patrón normal: Nombre + Apellido Paterno + Apellido Materno
                return {
                    'nombre': palabras[0],
                    'apellido_paterno': palabras[1],
                    'apellido_materno': palabras[2]
                }
                
        elif len(palabras) == 4:
            # Lógica mejorada para 4 palabras
            primera = palabras[0].lower()
            segunda = palabras[1].lower()
            tercera = palabras[2].lower()
            
            # Caso 1: Dos nombres + dos apellidos (más común)
            if (primera in nombres_compuestos_comunes and 
                segunda in nombres_compuestos_comunes):
                return {
                    'nombre': f"{palabras[0]} {palabras[1]}",
                    'apellido_paterno': palabras[2],
                    'apellido_materno': palabras[3]
                }
            
            # Caso 2: Un nombre + apellido con conector
            if tercera in conectores:
                return {
                    'nombre': palabras[0],
                    'apellido_paterno': palabras[1],
                    'apellido_materno': f"{palabras[2]} {palabras[3]}"
                }
            
            # Caso 3: Nombre + apellido compuesto + apellido simple
            else:
                # Asumir que es: Nombre + Apellido_Paterno + Apellido_Materno (compuesto)
                return {
                    'nombre': palabras[0],
                    'apellido_paterno': palabras[1],
                    'apellido_materno': f"{palabras[2]} {palabras[3]}"
                }
        
        else:
            # 5 o más palabras - lógica compleja
            nombre_parts = []
            apellido_parts = []
            en_apellidos = False
            
            for i, palabra in enumerate(palabras):
                palabra_lower = palabra.lower()
                
                # Si es un conector, probablemente estamos en apellidos
                if palabra_lower in conectores:
                    en_apellidos = True
                    apellido_parts.append(palabra)
                elif en_apellidos:
                    apellido_parts.append(palabra)
                else:
                    # Detectar cuándo termina el nombre
                    if i < 2:  # Máximo 2 nombres
                        # Si es nombre común, puede ser parte del nombre compuesto
                        if (palabra_lower in nombres_compuestos_comunes or 
                            (i == 1 and palabras[0].lower() in nombres_compuestos_comunes)):
                            nombre_parts.append(palabra)
                        else:
                            # Ya no es nombre, empezar apellidos
                            en_apellidos = True
                            apellido_parts.append(palabra)
                    else:
                        # A partir del 3er elemento, son apellidos
                        en_apellidos = True
                        apellido_parts.append(palabra)
            
            # Si no se identificaron apellidos claramente
            if not apellido_parts and len(palabras) >= 3:
                # Estrategia de respaldo: últimas 2 palabras son apellidos
                nombre_parts = palabras[:-2]
                apellido_parts = palabras[-2:]
            elif not apellido_parts:
                # Solo hay nombres
                nombre_parts = palabras[:-1]  
                apellido_parts = [palabras[-1]]
            
            # Construir resultado
            nombre = ' '.join(nombre_parts) if nombre_parts else palabras[0]
            
            if len(apellido_parts) >= 2:
                apellido_paterno = apellido_parts[0]
                apellido_materno = ' '.join(apellido_parts[1:])
            elif len(apellido_parts) == 1:
                apellido_paterno = apellido_parts[0]
                apellido_materno = ''
            else:
                # Respaldo para casos extremos
                apellido_paterno = palabras[1] if len(palabras) > 1 else ''
                apellido_materno = palabras[2] if len(palabras) > 2 else ''
            
            return {
                'nombre': nombre,
                'apellido_paterno': apellido_paterno,
                'apellido_materno': apellido_materno
            }

    def _buscar_por_cedula_mejorado(self, cedula: str, limite: int) -> List[Dict[str, Any]]:
        """Búsqueda mejorada por cédula con scoring"""
        if not self._es_cedula_valida(cedula):
            return []
        
        cedula_numeros = ''.join(c for c in cedula if c.isdigit())
        
        # Búsqueda exacta primero
        query_exacta = """
        SELECT 
            id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
            CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo,
            1 as relevancia,
            'cedula_exacta' as tipo_coincidencia
        FROM Pacientes
        WHERE Cedula = ?
        """
        
        resultados_exactos = self._execute_query(query_exacta, (cedula_numeros,))
        
        if resultados_exactos:
            return resultados_exactos
        
        # Búsqueda parcial si no hay exacta
        query_parcial = """
        SELECT TOP (?)
            id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
            CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo,
            2 as relevancia,
            'cedula_parcial' as tipo_coincidencia
        FROM Pacientes
        WHERE Cedula LIKE ?
        ORDER BY 
            CASE WHEN Cedula LIKE ? THEN 1 ELSE 2 END,
            LEN(Cedula),
            Cedula
        """
        
        patron_inicio = f"{cedula_numeros}%"
        patron_contiene = f"%{cedula_numeros}%"
        
        return self._execute_query(query_parcial, (limite, patron_contiene, patron_inicio))

    def _buscar_por_nombre_mejorado(self, nombre: str, limite: int) -> List[Dict[str, Any]]:
        """Búsqueda mejorada por nombre con scoring"""
        termino_normalizado = self._normalizar_termino_busqueda(nombre)
        
        # Búsqueda por coincidencia en nombre completo
        query = """
        SELECT TOP (?)
            id, Nombre, Apellido_Paterno, Apellido_Materno, Cedula,
            CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, '')) as nombre_completo,
            CASE 
                WHEN LOWER(CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, ''))) LIKE ? THEN 1
                WHEN LOWER(Nombre) LIKE ? OR LOWER(Apellido_Paterno) LIKE ? THEN 2
                ELSE 3
            END as relevancia,
            CASE 
                WHEN LOWER(CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, ''))) LIKE ? THEN 'nombre_completo'
                WHEN LOWER(Nombre) LIKE ? OR LOWER(Apellido_Paterno) LIKE ? THEN 'nombre_parcial'
                ELSE 'otra'
            END as tipo_coincidencia
        FROM Pacientes
        WHERE 
            LOWER(Nombre) LIKE ? OR 
            LOWER(Apellido_Paterno) LIKE ? OR 
            LOWER(Apellido_Materno) LIKE ? OR
            LOWER(CONCAT(Nombre, ' ', Apellido_Paterno, ' ', ISNULL(Apellido_Materno, ''))) LIKE ?
        ORDER BY relevancia, Nombre, Apellido_Paterno
        """
        
        patron_exacto = f"%{termino_normalizado}%"
        patron_palabra = f"%{termino_normalizado}%"
        
        return self._execute_query(query, (
            limite, patron_exacto, patron_palabra, patron_palabra,
            patron_exacto, patron_palabra, patron_palabra,
            patron_palabra, patron_palabra, patron_palabra, patron_exacto
        ))

    def _es_cedula_valida(self, termino: str) -> bool:
        """
        Valida si un término tiene formato válido de cédula
        """
        if not termino:
            return False
        
        # Limpiar espacios y caracteres especiales
        cedula_limpia = ''.join(c for c in termino if c.isdigit())
        
        # Debe tener entre 6 y 12 dígitos
        if len(cedula_limpia) < 6 or len(cedula_limpia) > 12:
            return False
        
        return True

    def _normalizar_termino_busqueda(self, termino: str) -> str:
        """
        Normaliza término de búsqueda eliminando caracteres especiales
        """
        if not termino:
            return ""
        
        # Convertir a minúsculas y quitar espacios extra
        normalizado = ' '.join(termino.strip().lower().split())
        
        # Eliminar caracteres especiales comunes
        caracteres_especiales = ['ñ', 'á', 'é', 'í', 'ó', 'ú']
        reemplazos = ['n', 'a', 'e', 'i', 'o', 'u']
        
        for i, char in enumerate(caracteres_especiales):
            normalizado = normalizado.replace(char, reemplazos[i])
        
        return normalizado
    # ===============================
    # VALIDACIONES
    # ===============================
    
    def _patient_exists(self, paciente_id: int) -> bool:
        """Verifica si existe el paciente - CORREGIDO"""
        return self._patient_exists_by_id(paciente_id)
    
    def _worker_exists(self, trabajador_id: int) -> bool:
        """Verifica si existe el trabajador"""
        query = "SELECT COUNT(*) as count FROM Trabajadores WHERE id = ?"
        result = self._execute_query(query, (trabajador_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def validate_lab_exam_exists(self, lab_id: int) -> bool:
        """Valida que el examen existe"""
        return self.exists('id', lab_id)
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_laboratory_caches(self):
        """Invalida cachés relacionados con laboratorio"""
        cache_types = ['laboratorio', 'laboratorio_completo', 'stats_laboratorio']
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_laboratory_caches()