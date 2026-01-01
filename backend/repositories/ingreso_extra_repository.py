from typing import List, Dict, Any, Tuple, Optional
from datetime import datetime

from ..core.base_repository import BaseRepository
from ..core.database_conexion import DatabaseConnection

class IngresoExtraRepository(BaseRepository):
    """Repository para gestión de Ingresos Extras"""
    
    def __init__(self):
        # ✅ Pasar table_name y cache_type al constructor base
        super().__init__("IngresosExtras", "ingresos_extras")
        self.db = DatabaseConnection()
        print("💰 IngresoExtraRepository inicializado")
    
    def agregar_ingreso_extra(self, descripcion: str, monto: float, fecha: str, id_usuario: int) -> Tuple[bool, Any]:
        """Agrega un nuevo ingreso extra a la base de datos"""
        try:
            query = """
                INSERT INTO IngresosExtras (descripcion, monto, fecha, id_registradoPor)
                VALUES (?, ?, ?, ?)
            """
            params = (descripcion, monto, fecha, id_usuario)
            
            print(f"🔍 Ejecutando INSERT con params: {params}")
            
            # ✅ CORREGIDO: Usar get_connection() en lugar de get_cursor()
            conn = self.db.get_connection()
            cursor = conn.cursor()
            cursor.execute(query, params)
            conn.commit()
            cursor.close()
            conn.close()
            
            print(f"✅ Ingreso extra agregado exitosamente")
            return True, "Ingreso extra agregado correctamente"
                
        except Exception as e:
            print(f"❌ Error inesperado al agregar ingreso extra: {str(e)}")
            import traceback
            traceback.print_exc()
            return False, f"Error inesperado: {str(e)}"
    
    def actualizar_ingreso_extra(self, id_ingreso: int, descripcion: str, monto: float, fecha: str) -> Tuple[bool, Any]:
        """Actualiza un ingreso extra existente"""
        try:
            query = """
                UPDATE IngresosExtras 
                SET descripcion = ?, monto = ?, fecha = ?
                WHERE id = ?
            """
            params = (descripcion, monto, fecha, id_ingreso)
            
            print(f"🔍 Ejecutando UPDATE para ID {id_ingreso}")
            
            conn = self.db.get_connection()
            cursor = conn.cursor()
            cursor.execute(query, params)
            conn.commit()
            cursor.close()
            conn.close()
            
            print(f"✅ Ingreso extra actualizado ID: {id_ingreso}")
            return True, "Ingreso extra actualizado correctamente"
                
        except Exception as e:
            print(f"❌ Error inesperado al actualizar ingreso extra: {str(e)}")
            import traceback
            traceback.print_exc()
            return False, f"Error inesperado: {str(e)}"
    
    def eliminar_ingreso_extra(self, id_ingreso: int) -> Tuple[bool, Any]:
        """Elimina un ingreso extra"""
        try:
            query = "DELETE FROM IngresosExtras WHERE id = ?"
            params = (id_ingreso,)
            
            print(f"🔍 Ejecutando DELETE para ID {id_ingreso}")
            
            conn = self.db.get_connection()
            cursor = conn.cursor()
            cursor.execute(query, params)
            conn.commit()
            cursor.close()
            conn.close()
            
            print(f"✅ Ingreso extra eliminado ID: {id_ingreso}")
            return True, "Ingreso extra eliminado correctamente"
                
        except Exception as e:
            print(f"❌ Error inesperado al eliminar ingreso extra: {str(e)}")
            import traceback
            traceback.print_exc()
            return False, f"Error inesperado: {str(e)}"
    
    def obtener_todos_ingresos_extras(self) -> Tuple[bool, List[Dict[str, Any]]]:
        """Obtiene todos los ingresos extras con información del usuario"""
        try:
            query = """
                SELECT 
                    ie.id,
                    ie.descripcion,
                    ie.monto,
                    CONVERT(VARCHAR, ie.fecha, 23) as fecha,
                    u.nombre + ' ' + u.Apellido_Paterno as registradoPor
                FROM IngresosExtras ie
                INNER JOIN Usuario u ON ie.id_registradoPor = u.id
                ORDER BY ie.fecha DESC, ie.id DESC
            """
            
            # ✅ CORREGIDO: NO usar get_all() - usar conexión directa
            conn = self.db.get_connection()
            cursor = conn.cursor()
            cursor.execute(query)
            
            # Convertir resultados a lista de diccionarios con tipos correctos
            columns = [column[0] for column in cursor.description]
            result = []
            for row in cursor.fetchall():
                row_dict = dict(zip(columns, row))
                # ✅ Asegurar que monto sea float
                if 'monto' in row_dict and row_dict['monto'] is not None:
                    row_dict['monto'] = float(row_dict['monto'])
                result.append(row_dict)
            
            cursor.close()
            conn.close()
            
            
            # Debug de los primeros registros
            if len(result) > 0:
                print(f"📊 Primer ingreso:")
                first = result[0]
                print(f"   ID: {first.get('id')}, Descripción: {first.get('descripcion')}, Monto: {first.get('monto')} ({type(first.get('monto')).__name__})")
            
            return True, result
                
        except Exception as e:
            print(f"❌ Error inesperado al obtener ingresos extras: {str(e)}")
            import traceback
            traceback.print_exc()
            return False, []
    
    def obtener_ingresos_extras_paginados(self, pagina: int, items_por_pagina: int) -> Tuple[bool, List[Dict[str, Any]]]:
        """Obtiene ingresos extras paginados"""
        try:
            offset = pagina * items_por_pagina
            
            query = """
                SELECT 
                    ie.id,
                    ie.descripcion,
                    ie.monto,
                    CONVERT(VARCHAR, ie.fecha, 23) as fecha,
                    u.nombre + ' ' + u.Apellido_Paterno as registradoPor
                FROM IngresosExtras ie
                INNER JOIN Usuario u ON ie.id_registradoPor = u.id
                ORDER BY ie.fecha DESC, ie.id DESC
                OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
            """
            
            conn = self.db.get_connection()
            cursor = conn.cursor()
            cursor.execute(query, (offset, items_por_pagina))
            
            # Convertir resultados a lista de diccionarios con tipos correctos
            columns = [column[0] for column in cursor.description]
            result = []
            for row in cursor.fetchall():
                row_dict = dict(zip(columns, row))
                # ✅ Asegurar que monto sea float
                if 'monto' in row_dict and row_dict['monto'] is not None:
                    row_dict['monto'] = float(row_dict['monto'])
                result.append(row_dict)
            
            cursor.close()
            conn.close()
            
            print(f"✅ Obtenidos {len(result)} ingresos (página {pagina + 1})")
            return True, result
                
        except Exception as e:
            print(f"❌ Error inesperado al obtener ingresos paginados: {str(e)}")
            import traceback
            traceback.print_exc()
            return False, []
    
    def contar_ingresos_extras(self, mes: int = 0, anio: int = 0) -> Tuple[bool, int]:
        """Cuenta el total de ingresos extras, opcionalmente filtrados por mes y año"""
        try:
            query = "SELECT COUNT(*) as total FROM IngresosExtras"
            
            # ✅ CORREGIDO: Construir WHERE dinámicamente
            where_conditions = []
            params = []
            
            if mes > 0:
                where_conditions.append("MONTH(fecha) = ?")
                params.append(mes)
            
            if anio > 0:
                where_conditions.append("YEAR(fecha) = ?")
                params.append(anio)
            
            if where_conditions:
                query += " WHERE " + " AND ".join(where_conditions)
            
            print(f"🔍 Contando ingresos - Mes: {mes}, Año: {anio}")
            
            conn = self.db.get_connection()
            cursor = conn.cursor()
            
            if params:
                cursor.execute(query, tuple(params))
            else:
                cursor.execute(query)
            
            row = cursor.fetchone()
            total = row[0] if row else 0
            
            cursor.close()
            conn.close()
            
            filtro_texto = []
            if mes > 0:
                filtro_texto.append(f"Mes {mes}")
            if anio > 0:
                filtro_texto.append(f"Año {anio}")
            
            print(f"📊 Total ingresos contados: {total} ({', '.join(filtro_texto) if filtro_texto else 'Sin filtros'})")
            return True, total
                
        except Exception as e:
            print(f"❌ Error inesperado al contar ingresos: {str(e)}")
            import traceback
            traceback.print_exc()
            return False, 0
    
    def obtener_ingresos_extras_filtrados(self, mes: int, anio: int, pagina: int, items_por_pagina: int) -> Tuple[bool, List[Dict[str, Any]]]:
        """Obtiene ingresos extras filtrados por mes y/o año"""
        try:
            offset = pagina * items_por_pagina
            
            # ✅ CORREGIDO: Construir query dinámicamente según filtros activos
            query = """
                SELECT 
                    ie.id,
                    ie.descripcion,
                    ie.monto,
                    CONVERT(VARCHAR, ie.fecha, 23) as fecha,
                    u.nombre + ' ' + u.Apellido_Paterno as registradoPor
                FROM IngresosExtras ie
                INNER JOIN Usuario u ON ie.id_registradoPor = u.id
            """
            
            # Construir WHERE dinámicamente
            where_conditions = []
            params = []
            
            if mes > 0:
                where_conditions.append("MONTH(ie.fecha) = ?")
                params.append(mes)
            
            if anio > 0:
                where_conditions.append("YEAR(ie.fecha) = ?")
                params.append(anio)
            
            if where_conditions:
                query += " WHERE " + " AND ".join(where_conditions)
            
            query += """
                ORDER BY ie.fecha DESC, ie.id DESC
                OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
            """
            
            # Agregar offset y limit
            params.append(offset)
            params.append(items_por_pagina)
            
            print(f"🔍 Query filtros: Mes={mes}, Año={anio}, Página={pagina + 1}")
            print(f"   Condiciones WHERE: {where_conditions}")
            
            conn = self.db.get_connection()
            cursor = conn.cursor()
            cursor.execute(query, tuple(params))
            
            # Convertir resultados a lista de diccionarios con tipos correctos
            columns = [column[0] for column in cursor.description]
            result = []
            for row in cursor.fetchall():
                row_dict = dict(zip(columns, row))
                # Asegurar que monto sea float
                if 'monto' in row_dict and row_dict['monto'] is not None:
                    row_dict['monto'] = float(row_dict['monto'])
                result.append(row_dict)
            
            cursor.close()
            conn.close()
            
            filtro_texto = []
            if mes > 0:
                filtro_texto.append(f"Mes: {mes}")
            if anio > 0:
                filtro_texto.append(f"Año: {anio}")
            
            print(f"✅ Obtenidos {len(result)} ingresos con filtros: {', '.join(filtro_texto) if filtro_texto else 'Sin filtros'}")
            return True, result
                
        except Exception as e:
            print(f"❌ Error inesperado al obtener ingresos filtrados: {str(e)}")
            import traceback
            traceback.print_exc()
            return False, []
    
    def obtener_total_ingresos_mes(self, mes: int, anio: int) -> Tuple[bool, float]:
        """Obtiene el total de ingresos extras de un mes específico o año"""
        try:
            query = "SELECT COALESCE(SUM(monto), 0) as total FROM IngresosExtras"
            
            # ✅ CORREGIDO: Construir WHERE dinámicamente
            where_conditions = []
            params = []
            
            if mes > 0:
                where_conditions.append("MONTH(fecha) = ?")
                params.append(mes)
            
            if anio > 0:
                where_conditions.append("YEAR(fecha) = ?")
                params.append(anio)
            
            if where_conditions:
                query += " WHERE " + " AND ".join(where_conditions)
            
            conn = self.db.get_connection()
            cursor = conn.cursor()
            
            if params:
                cursor.execute(query, tuple(params))
            else:
                cursor.execute(query)
            
            row = cursor.fetchone()
            total = float(row[0]) if row else 0.0
            
            cursor.close()
            conn.close()
            
            filtro_texto = []
            if mes > 0:
                filtro_texto.append(f"Mes {mes}")
            if anio > 0:
                filtro_texto.append(f"Año {anio}")
            
            print(f"💰 Total ingresos: Bs {total:.2f} ({', '.join(filtro_texto) if filtro_texto else 'Sin filtros'})")
            return True, total
                
        except Exception as e:
            print(f"❌ Error inesperado al obtener total de ingresos: {str(e)}")
            import traceback
            traceback.print_exc()
            return False, 0.0
    
    def get_active(self) -> Tuple[bool, List[Dict[str, Any]]]:
        """
        Método requerido por BaseRepository.
        Obtiene todos los ingresos extras (no hay concepto de activo/inactivo).
        """
        return self.obtener_todos_ingresos_extras()

    def verificar_conexion(self) -> bool:
        """Verifica la conexión con la base de datos"""
        try:
            conn = self.db.get_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT 1 as conexion")
            cursor.close()
            conn.close()
            
            print("✅ Conexión a BD verificada (IngresoExtra)")
            return True
                
        except Exception as e:
            print(f"❌ Error verificando conexión: {e}")
            return False
    
    def limpiar_cache(self):
        """Limpia la caché del repositorio"""
        try:
            if hasattr(self, '_cache_manager'):
                self._cache_manager.clear()
            print("✅ Cache de ingresos extras limpiado")
        except Exception as e:
            print(f"❌ Error limpiando cache: {e}")