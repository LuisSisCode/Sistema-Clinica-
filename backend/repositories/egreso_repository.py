"""
egreso_repository.py
Repository para gestión completa de egresos (gastos) de la clínica
"""

from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, date
from decimal import Decimal
import pyodbc

from ..core.base_repository import BaseRepository
from ..core.excepciones import (
    ValidationError, DatabaseError, ExceptionHandler,
    validate_required, validate_positive_number
)


class EgresoRepository(BaseRepository):
    """
    Repository para operaciones CRUD de Egresos
    
    Funcionalidades:
    - Registrar gastos con validación
    - Consultar gastos por fecha/tipo
    - Anular gastos (soft delete)
    - Reportes y estadísticas
    """
    
    def __init__(self):
        super().__init__('Egresos', 'egresos')
        print("💸 EgresoRepository inicializado")
    
    # ===============================
    # OPERACIONES CRUD
    # ===============================
    
    def crear_egreso(self, 
                    id_tipo_gasto: int,
                    monto: float,
                    descripcion: str,
                    id_usuario: int,
                    comprobante: str = None,
                    proveedor: str = None,
                    metodo_pago: str = None,
                    observaciones: str = None,
                    fecha: datetime = None) -> Tuple[bool, str, Optional[int]]:
        """
        Registra un nuevo egreso en el sistema
        
        Args:
            id_tipo_gasto: ID del tipo de gasto
            monto: Monto del gasto (debe ser > 0)
            descripcion: Descripción del gasto
            id_usuario: ID del usuario que registra
            comprobante: Número de factura/recibo (opcional)
            proveedor: Nombre del proveedor (opcional)
            metodo_pago: Método de pago usado (opcional)
            observaciones: Observaciones adicionales (opcional)
            fecha: Fecha del gasto (default: ahora)
            
        Returns:
            Tuple[bool, str, Optional[int]]: (éxito, mensaje, ID del egreso creado)
        """
        try:
            # Validaciones
            validate_required(id_tipo_gasto, "ID de tipo de gasto")
            validate_required(monto, "Monto")
            validate_positive_number(monto, "Monto")
            validate_required(descripcion, "Descripción")
            validate_required(id_usuario, "ID de usuario")
            
            if len(descripcion.strip()) < 5:
                raise ValidationError("La descripción debe tener al menos 5 caracteres")
            
            # Usar fecha actual si no se proporciona
            if fecha is None:
                fecha = datetime.now()
            
            # Preparar query
            query = """
            INSERT INTO Egresos 
                (Id_Tipo_Gasto, Monto, Descripcion, Fecha, Id_Usuario,
                 Comprobante, Proveedor, Metodo_Pago, Observaciones, Estado)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1);
            
            SELECT SCOPE_IDENTITY() as nuevo_id;
            """
            
            params = (
                id_tipo_gasto,
                Decimal(str(monto)),
                descripcion.strip(),
                fecha,
                id_usuario,
                comprobante.strip() if comprobante else None,
                proveedor.strip() if proveedor else None,
                metodo_pago.strip() if metodo_pago else None,
                observaciones.strip() if observaciones else None
            )
            
            # Ejecutar
            resultado = self._execute_query(query, params, use_cache=False)
            
            if resultado and len(resultado) > 0:
                egreso_id = int(resultado[0]['nuevo_id'])
                print(f"✅ Egreso creado: ID {egreso_id}, Monto: ${monto}")
                return True, f"Egreso registrado exitosamente (ID: {egreso_id})", egreso_id
            else:
                return False, "Error al obtener ID del egreso creado", None
                
        except ValidationError as e:
            return False, str(e), None
        except Exception as e:
            print(f"❌ Error creando egreso: {e}")
            return False, f"Error al registrar egreso: {str(e)}", None
    
    def anular_egreso(self, 
                     egreso_id: int,
                     motivo: str,
                     usuario_id: int) -> Tuple[bool, str]:
        """
        Anula un egreso (soft delete)
        
        Args:
            egreso_id: ID del egreso a anular
            motivo: Motivo de la anulación
            usuario_id: ID del usuario que anula
            
        Returns:
            Tuple[bool, str]: (éxito, mensaje)
        """
        try:
            validate_required(egreso_id, "ID de egreso")
            validate_required(motivo, "Motivo de anulación")
            validate_required(usuario_id, "ID de usuario")
            
            if len(motivo.strip()) < 10:
                raise ValidationError("El motivo debe tener al menos 10 caracteres")
            
            # Verificar que el egreso existe y está activo
            egreso = self.get_by_id(egreso_id)
            if not egreso:
                return False, f"Egreso con ID {egreso_id} no encontrado"
            
            if not egreso.get('Estado', False):
                return False, "El egreso ya está anulado"
            
            # Anular
            query = """
            UPDATE Egresos 
            SET Estado = 0,
                Fecha_Anulacion = GETDATE(),
                Motivo_Anulacion = ?,
                Usuario_Anulacion = ?
            WHERE id = ? AND Estado = 1;
            """
            
            affected = self._execute_update(query, (motivo.strip(), usuario_id, egreso_id))
            
            if affected > 0:
                print(f"✅ Egreso {egreso_id} anulado por usuario {usuario_id}")
                return True, f"Egreso anulado exitosamente"
            else:
                return False, "No se pudo anular el egreso (ya anulado o no existe)"
                
        except ValidationError as e:
            return False, str(e)
        except Exception as e:
            print(f"❌ Error anulando egreso: {e}")
            return False, f"Error al anular egreso: {str(e)}"
    
    # ===============================
    # CONSULTAS Y BÚSQUEDAS
    # ===============================
    
    def get_egresos_por_fecha(self, 
                              fecha_inicio: date,
                              fecha_fin: date,
                              incluir_anulados: bool = False) -> List[Dict[str, Any]]:
        """
        Obtiene egresos en un rango de fechas
        
        Args:
            fecha_inicio: Fecha inicial
            fecha_fin: Fecha final
            incluir_anulados: Si incluir egresos anulados
            
        Returns:
            Lista de egresos con información completa
        """
        try:
            query = """
            SELECT 
                e.id,
                e.Id_Tipo_Gasto,
                tg.Nombre as Tipo_Gasto_Nombre,
                e.Monto,
                e.Descripcion,
                e.Fecha,
                e.Comprobante,
                e.Proveedor,
                e.Metodo_Pago,
                e.Observaciones,
                e.Estado,
                e.Id_Usuario,
                u.Nombre + ' ' + u.Apellido_Paterno as Usuario_Nombre,
                e.Fecha_Anulacion,
                e.Motivo_Anulacion
            FROM Egresos e
            INNER JOIN Tipo_Gastos tg ON e.Id_Tipo_Gasto = tg.id
            INNER JOIN Usuario u ON e.Id_Usuario = u.id
            WHERE CAST(e.Fecha AS DATE) BETWEEN ? AND ?
            """
            
            if not incluir_anulados:
                query += " AND e.Estado = 1"
            
            query += " ORDER BY e.Fecha DESC"
            
            resultado = self._execute_query(query, (fecha_inicio, fecha_fin), use_cache=False)
            
            print(f"📋 {len(resultado)} egresos encontrados entre {fecha_inicio} y {fecha_fin}")
            return resultado
            
        except Exception as e:
            print(f"❌ Error obteniendo egresos por fecha: {e}")
            return []
    
    def get_resumen_por_tipo(self, 
                            fecha_inicio: date,
                            fecha_fin: date) -> List[Dict[str, Any]]:
        """
        Obtiene resumen de egresos agrupados por tipo
        
        Args:
            fecha_inicio: Fecha inicial
            fecha_fin: Fecha final
            
        Returns:
            Lista con resumen por tipo de gasto
        """
        try:
            query = """
            SELECT 
                tg.id as Id_Tipo_Gasto,
                tg.Nombre as Tipo_Gasto,
                COUNT(e.id) as Cantidad,
                ISNULL(SUM(e.Monto), 0) as Total,
                ISNULL(AVG(e.Monto), 0) as Promedio
            FROM Tipo_Gastos tg
            LEFT JOIN Egresos e ON tg.id = e.Id_Tipo_Gasto 
                AND e.Estado = 1
                AND CAST(e.Fecha AS DATE) BETWEEN ? AND ?
            GROUP BY tg.id, tg.Nombre
            ORDER BY Total DESC
            """
            
            resultado = self._execute_query(query, (fecha_inicio, fecha_fin), use_cache=False)
            
            print(f"📊 Resumen de egresos por tipo calculado")
            return resultado
            
        except Exception as e:
            print(f"❌ Error obteniendo resumen por tipo: {e}")
            return []
    
    def get_total_egresos_dia(self, fecha: date) -> Decimal:
        """
        Obtiene el total de egresos de un día específico
        
        Args:
            fecha: Fecha a consultar
            
        Returns:
            Total de egresos del día
        """
        try:
            query = """
            SELECT ISNULL(SUM(Monto), 0) as Total
            FROM Egresos
            WHERE CAST(Fecha AS DATE) = ? 
            AND Estado = 1
            """
            
            resultado = self._execute_query(query, (fecha,), use_cache=False)
            
            if resultado and len(resultado) > 0:
                total = Decimal(str(resultado[0]['Total']))
                print(f"💰 Total egresos del {fecha}: ${total}")
                return total
            
            return Decimal('0')
            
        except Exception as e:
            print(f"❌ Error calculando total de egresos: {e}")
            return Decimal('0')
    
    def buscar_por_comprobante(self, comprobante: str) -> Optional[Dict[str, Any]]:
        """
        Busca un egreso por número de comprobante
        
        Args:
            comprobante: Número de comprobante a buscar
            
        Returns:
            Egreso encontrado o None
        """
        try:
            query = """
            SELECT 
                e.*,
                tg.Nombre as Tipo_Gasto_Nombre,
                u.Nombre + ' ' + u.Apellido_Paterno as Usuario_Nombre
            FROM Egresos e
            INNER JOIN Tipo_Gastos tg ON e.Id_Tipo_Gasto = tg.id
            INNER JOIN Usuario u ON e.Id_Usuario = u.id
            WHERE e.Comprobante = ?
            """
            
            resultado = self._execute_query(query, (comprobante,), use_cache=False)
            
            if resultado and len(resultado) > 0:
                print(f"✅ Egreso encontrado con comprobante {comprobante}")
                return resultado[0]
            
            return None
            
        except Exception as e:
            print(f"❌ Error buscando por comprobante: {e}")
            return None
    
    # ===============================
    # ESTADÍSTICAS
    # ===============================
    
    def get_estadisticas_mes(self, mes: int, anio: int) -> Dict[str, Any]:
        """
        Obtiene estadísticas de egresos de un mes
        
        Args:
            mes: Número de mes (1-12)
            anio: Año
            
        Returns:
            Diccionario con estadísticas
        """
        try:
            query = """
            SELECT 
                COUNT(*) as Total_Egresos,
                SUM(Monto) as Total_Monto,
                AVG(Monto) as Promedio_Monto,
                MAX(Monto) as Monto_Maximo,
                MIN(Monto) as Monto_Minimo
            FROM Egresos
            WHERE MONTH(Fecha) = ? AND YEAR(Fecha) = ? AND Estado = 1
            """
            
            resultado = self._execute_query(query, (mes, anio), use_cache=False)
            
            if resultado and len(resultado) > 0:
                stats = resultado[0]
                print(f"📊 Estadísticas de egresos {mes}/{anio} calculadas")
                return {
                    'total_egresos': stats['Total_Egresos'] or 0,
                    'total_monto': float(stats['Total_Monto'] or 0),
                    'promedio_monto': float(stats['Promedio_Monto'] or 0),
                    'monto_maximo': float(stats['Monto_Maximo'] or 0),
                    'monto_minimo': float(stats['Monto_Minimo'] or 0),
                    'mes': mes,
                    'anio': anio
                }
            
            return {
                'total_egresos': 0,
                'total_monto': 0.0,
                'promedio_monto': 0.0,
                'monto_maximo': 0.0,
                'monto_minimo': 0.0,
                'mes': mes,
                'anio': anio
            }
            
        except Exception as e:
            print(f"❌ Error calculando estadísticas: {e}")
            return {}


