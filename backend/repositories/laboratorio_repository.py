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
            print(f"🔍 Obteniendo página {page + 1}, {page_size} elementos por página")
            print(f"🔍 Filtros: búsqueda='{search_term}', tipo='{tipo_analisis}', servicio='{tipo_servicio}'")
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
            
            print(f"🔬 Exámenes paginados: página {page + 1}, {len(examenes_procesados)} registros de {total_records}")
            
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
            print(f"📊 Total exámenes con filtros: {count}")
            return count
            
        except Exception as e:
            print(f"❌ Error contando exámenes: {e}")
            return 0
    
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
        """Busca paciente por cédula o crea uno nuevo si no existe - CORREGIDO"""
        try:
            nombre = nombre.strip()
            apellido_paterno = apellido_paterno.strip()
            apellido_materno = apellido_materno.strip()
            cedula_clean = cedula.strip() if cedula else ""
            
            # Validaciones básicas
            if not nombre or len(nombre) < 2:
                raise ValidationError("nombre", nombre, "Nombre es obligatorio (mínimo 2 caracteres)")
            if not apellido_paterno or len(apellido_paterno) < 2:
                raise ValidationError("apellido_paterno", apellido_paterno, "Apellido paterno es obligatorio")
            if not cedula_clean or len(cedula_clean) < 5:
                raise ValidationError("cedula", cedula_clean, "Cédula es obligatoria (mínimo 5 dígitos)")
            
            # 1. Buscar por cédula exacta primero
            existing_patient = self.search_patient_by_cedula_exact(cedula_clean)
            if existing_patient:
                print(f"👤 Paciente existente encontrado: {existing_patient['nombre_completo']}")
                return existing_patient['id']
            
            # 2. Crear nuevo paciente - CORREGIDO: Insertar directamente en tabla Pacientes
            print(f"🆕 Creando nuevo paciente: {nombre} {apellido_paterno} - Cédula: {cedula_clean}")
            
            # Query corregida - insertar en tabla Pacientes, no Laboratorio
            insert_query = """
            INSERT INTO Pacientes (Nombre, Apellido_Paterno, Apellido_Materno, Cedula) 
            OUTPUT INSERTED.id
            VALUES (?, ?, ?, ?)
            """
            
            params = (nombre, apellido_paterno, apellido_materno, cedula_clean)
            
            # Ejecutar query directamente para tabla Pacientes
            result = self._execute_query(insert_query, params, fetch_one=True)
            
            if result and 'id' in result:
                patient_id = result['id']
                print(f"👤 Nuevo paciente creado exitosamente - ID: {patient_id}")
                return patient_id
            else:
                raise ValidationError("paciente", "No se pudo obtener ID", "Error en creación de paciente")
                
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
        SELECT l.id, l.Nombre, l.Detalles, l.tipo, l.Fecha,
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
        """Obtiene trabajadores disponibles para laboratorio"""
        query = """
        SELECT t.id, 
               t.Nombre, t.Apellido_Paterno, t.Apellido_Materno,
               CONCAT(t.Nombre, ' ', t.Apellido_Paterno, ' ', t.Apellido_Materno) as nombre_completo,
               tt.Tipo as tipo_trabajador,
               COUNT(l.id) as examenes_asignados
        FROM Trabajadores t
        INNER JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id
        LEFT JOIN Laboratorio l ON t.id = l.Id_Trabajador
        WHERE tt.Tipo LIKE '%Laboratorio%' OR tt.Tipo LIKE '%Técnico%' OR tt.Tipo LIKE '%Lab%'
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