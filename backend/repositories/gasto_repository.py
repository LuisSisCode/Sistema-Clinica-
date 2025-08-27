from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, ExceptionHandler, validate_required
)
from ..core.cache_system import cached_query
from ..core.utils import (
    get_current_datetime, format_date_for_db, get_date_range_query,
    validate_required_string, validate_positive_number, safe_float
)

class GastoRepository(BaseRepository):
    """Repository para gestión de Gastos y Tipos de Gastos"""
    
    def __init__(self):
        super().__init__('Gastos', 'gastos')
        print("💸 GastoRepository inicializado")
    
    # ===============================
    # FUNCIÓN HELPER PARA FECHAS
    # ===============================
    
    def _format_dates_in_results(self, results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Convierte objetos datetime a strings en los resultados para compatibilidad con QML"""
        if not isinstance(results, list):
            return results
            
        for result in results:
            if isinstance(result, dict):
                # Convertir campo 'Fecha' si existe
                if result.get('Fecha') and hasattr(result['Fecha'], 'strftime'):
                    result['Fecha'] = result['Fecha'].strftime('%Y-%m-%d %H:%M:%S')
                
                # Convertir campo 'fecha' si existe
                if result.get('fecha') and hasattr(result['fecha'], 'strftime'):
                    result['fecha'] = result['fecha'].strftime('%Y-%m-%d %H:%M:%S')
                
                # Convertir campos de fecha específicos
                date_fields = ['ultimo_gasto', 'tipo_fecha_creacion', 'fechaGasto']
                for field in date_fields:
                    if result.get(field) and hasattr(result[field], 'strftime'):
                        result[field] = result[field].strftime('%Y-%m-%d %H:%M:%S')
        
        return results
    
    def _format_single_date_result(self, result: Dict[str, Any]) -> Dict[str, Any]:
        """Convierte fechas en un solo resultado"""
        if not result:
            return result
        
        return self._format_dates_in_results([result])[0]
    
    # ===============================
    # IMPLEMENTACIÓN ABSTRACTA
    # ===============================
    
    def get_active(self) -> List[Dict[str, Any]]:
        """Obtiene gastos del mes actual con información completa"""
        return self.get_gastos_del_mes()
    
    # ===============================
    # CRUD ESPECÍFICO
    # ===============================
    
    def create_expense(self, tipo_gasto_id: int, monto: float, usuario_id: int,
                      fecha: datetime = None, descripcion: str = None, proveedor: str = None) -> int:
        """
        Crea nuevo gasto
        
        Args:
            tipo_gasto_id: ID del tipo de gasto
            monto: Monto del gasto
            usuario_id: ID del usuario responsable
            fecha: Fecha del gasto (opcional, por defecto ahora)
            descripcion: Descripción del gasto (opcional)
            proveedor: Proveedor o empresa (opcional)
            
        Returns:
            ID del gasto creado
        """
        # Validaciones
        validate_required(tipo_gasto_id, "tipo_gasto_id")
        validate_required(usuario_id, "usuario_id")
        monto = validate_positive_number(monto, "monto")
        
        # Verificar que existan las entidades relacionadas
        if not self._expense_type_exists(tipo_gasto_id):
            raise ValidationError("tipo_gasto_id", tipo_gasto_id, "Tipo de gasto no encontrado")
        
        if not self._user_exists(usuario_id):
            raise ValidationError("usuario_id", usuario_id, "Usuario no encontrado")
        
        # Usar fecha actual si no se proporciona
        if fecha is None:
            fecha = get_current_datetime()
        
        # Crear gasto con nueva estructura
        gasto_data = {
            'ID_Tipo': tipo_gasto_id,
            'Descripcion': descripcion or "Sin descripción",
            'Monto': monto,
            'Fecha': fecha,
            'Proveedor': proveedor,
            'Id_RegistradoPor': usuario_id
        }
        
        gasto_id = self.insert(gasto_data)
        if not gasto_id:
            raise ValidationError("gasto", "creacion", "Error creando gasto")
        
        print(f"💸 Gasto creado: Tipo ID {tipo_gasto_id}, Monto ${monto} - ID: {gasto_id}")
        
        return gasto_id
    
    def update_expense(self, gasto_id: int, monto: float = None, tipo_gasto_id: int = None,
                      fecha: datetime = None, descripcion: str = None, proveedor: str = None) -> bool:
        """Actualiza gasto existente"""
        # Verificar existencia
        if not self.get_by_id(gasto_id):
            raise ValidationError("gasto_id", gasto_id, "Gasto no encontrado")
        
        update_data = {}
        
        if monto is not None:
            monto = validate_positive_number(monto, "monto")
            update_data['Monto'] = monto
        
        if tipo_gasto_id is not None:
            if not self._expense_type_exists(tipo_gasto_id):
                raise ValidationError("tipo_gasto_id", tipo_gasto_id, "Tipo de gasto no encontrado")
            update_data['ID_Tipo'] = tipo_gasto_id
        
        if fecha is not None:
            update_data['Fecha'] = fecha
            
        if descripcion is not None:
            update_data['Descripcion'] = descripcion.strip()
            
        if proveedor is not None:
            update_data['Proveedor'] = proveedor.strip() if proveedor else None
        
        if not update_data:
            return True
        
        success = self.update(gasto_id, update_data)
        if success:
            print(f"💸 Gasto actualizado: ID {gasto_id}")
        
        return success
    
    # ===============================
    # CONSULTAS CON RELACIONES
    # ===============================
    
    @cached_query('gastos_completos', ttl=300)
    def get_all_with_details(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Obtiene gastos con información completa"""
        query = """
        SELECT g.id, g.Monto, g.Fecha, g.Descripcion, g.Proveedor,
               -- Tipo de gasto
               tg.id as tipo_id, tg.Nombre as tipo_nombre, tg.fecha as tipo_fecha_creacion,
               -- Usuario responsable
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno, ' ', u.Apellido_Materno) as usuario_completo,
               u.correo as usuario_email, u.id as usuario_id,
               u.Nombre as registrado_por_nombre
        FROM Gastos g
        INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
        ORDER BY g.Fecha DESC
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        result = self._execute_query(query, (limit,))
        return self._format_dates_in_results(result)
    
    def get_expense_by_id_complete(self, gasto_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene gasto específico con información completa"""
        query = """
        SELECT g.id, g.Monto, g.Fecha, g.Descripcion, g.Proveedor,
               -- Tipo de gasto
               tg.id as tipo_id, tg.Nombre as tipo_nombre, tg.fecha as tipo_fecha_creacion,
               -- Usuario responsable
               u.id as usuario_id,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno, ' ', u.Apellido_Materno) as usuario_completo,
               u.Nombre as usuario_nombre, u.Apellido_Paterno as usuario_apellido_p,
               u.Apellido_Materno as usuario_apellido_m, u.correo as usuario_email,
               u.Nombre as registrado_por_nombre
        FROM Gastos g
        INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
        WHERE g.id = ?
        """
        result = self._execute_query(query, (gasto_id,), fetch_one=True)
        return self._format_single_date_result(result) if result else None
    
    # ===============================
    # BÚSQUEDAS POR FECHAS
    # ===============================
    
    def get_expenses_by_date_range(self, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
        """Obtiene gastos en rango de fechas"""
        query = """
        SELECT g.id, g.Monto, g.Fecha, g.Descripcion, g.Proveedor,
            -- Tipo de gasto
            tg.id as tipo_id, tg.Nombre as tipo_nombre,
            -- Usuario responsable  
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno, ' ', u.Apellido_Materno) as usuario_completo,
            CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as registrado_por_nombre
        FROM Gastos g
        INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
        WHERE g.Fecha BETWEEN ? AND ?
        ORDER BY g.Fecha DESC
        """
        result = self._execute_query(query, (start_date, end_date))
        return self._format_dates_in_results(result)
    
    def get_gastos_del_mes(self, año: int = None, mes: int = None) -> List[Dict[str, Any]]:
        """Obtiene gastos del mes específico"""
        if not año:
            año = datetime.now().year
        if not mes:
            mes = datetime.now().month
        
        query = """
        SELECT g.*, tg.Nombre as tipo_nombre,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_nombre
        FROM Gastos g
        INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
        WHERE YEAR(g.Fecha) = ? AND MONTH(g.Fecha) = ?
        ORDER BY g.Fecha DESC
        """
        result = self._execute_query(query, (año, mes))
        return self._format_dates_in_results(result)
    
    @cached_query('gastos_hoy', ttl=60)
    def get_today_expenses(self) -> List[Dict[str, Any]]:
        """Obtiene gastos del día actual"""
        today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        tomorrow = today + timedelta(days=1)
        
        result = self.get_expenses_by_date_range(today, tomorrow)
        return self._format_dates_in_results(result)
    
    def get_recent_expenses(self, days: int = 7) -> List[Dict[str, Any]]:
        """Obtiene gastos recientes"""
        end_date = get_current_datetime()
        start_date = end_date - timedelta(days=days)
        
        result = self.get_expenses_by_date_range(start_date, end_date)
        return self._format_dates_in_results(result)
    
    # ===============================
    # BÚSQUEDAS POR ENTIDADES
    # ===============================
    
    def get_expenses_by_type(self, tipo_gasto_id: int, limit: int = 50) -> List[Dict[str, Any]]:
        """Obtiene gastos por tipo específico"""
        query = """
        SELECT g.*, tg.Nombre as tipo_nombre,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_nombre
        FROM Gastos g
        INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
        WHERE g.ID_Tipo = ?
        ORDER BY g.Fecha DESC
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        result = self._execute_query(query, (tipo_gasto_id, limit))
        return self._format_dates_in_results(result)
    
    def get_expenses_by_user(self, usuario_id: int, limit: int = 50) -> List[Dict[str, Any]]:
        """Obtiene gastos registrados por un usuario"""
        query = """
        SELECT g.*, tg.Nombre as tipo_nombre
        FROM Gastos g
        INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        WHERE g.Id_RegistradoPor = ?
        ORDER BY g.Fecha DESC
        OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """
        result = self._execute_query(query, (usuario_id, limit))
        return self._format_dates_in_results(result)
    
    def get_expenses_by_amount_range(self, min_amount: float, max_amount: float) -> List[Dict[str, Any]]:
        """Obtiene gastos por rango de monto"""
        query = """
        SELECT g.*, tg.Nombre as tipo_nombre,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_nombre
        FROM Gastos g
        INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
        WHERE g.Monto BETWEEN ? AND ?
        ORDER BY g.Monto DESC, g.Fecha DESC
        """
        result = self._execute_query(query, (min_amount, max_amount))
        return self._format_dates_in_results(result)
    
    # ===============================
    # GESTIÓN DE TIPOS DE GASTOS
    # ===============================
    
    @cached_query('tipos_gastos', ttl=1800)
    def get_all_expense_types(self) -> List[Dict[str, Any]]:
        """Obtiene todos los tipos de gastos con estadísticas"""
        query = """
        SELECT tg.*, 
               COUNT(g.id) as total_gastos,
               COALESCE(SUM(g.Monto), 0) as monto_total,
               COALESCE(AVG(g.Monto), 0) as monto_promedio
        FROM Tipo_Gastos tg
        LEFT JOIN Gastos g ON tg.id = g.ID_Tipo
        GROUP BY tg.id, tg.Nombre, tg.fecha
        ORDER BY total_gastos DESC, tg.Nombre
        """
        result = self._execute_query(query)
        return self._format_dates_in_results(result)
    
    def get_expense_type_by_id(self, tipo_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de gasto por ID con estadísticas"""
        query = """
        SELECT tg.*, 
               COUNT(g.id) as total_gastos,
               COALESCE(SUM(g.Monto), 0) as monto_total,
               COALESCE(AVG(g.Monto), 0) as monto_promedio,
               MAX(g.Fecha) as ultimo_gasto
        FROM Tipo_Gastos tg
        LEFT JOIN Gastos g ON tg.id = g.ID_Tipo
        WHERE tg.id = ?
        GROUP BY tg.id, tg.Nombre, tg.fecha
        """
        result = self._execute_query(query, (tipo_id,), fetch_one=True)
        return self._format_single_date_result(result) if result else None
    
    def get_expense_type_by_name(self, nombre: str) -> Optional[Dict[str, Any]]:
        """Obtiene tipo de gasto por nombre"""
        query = "SELECT * FROM Tipo_Gastos WHERE Nombre = ?"
        result = self._execute_query(query, (nombre.strip(),), fetch_one=True)
        return self._format_single_date_result(result) if result else None
    
    def create_expense_type(self, nombre: str) -> int:
        """
        Crea nuevo tipo de gasto
        
        Args:
            nombre: Nombre del tipo de gasto
            
        Returns:
            ID del tipo creado
        """
        nombre = validate_required_string(nombre, "nombre", 3)
        
        # Verificar que no existe
        if self.expense_type_name_exists(nombre):
            raise ValidationError("nombre", nombre, "Tipo de gasto ya existe")
        
        query = """
        INSERT INTO Tipo_Gastos (Nombre, fecha)
        OUTPUT INSERTED.id
        VALUES (?, GETDATE())
        """
        
        result = self._execute_query(query, (nombre.strip(),), fetch_one=True)
        tipo_id = result['id'] if result else None
        
        if tipo_id:
            print(f"💸 Tipo de gasto creado: {nombre} - ID: {tipo_id}")
        
        return tipo_id
    
    def update_expense_type(self, tipo_id: int, nombre: str) -> bool:
        """Actualiza tipo de gasto"""
        nombre = validate_required_string(nombre, "nombre", 3)
        
        # Verificar existencia
        existing_type = self.get_expense_type_by_id(tipo_id)
        if not existing_type:
            raise ValidationError("tipo_id", tipo_id, "Tipo de gasto no encontrado")
        
        # Verificar nombre único (excepto el mismo)
        if nombre != existing_type['Nombre'] and self.expense_type_name_exists(nombre):
            raise ValidationError("nombre", nombre, "Tipo de gasto ya existe")
        
        query = "UPDATE Tipo_Gastos SET Nombre = ? WHERE id = ?"
        affected_rows = self._execute_query(query, (nombre.strip(), tipo_id), 
                                          fetch_all=False, use_cache=False)
        
        success = affected_rows > 0
        if success:
            print(f"💸 Tipo de gasto actualizado: ID {tipo_id}")
        
        return success
    
    def delete_expense_type(self, tipo_id: int) -> bool:
        """Elimina tipo de gasto si no tiene gastos asociados"""
        # Verificar que no tenga gastos
        gastos_count = self.count("ID_Tipo = ?", (tipo_id,))
        if gastos_count > 0:
            raise ValidationError("tipo_id", tipo_id,
                                f"No se puede eliminar tipo con {gastos_count} gastos asociados")
        
        query = "DELETE FROM Tipo_Gastos WHERE id = ?"
        affected_rows = self._execute_query(query, (tipo_id,), fetch_all=False, use_cache=False)
        
        success = affected_rows > 0
        if success:
            print(f"🗑️ Tipo de gasto eliminado: ID {tipo_id}")
        
        return success
    
    def expense_type_name_exists(self, nombre: str) -> bool:
        """Verifica si existe un nombre de tipo"""
        query = "SELECT COUNT(*) as count FROM Tipo_Gastos WHERE Nombre = ?"
        result = self._execute_query(query, (nombre.strip(),), fetch_one=True)
        return result['count'] > 0 if result else False
    
    # ===============================
    # BÚSQUEDAS AVANZADAS
    # ===============================
    
    def search_expenses(self, search_term: str, start_date: datetime = None,
                       end_date: datetime = None, limit: int = 50) -> List[Dict[str, Any]]:
        """Búsqueda avanzada en gastos"""
        if not search_term:
            if start_date and end_date:
                return self.get_expenses_by_date_range(start_date, end_date)
            return []
        
        search_term = f"%{search_term.strip()}%"
        
        base_query = """
        SELECT g.*, tg.Nombre as tipo_nombre,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno, ' ', u.Apellido_Materno) as usuario_completo
        FROM Gastos g
        INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
        WHERE (tg.Nombre LIKE ? OR u.Nombre LIKE ? OR u.Apellido_Paterno LIKE ? 
               OR u.Apellido_Materno LIKE ? OR g.Descripcion LIKE ? OR g.Proveedor LIKE ?)
        """
        
        params = [search_term] * 6
        
        # Agregar filtros de fecha si se proporcionan
        if start_date and end_date:
            base_query += " AND g.Fecha BETWEEN ? AND ?"
            params.extend([start_date, end_date])
        
        base_query += " ORDER BY g.Fecha DESC OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY"
        params.append(limit)
        
        result = self._execute_query(base_query, tuple(params))
        return self._format_dates_in_results(result)
    
    def get_high_expenses(self, min_amount: float = 1000.0, days: int = 30) -> List[Dict[str, Any]]:
        """Obtiene gastos altos en período específico"""
        start_date = datetime.now() - timedelta(days=days)
        
        query = """
        SELECT g.*, tg.Nombre as tipo_nombre,
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_nombre
        FROM Gastos g
        INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
        WHERE g.Monto >= ? AND g.Fecha >= ?
        ORDER BY g.Monto DESC, g.Fecha DESC
        """
        result = self._execute_query(query, (min_amount, start_date))
        return self._format_dates_in_results(result)
    
    # ===============================
    # ESTADÍSTICAS Y REPORTES
    # ===============================
    
    @cached_query('stats_gastos', ttl=300)
    def get_expense_statistics(self) -> Dict[str, Any]:
        """Estadísticas completas de gastos"""
        # Estadísticas generales
        general_query = """
        SELECT 
            COUNT(*) as total_gastos,
            SUM(Monto) as gastos_total,
            AVG(Monto) as gasto_promedio,
            MIN(Monto) as gasto_minimo,
            MAX(Monto) as gasto_maximo,
            COUNT(DISTINCT ID_Tipo) as tipos_utilizados
        FROM Gastos
        """
        
        # Por tipo de gasto
        by_type_query = """
        SELECT tg.Nombre as tipo_gasto,
               COUNT(g.id) as cantidad_gastos,
               SUM(g.Monto) as total_monto,
               AVG(g.Monto) as promedio_monto,
               ROUND(SUM(g.Monto) * 100.0 / (SELECT SUM(Monto) FROM Gastos), 2) as porcentaje_total
        FROM Tipo_Gastos tg
        INNER JOIN Gastos g ON tg.id = g.ID_Tipo
        GROUP BY tg.id, tg.Nombre
        ORDER BY total_monto DESC
        """
        
        # Por usuario
        by_user_query = """
        SELECT CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario,
               COUNT(g.id) as gastos_registrados,
               SUM(g.Monto) as monto_total,
               AVG(g.Monto) as gasto_promedio
        FROM Gastos g
        INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
        GROUP BY u.id, u.Nombre, u.Apellido_Paterno
        ORDER BY monto_total DESC
        """
        
        # Por mes (últimos 12 meses)
        monthly_query = """
        SELECT 
            FORMAT(Fecha, 'yyyy-MM') as mes,
            COUNT(*) as cantidad_gastos,
            SUM(Monto) as total_mes
        FROM Gastos
        WHERE Fecha >= DATEADD(month, -12, GETDATE())
        GROUP BY FORMAT(Fecha, 'yyyy-MM')
        ORDER BY mes DESC
        """
        
        general_stats = self._execute_query(general_query, fetch_one=True)
        by_type_stats = self._execute_query(by_type_query)
        by_user_stats = self._execute_query(by_user_query)
        monthly_stats = self._execute_query(monthly_query)
        
        return {
            'general': general_stats,
            'por_tipo': by_type_stats,
            'por_usuario': by_user_stats,
            'por_mes': monthly_stats
        }
    
    @cached_query('gastos_today_stats', ttl=60)
    def get_today_statistics(self) -> Dict[str, Any]:
        """Estadísticas del día actual"""
        today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        today_end = today_start + timedelta(days=1)
        
        query = """
        SELECT 
            COUNT(*) as gastos_hoy,
            COALESCE(SUM(Monto), 0) as total_gastos_hoy,
            COUNT(DISTINCT ID_Tipo) as tipos_gastados_hoy,
            COUNT(DISTINCT Id_RegistradoPor) as usuarios_activos_hoy
        FROM Gastos g
        WHERE g.Fecha BETWEEN ? AND ?
        """
        
        return self._execute_query(query, (today_start, today_end), fetch_one=True)
    
    def get_expense_trends(self, months: int = 6) -> List[Dict[str, Any]]:
        """Obtiene tendencias de gastos por mes"""
        query = """
        SELECT 
            FORMAT(g.Fecha, 'yyyy-MM') as mes,
            FORMAT(g.Fecha, 'MMMM yyyy', 'es-ES') as mes_nombre,
            COUNT(*) as total_gastos,
            SUM(g.Monto) as monto_total,
            AVG(g.Monto) as gasto_promedio,
            COUNT(DISTINCT g.ID_Tipo) as tipos_diferentes
        FROM Gastos g
        WHERE g.Fecha >= DATEADD(month, -?, GETDATE())
        GROUP BY FORMAT(g.Fecha, 'yyyy-MM'), FORMAT(g.Fecha, 'MMMM yyyy', 'es-ES')
        ORDER BY mes DESC
        """
        result = self._execute_query(query, (months,))
        return self._format_dates_in_results(result)
    
    def get_budget_analysis(self, budget_limits: Dict[str, float] = None) -> Dict[str, Any]:
        """Análisis de presupuesto por tipo de gasto"""
        if not budget_limits:
            budget_limits = {}
        
        # Gastos del mes actual por tipo
        current_month = datetime.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        
        query = """
        SELECT tg.Nombre as tipo_gasto,
               SUM(g.Monto) as gasto_actual,
               COUNT(g.id) as cantidad_gastos
        FROM Tipo_Gastos tg
        LEFT JOIN Gastos g ON tg.id = g.ID_Tipo AND g.Fecha >= ?
        GROUP BY tg.id, tg.Nombre
        ORDER BY gasto_actual DESC
        """
        
        gastos_actuales = self._execute_query(query, (current_month,))
        
        # Agregar información de presupuesto
        for gasto in gastos_actuales:
            tipo = gasto['tipo_gasto']
            actual = gasto['gasto_actual'] or 0
            presupuesto = budget_limits.get(tipo, 0)
            
            gasto['presupuesto'] = presupuesto
            gasto['diferencia'] = presupuesto - actual
            gasto['porcentaje_usado'] = (actual / presupuesto * 100) if presupuesto > 0 else 0
            gasto['estado'] = self._get_budget_status(actual, presupuesto)
        
        total_gastado = sum(g['gasto_actual'] or 0 for g in gastos_actuales)
        total_presupuesto = sum(budget_limits.values())
        
        return {
            'mes_actual': current_month.strftime('%Y-%m'),
            'total_gastado': total_gastado,
            'total_presupuesto': total_presupuesto,
            'diferencia_total': total_presupuesto - total_gastado,
            'porcentaje_total_usado': (total_gastado / total_presupuesto * 100) if total_presupuesto > 0 else 0,
            'gastos_por_tipo': gastos_actuales
        }
    
    def _get_budget_status(self, actual: float, presupuesto: float) -> str:
        """Determina estado del presupuesto"""
        if presupuesto <= 0:
            return "SIN_PRESUPUESTO"
        
        porcentaje = (actual / presupuesto) * 100
        
        if porcentaje >= 100:
            return "EXCEDIDO"
        elif porcentaje >= 80:
            return "ALERTA"
        elif porcentaje >= 50:
            return "MODERADO"
        else:
            return "NORMAL"
    
    # ===============================
    # UTILIDADES Y VALIDACIONES
    # ===============================
    
    def _expense_type_exists(self, tipo_id: int) -> bool:
        """Verifica si existe el tipo de gasto"""
        query = "SELECT COUNT(*) as count FROM Tipo_Gastos WHERE id = ?"
        result = self._execute_query(query, (tipo_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def _user_exists(self, usuario_id: int) -> bool:
        """Verifica si existe el usuario"""
        query = "SELECT COUNT(*) as count FROM Usuario WHERE id = ? AND Estado = 1"
        result = self._execute_query(query, (usuario_id,), fetch_one=True)
        return result['count'] > 0 if result else False
    
    def validate_expense_exists(self, gasto_id: int) -> bool:
        """Valida que el gasto existe"""
        return self.exists('id', gasto_id)
    
    def get_expense_user(self, gasto_id: int) -> Optional[Dict[str, Any]]:
        """Obtiene usuario responsable del gasto"""
        query = """
        SELECT u.*
        FROM Usuario u
        INNER JOIN Gastos g ON u.id = g.Id_RegistradoPor
        WHERE g.id = ?
        """
        result = self._execute_query(query, (gasto_id,), fetch_one=True)
        return self._format_single_date_result(result) if result else None
    
    def get_available_expense_types(self) -> List[str]:
        """Obtiene lista de tipos de gastos disponibles"""
        query = "SELECT Nombre FROM Tipo_Gastos ORDER BY Nombre"
        result = self._execute_query(query)
        return [row['Nombre'] for row in result]
    
    # ===============================
    # REPORTES
    # ===============================
    
    def get_expenses_for_report(self, start_date: datetime = None, end_date: datetime = None,
                               tipo_id: int = None, usuario_id: int = None) -> List[Dict[str, Any]]:
        """Obtiene gastos formateados para reportes"""
        base_query = """
        SELECT g.id, g.Monto, g.Fecha, g.Descripcion, g.Proveedor,
               -- Tipo
               tg.Nombre as tipo_nombre,
               -- Usuario
               CONCAT(u.Nombre, ' ', u.Apellido_Paterno, ' ', u.Apellido_Materno) as usuario_completo
        FROM Gastos g
        INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
        INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
        """
        
        conditions = []
        params = []
        
        if start_date and end_date:
            conditions.append("g.Fecha BETWEEN ? AND ?")
            params.extend([start_date, end_date])
        
        if tipo_id:
            conditions.append("g.ID_Tipo = ?")
            params.append(tipo_id)
        
        if usuario_id:
            conditions.append("g.Id_RegistradoPor = ?")
            params.append(usuario_id)
        
        if conditions:
            base_query += " WHERE " + " AND ".join(conditions)
        
        base_query += " ORDER BY g.Fecha DESC"
        
        expenses = self._execute_query(base_query, tuple(params))
        expenses = self._format_dates_in_results(expenses)
        
        # Agregar información adicional para reporte
        for expense in expenses:
            try:
                # Convertir string de fecha de vuelta a datetime para formateo
                if isinstance(expense['Fecha'], str):
                    fecha_obj = datetime.strptime(expense['Fecha'], '%Y-%m-%d %H:%M:%S')
                    expense['fecha_formato'] = fecha_obj.strftime('%d/%m/%Y')
                else:
                    expense['fecha_formato'] = expense['Fecha'].strftime('%d/%m/%Y')
                    
                expense['monto_formato'] = f"${expense['Monto']:,.2f}"
            except Exception as e:
                print(f"Error formateando datos para reporte: {e}")
                expense['fecha_formato'] = "N/A"
                expense['monto_formato'] = f"${expense['Monto']:,.2f}"
        
        return expenses
    
    # ===============================
    # PAGINACIÓN - MÉTODO CORREGIDO
    # ===============================
    
    def get_paginated_expenses(self, offset: int, limit: int, filters: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """Obtiene gastos paginados con filtros - CORREGIDO PARA QML"""
        try:
            # Validar parámetros
            if offset < 0:
                offset = 0
            if limit <= 0 or limit > 100:
                limit = 10
                
            # Construir consulta con filtros
            query = """
            SELECT g.id, g.Monto, g.Fecha, g.Descripcion, g.Proveedor,
                tg.Nombre as tipo_nombre,
                CONCAT(u.Nombre, ' ', u.Apellido_Paterno) as usuario_nombre
            FROM Gastos g
            INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
            INNER JOIN Usuario u ON g.Id_RegistradoPor = u.id
            """
            
            conditions = []
            params = []
            
            if filters:
                if filters.get('mes') and filters.get('año'):
                    conditions.append("MONTH(g.Fecha) = ? AND YEAR(g.Fecha) = ?")
                    params.append(filters['mes'])
                    params.append(filters['año'])
                    
                if filters.get('tipo_id') and filters['tipo_id'] > 0:
                    conditions.append("g.ID_Tipo = ?")
                    params.append(filters['tipo_id'])
            
            if conditions:
                query += " WHERE " + " AND ".join(conditions)
                
            query += " ORDER BY g.Fecha DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY"
            params.extend([offset, limit])
            
            result = self._execute_query(query, tuple(params))
            
            # CONVERSIÓN ESPECÍFICA PARA QML
            for gasto in result:
                if gasto.get('Fecha') and hasattr(gasto['Fecha'], 'strftime'):
                    # Convertir a formato de solo fecha para QML
                    gasto['Fecha'] = gasto['Fecha'].strftime('%Y-%m-%d')
            
            return result
            
        except Exception as e:
            print(f"❌ Error en get_paginated_expenses: {e}")
            raise e

    def get_expenses_count(self, filters: Dict[str, Any] = None) -> int:
        """Cuenta total de gastos con filtros"""
        query = "SELECT COUNT(*) as total FROM Gastos g"
        params = []
        
        if filters:
            where_conditions = []
            if filters.get('tipo_id'):
                where_conditions.append("g.ID_Tipo = ?")
                params.append(filters['tipo_id'])
            if filters.get('mes'):
                where_conditions.append("MONTH(g.Fecha) = ?")
                params.append(filters['mes'])
            if filters.get('año'):
                where_conditions.append("YEAR(g.Fecha) = ?")
                params.append(filters['año'])
            
            if where_conditions:
                query += " WHERE " + " AND ".join(where_conditions)
        
        result = self._execute_query(query, tuple(params), fetch_one=True)
        return result['total'] if result else 0
    
    # ===============================
    # CACHÉ
    # ===============================
    
    def invalidate_expense_caches(self):
        """Invalida cachés relacionados con gastos"""
        cache_types = ['gastos', 'gastos_completos', 'gastos_hoy', 'stats_gastos', 
                      'gastos_today_stats', 'tipos_gastos']
        from ..core.cache_system import invalidate_after_update
        invalidate_after_update(cache_types)
    
    def _invalidate_cache_after_modification(self):
        """Override para invalidación específica"""
        super()._invalidate_cache_after_modification()
        self.invalidate_expense_caches()