# ===============================
# FUNCIONES DE UTILIDAD
# ===============================

def validar_egreso_datos(datos: Dict[str, Any]) -> Tuple[bool, str]:
    """
    Valida que los datos de un egreso sean correctos
    
    Args:
        datos: Diccionario con datos del egreso
        
    Returns:
        Tuple[bool, str]: (válido, mensaje de error)
    """
    try:
        # Validar campos requeridos
        campos_requeridos = ['id_tipo_gasto', 'monto', 'descripcion', 'id_usuario']
        for campo in campos_requeridos:
            if campo not in datos or not datos[campo]:
                return False, f"Campo requerido faltante: {campo}"
        
        # Validar monto positivo
        if float(datos['monto']) <= 0:
            return False, "El monto debe ser mayor a 0"
        
        # Validar descripción
        if len(datos['descripcion'].strip()) < 5:
            return False, "La descripción debe tener al menos 5 caracteres"
        
        return True, "Datos válidos"
        
    except Exception as e:
        return False, f"Error validando datos: {str(e)}"


if __name__ == "__main__":
    # Testing básico
    print("="*60)
    print("TESTING - EgresoRepository")
    print("="*60)
    
    repo = EgresoRepository()
    
    # Test: Obtener egresos de hoy
    hoy = date.today()
    egresos = repo.get_egresos_por_fecha(hoy, hoy)
    print(f"\n✅ Test 1: {len(egresos)} egresos encontrados hoy")
    
    # Test: Obtener resumen por tipo
    resumen = repo.get_resumen_por_tipo(hoy, hoy)
    print(f"✅ Test 2: Resumen por tipo calculado ({len(resumen)} tipos)")
    
    # Test: Total de egresos del día
    total = repo.get_total_egresos_dia(hoy)
    print(f"✅ Test 3: Total egresos hoy: ${total}")
    
    print("\n" + "="*60)
    print("✅ TESTING COMPLETADO")
    print("="*60)
