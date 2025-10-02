import pyodbc
from typing import List, Optional
from datetime import datetime
from decimal import Decimal
from models.ingreso_extra_model import IngresoExtra


class IngresoExtraRepository:
    """
    Repositorio para gestionar operaciones CRUD de Ingresos Extras
    """
    
    def __init__(self, connection_string: str):
        """
        Inicializa el repositorio con la cadena de conexión
        Args:
            connection_string: Cadena de conexión a SQL Server
        """
        self.connection_string = connection_string
    
    def _get_connection(self):
        """Obtiene una conexión a la base de datos"""
        return pyodbc.connect(self.connection_string)
    
    def obtener_todos(self) -> List[IngresoExtra]:
        """
        Obtiene todos los ingresos extras con informaciÃ³n del usuario registrador
        Returns: Lista de objetos IngresoExtra
        """
        query = """
            SELECT 
                ie.id,
                ie.Descripcion,
                ie.Monto,
                ie.Fecha,
                ie.Id_RegistradoPor,
                CONCAT(u.Nombre, ' ', u.Apellido_Paterno, ' ', u.Apellido_Materno) as NombreCompleto
            FROM [ClinicaMariaInmaculada].[dbo].[IngresosExtras] ie
            LEFT JOIN [ClinicaMariaInmaculada].[dbo].[Usuario] u 
                ON ie.Id_RegistradoPor = u.id
            ORDER BY ie.Fecha DESC, ie.id DESC
        """
        
        ingresos = []
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query)
                
                for row in cursor.fetchall():
                    ingreso = IngresoExtra(
                        id=row.id,
                        descripcion=row.Descripcion,
                        monto=Decimal(str(row.Monto)),
                        fecha=row.Fecha,
                        id_registrado_por=row.Id_RegistradoPor,
                        nombre_registrado_por=row.NombreCompleto
                    )
                    ingresos.append(ingreso)
        except Exception as e:
            print(f"Error al obtener ingresos extras: {e}")
            raise
        
        return ingresos
    
    def obtener_por_id(self, id: int) -> Optional[IngresoExtra]:
        """
        Obtiene un ingreso extra por su ID
        Args:
            id: ID del ingreso extra
        Returns: Objeto IngresoExtra o None si no existe
        """
        query = """
            SELECT 
                ie.id,
                ie.Descripcion,
                ie.Monto,
                ie.Fecha,
                ie.Id_RegistradoPor,
                CONCAT(u.Nombre, ' ', u.Apellido_Paterno, ' ', u.Apellido_Materno) as NombreCompleto
            FROM [ClinicaMariaInmaculada].[dbo].[IngresosExtras] ie
            LEFT JOIN [ClinicaMariaInmaculada].[dbo].[Usuario] u 
                ON ie.Id_RegistradoPor = u.id
            WHERE ie.id = ?
        """
        
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, (id,))
                row = cursor.fetchone()
                
                if row:
                    return IngresoExtra(
                        id=row.id,
                        descripcion=row.Descripcion,
                        monto=Decimal(str(row.Monto)),
                        fecha=row.Fecha,
                        id_registrado_por=row.Id_RegistradoPor,
                        nombre_registrado_por=row.NombreCompleto
                    )
        except Exception as e:
            print(f"Error al obtener ingreso extra por ID: {e}")
            raise
        
        return None
    
    def insertar(self, ingreso: IngresoExtra) -> int:
        """
        Inserta un nuevo ingreso extra
        Args:
            ingreso: Objeto IngresoExtra a insertar
        Returns: ID del ingreso insertado
        """
        # Validar antes de insertar
        es_valido, mensaje = ingreso.validate()
        if not es_valido:
            raise ValueError(mensaje)
        
        query = """
            INSERT INTO [ClinicaMariaInmaculada].[dbo].[IngresosExtras]
            (Descripcion, Monto, Fecha, Id_RegistradoPor)
            VALUES (?, ?, ?, ?);
            SELECT SCOPE_IDENTITY();
        """
        
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, (
                    ingreso.descripcion,
                    float(ingreso.monto),
                    ingreso.fecha,
                    ingreso.id_registrado_por
                ))
                
                # Obtener el ID generado
                nuevo_id = cursor.fetchone()[0]
                conn.commit()
                return int(nuevo_id)
        except Exception as e:
            print(f"Error al insertar ingreso extra: {e}")
            raise
    
    def actualizar(self, ingreso: IngresoExtra) -> bool:
        """
        Actualiza un ingreso extra existente
        Args:
            ingreso: Objeto IngresoExtra con los datos actualizados
        Returns: True si se actualizÃ³ correctamente
        """
        if not ingreso.id:
            raise ValueError("El ID del ingreso es requerido para actualizar")
        
        # Validar antes de actualizar
        es_valido, mensaje = ingreso.validate()
        if not es_valido:
            raise ValueError(mensaje)
        
        query = """
            UPDATE [ClinicaMariaInmaculada].[dbo].[IngresosExtras]
            SET Descripcion = ?,
                Monto = ?,
                Fecha = ?,
                Id_RegistradoPor = ?
            WHERE id = ?
        """
        
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, (
                    ingreso.descripcion,
                    float(ingreso.monto),
                    ingreso.fecha,
                    ingreso.id_registrado_por,
                    ingreso.id
                ))
                conn.commit()
                return cursor.rowcount > 0
        except Exception as e:
            print(f"Error al actualizar ingreso extra: {e}")
            raise
    
    def eliminar(self, id: int) -> bool:
        """
        Elimina un ingreso extra por su ID
        Args:
            id: ID del ingreso a eliminar
        Returns: True si se elimina correctamente
        """
        query = """
            DELETE FROM [ClinicaMariaInmaculada].[dbo].[IngresosExtras]
            WHERE id = ?
        """
        
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, (id,))
                conn.commit()
                return cursor.rowcount > 0
        except Exception as e:
            print(f"Error al eliminar ingreso extra: {e}")
            raise
    
    def obtener_por_fecha(self, fecha_inicio: datetime, fecha_fin: datetime) -> List[IngresoExtra]:
        """
        Obtiene ingresos extras en un rango de fechas
        Args:
            fecha_inicio: Fecha inicial del rango
            fecha_fin: Fecha final del rango
        Returns: Lista de objetos IngresoExtra
        """
        query = """
            SELECT 
                ie.id,
                ie.Descripcion,
                ie.Monto,
                ie.Fecha,
                ie.Id_RegistradoPor,
                CONCAT(u.Nombre, ' ', u.Apellido_Paterno, ' ', u.Apellido_Materno) as NombreCompleto
            FROM [ClinicaMariaInmaculada].[dbo].[IngresosExtras] ie
            LEFT JOIN [ClinicaMariaInmaculada].[dbo].[Usuario] u 
                ON ie.Id_RegistradoPor = u.id
            WHERE ie.Fecha BETWEEN ? AND ?
            ORDER BY ie.Fecha DESC
        """
        
        ingresos = []
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, (fecha_inicio, fecha_fin))
                
                for row in cursor.fetchall():
                    ingreso = IngresoExtra(
                        id=row.id,
                        descripcion=row.Descripcion,
                        monto=Decimal(str(row.Monto)),
                        fecha=row.Fecha,
                        id_registrado_por=row.Id_RegistradoPor,
                        nombre_registrado_por=row.NombreCompleto
                    )
                    ingresos.append(ingreso)
        except Exception as e:
            print(f"Error al obtener ingresos por fecha: {e}")
            raise
        
        return ingresos
    
    def obtener_total_por_periodo(self, fecha_inicio: datetime, fecha_fin: datetime) -> Decimal:
        """
        Calcula el total de ingresos extras en un periodo
        Args:
            fecha_inicio: Fecha inicial del periodo
            fecha_fin: Fecha final del periodo
        Returns: Total como Decimal
        """
        query = """
            SELECT ISNULL(SUM(Monto), 0) as Total
            FROM [ClinicaMariaInmaculada].[dbo].[IngresosExtras]
            WHERE Fecha BETWEEN ? AND ?
        """
        
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, (fecha_inicio, fecha_fin))
                row = cursor.fetchone()
                return Decimal(str(row.Total)) if row else Decimal('0.00')
        except Exception as e:
            print(f"Error al calcular total: {e}")
            raise

