#!/usr/bin/env python3
"""
Script de Diagnóstico para Sistema de Ventas
Detecta problemas comunes en la base de datos y configuración
"""

import pyodbc
import json
from datetime import datetime, timedelta
from typing import Dict, List, Any

class DiagnosticoVentas:
    def __init__(self, connection_string: str = None):
        """
        Inicializa el diagnóstico con la cadena de conexión
        Configuración basada en database_conexion.py del sistema
        """
        if connection_string:
            self.conn_string = connection_string
        else:
            # Configuración extraída de database_conexion.py
            self.conn_string = (
                "DRIVER={SQL Server};"
                "SERVER=192.168.0.105;"
                "DATABASE=ClinicaMariaInmaculada;"
                "UID=ADMIN;"
                "PWD=admin;"
            )
    
    def conectar(self):
        """Establece conexión con la base de datos"""
        try:
            self.conn = pyodbc.connect(self.conn_string)
            self.cursor = self.conn.cursor()
            return True
        except Exception as e:
            print(f"❌ Error de conexión: {e}")
            return False
    
    def ejecutar_diagnostico_completo(self):
        """Ejecuta todos los diagnósticos disponibles"""
        print("🔍 INICIANDO DIAGNÓSTICO COMPLETO DEL SISTEMA DE VENTAS")
        print("=" * 60)
        
        # 0. Probar conexión con configuración del sistema
        print("\n🔌 0. PROBANDO CONEXIÓN DEL SISTEMA...")
        if not self.probar_conexion_sistema():
            print("❌ No se pudo conectar con la configuración del sistema. Deteniendo diagnóstico.")
            return
        
        if not self.conectar():
            print("❌ No se pudo conectar a la base de datos. Revise la configuración.")
            return
        
        try:
            # 1. Verificar estructura de tablas
            print("\n📋 1. VERIFICANDO ESTRUCTURA DE TABLAS...")
            self.verificar_estructura_tablas()
            
            # 2. Verificar relaciones Foreign Key
            print("\n🔗 2. VERIFICANDO RELACIONES FOREIGN KEY...")
            self.verificar_foreign_keys()
            
            # 3. Verificar datos existentes
            print("\n📊 3. VERIFICANDO DATOS EXISTENTES...")
            self.verificar_datos_existentes()
            
            # 4. Detectar ventas huérfanas
            print("\n🚨 4. DETECTANDO VENTAS HUÉRFANAS...")
            self.detectar_ventas_huerfanas()
            
            # 5. Verificar integridad de datos
            print("\n✅ 5. VERIFICANDO INTEGRIDAD DE DATOS...")
            self.verificar_integridad_datos()
            
            # 6. Analizar ventas del día
            print("\n📅 6. ANALIZANDO VENTAS DEL DÍA...")
            self.analizar_ventas_dia()
            
            # 7. Generar reporte de salud
            print("\n🏥 7. REPORTE DE SALUD DEL SISTEMA...")
            self.generar_reporte_salud()
            
        except Exception as e:
            print(f"❌ Error durante el diagnóstico: {e}")
        finally:
            if hasattr(self, 'conn'):
                self.conn.close()
        
        print("\n" + "=" * 60)
        print("🎯 DIAGNÓSTICO COMPLETADO")
    
    def verificar_estructura_tablas(self):
        """Verifica que las tablas necesarias existan"""
        tablas_requeridas = ['Ventas', 'DetallesVentas', 'Usuario', 'Productos', 'Lote', 'Marca']
        
        for tabla in tablas_requeridas:
            try:
                self.cursor.execute(f"SELECT COUNT(*) FROM {tabla}")
                count = self.cursor.fetchone()[0]
                print(f"   ✅ {tabla}: {count} registros")
            except Exception as e:
                print(f"   ❌ {tabla}: ERROR - {e}")
    
    def verificar_foreign_keys(self):
        """Verifica las relaciones Foreign Key críticas"""
        query_fks = """
        SELECT 
            fk.name AS FK_Name,
            tp.name AS Parent_Table,
            cp.name AS Parent_Column,
            tr.name AS Referenced_Table,
            cr.name AS Referenced_Column
        FROM sys.foreign_keys fk
        INNER JOIN sys.tables tp ON fk.parent_object_id = tp.object_id
        INNER JOIN sys.tables tr ON fk.referenced_object_id = tr.object_id
        INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        INNER JOIN sys.columns cp ON fkc.parent_column_id = cp.column_id AND fkc.parent_object_id = cp.object_id
        INNER JOIN sys.columns cr ON fkc.referenced_column_id = cr.column_id AND fkc.referenced_object_id = cr.object_id
        WHERE tp.name IN ('Ventas', 'DetallesVentas')
        ORDER BY tp.name, fk.name
        """
        
        try:
            self.cursor.execute(query_fks)
            fks = self.cursor.fetchall()
            
            if fks:
                print("   🔗 Foreign Keys encontradas:")
                for fk in fks:
                    print(f"      {fk[0]}: {fk[1]}.{fk[2]} -> {fk[3]}.{fk[4]}")
            else:
                print("   ⚠️ No se encontraron Foreign Keys (posible problema)")
                
        except Exception as e:
            print(f"   ❌ Error verificando FKs: {e}")
    
    def verificar_datos_existentes(self):
        """Verifica la cantidad de datos en tablas críticas"""
        consultas = {
            'Usuarios': "SELECT COUNT(*) FROM Usuario",
            'Productos': "SELECT COUNT(*) FROM Productos", 
            'Lotes': "SELECT COUNT(*) FROM Lote",
            'Ventas_Total': "SELECT COUNT(*) FROM Ventas",
            'Ventas_Hoy': "SELECT COUNT(*) FROM Ventas WHERE CAST(Fecha AS DATE) = CAST(GETDATE() AS DATE)",
            'Detalles_Total': "SELECT COUNT(*) FROM DetallesVentas"
        }
        
        for nombre, query in consultas.items():
            try:
                self.cursor.execute(query)
                count = self.cursor.fetchone()[0]
                status = "✅" if count > 0 else "⚠️"
                print(f"   {status} {nombre}: {count}")
            except Exception as e:
                print(f"   ❌ {nombre}: ERROR - {e}")
    
    def detectar_ventas_huerfanas(self):
        """Detecta ventas sin detalles y detalles sin ventas"""
        
        # Ventas sin detalles
        query_ventas_sin_detalles = """
        SELECT v.id, v.Fecha, v.Total 
        FROM Ventas v
        LEFT JOIN DetallesVentas dv ON v.id = dv.Id_Venta
        WHERE dv.Id_Venta IS NULL
        """
        
        try:
            self.cursor.execute(query_ventas_sin_detalles)
            ventas_huerfanas = self.cursor.fetchall()
            
            if ventas_huerfanas:
                print(f"   🚨 PROBLEMA: {len(ventas_huerfanas)} ventas sin detalles encontradas:")
                for venta in ventas_huerfanas[:5]:  # Mostrar solo las primeras 5
                    print(f"      ID: {venta[0]}, Fecha: {venta[1]}, Total: ${venta[2]}")
                if len(ventas_huerfanas) > 5:
                    print(f"      ... y {len(ventas_huerfanas) - 5} más")
            else:
                print("   ✅ No se encontraron ventas sin detalles")
                
        except Exception as e:
            print(f"   ❌ Error detectando ventas huérfanas: {e}")
        
        # Detalles sin ventas
        query_detalles_huerfanos = """
        SELECT dv.id, dv.Id_Venta 
        FROM DetallesVentas dv
        LEFT JOIN Ventas v ON dv.Id_Venta = v.id
        WHERE v.id IS NULL
        """
        
        try:
            self.cursor.execute(query_detalles_huerfanos)
            detalles_huerfanos = self.cursor.fetchall()
            
            if detalles_huerfanos:
                print(f"   🚨 PROBLEMA: {len(detalles_huerfanos)} detalles huérfanos encontrados:")
                for detalle in detalles_huerfanos[:5]:
                    print(f"      Detalle ID: {detalle[0]}, Venta ID inexistente: {detalle[1]}")
            else:
                print("   ✅ No se encontraron detalles huérfanos")
                
        except Exception as e:
            print(f"   ❌ Error detectando detalles huérfanos: {e}")
    
    def verificar_integridad_datos(self):
        """Verifica la integridad matemática de las ventas"""
        
        query_integridad = """
        SELECT 
            v.id,
            v.Total as Total_Venta,
            SUM(dv.Cantidad_Unitario * dv.Precio_Unitario) as Total_Calculado,
            ABS(v.Total - SUM(dv.Cantidad_Unitario * dv.Precio_Unitario)) as Diferencia
        FROM Ventas v
        INNER JOIN DetallesVentas dv ON v.id = dv.Id_Venta
        GROUP BY v.id, v.Total
        HAVING ABS(v.Total - SUM(dv.Cantidad_Unitario * dv.Precio_Unitario)) > 0.01
        """
        
        try:
            self.cursor.execute(query_integridad)
            ventas_inconsistentes = self.cursor.fetchall()
            
            if ventas_inconsistentes:
                print(f"   🚨 PROBLEMA: {len(ventas_inconsistentes)} ventas con totales inconsistentes:")
                for venta in ventas_inconsistentes:
                    print(f"      ID: {venta[0]}, DB: ${venta[1]}, Calculado: ${venta[2]}, Dif: ${venta[3]}")
            else:
                print("   ✅ Todos los totales de ventas son consistentes")
                
        except Exception as e:
            print(f"   ❌ Error verificando integridad: {e}")
    
    def analizar_ventas_dia(self):
        """Analiza las ventas del día actual"""
        
        query_ventas_hoy = """
        SELECT 
            v.id,
            v.Fecha,
            v.Total,
            u.Nombre + ' ' + u.Apellido_Paterno as Vendedor,
            COUNT(dv.id) as Items_Vendidos
        FROM Ventas v
        INNER JOIN Usuario u ON v.Id_Usuario = u.id
        LEFT JOIN DetallesVentas dv ON v.id = dv.Id_Venta
        WHERE CAST(v.Fecha AS DATE) = CAST(GETDATE() AS DATE)
        GROUP BY v.id, v.Fecha, v.Total, u.Nombre, u.Apellido_Paterno
        ORDER BY v.Fecha DESC
        """
        
        try:
            self.cursor.execute(query_ventas_hoy)
            ventas_hoy = self.cursor.fetchall()
            
            if ventas_hoy:
                total_ingresos = sum(venta[2] for venta in ventas_hoy)
                print(f"   📊 Ventas del día: {len(ventas_hoy)} ventas, ${total_ingresos:.2f} total")
                
                # Mostrar ventas problemáticas (sin items)
                ventas_sin_items = [v for v in ventas_hoy if v[4] == 0]
                if ventas_sin_items:
                    print(f"   🚨 PROBLEMA: {len(ventas_sin_items)} ventas sin items:")
                    for venta in ventas_sin_items:
                        print(f"      ID: {venta[0]}, Total: ${venta[2]}, Vendedor: {venta[3]}")
                else:
                    print("   ✅ Todas las ventas del día tienen items")
            else:
                print("   📊 No hay ventas registradas hoy")
                
        except Exception as e:
            print(f"   ❌ Error analizando ventas del día: {e}")
    
    def generar_reporte_salud(self):
        """Genera un reporte general de salud del sistema"""
        
        problemas = []
        warnings = []
        
        try:
            # Verificar ventas sin detalles
            self.cursor.execute("""
                SELECT COUNT(*) FROM Ventas v
                LEFT JOIN DetallesVentas dv ON v.id = dv.Id_Venta
                WHERE dv.Id_Venta IS NULL
            """)
            ventas_sin_detalles = self.cursor.fetchone()[0]
            
            if ventas_sin_detalles > 0:
                problemas.append(f"{ventas_sin_detalles} ventas sin detalles")
            
            # Verificar ventas recientes
            self.cursor.execute("""
                SELECT COUNT(*) FROM Ventas 
                WHERE Fecha >= DATEADD(DAY, -7, GETDATE())
            """)
            ventas_recientes = self.cursor.fetchone()[0]
            
            if ventas_recientes == 0:
                warnings.append("No hay ventas en los últimos 7 días")
            
            # Verificar usuarios activos
            self.cursor.execute("SELECT COUNT(*) FROM Usuario")
            total_usuarios = self.cursor.fetchone()[0]
            
            if total_usuarios == 0:
                problemas.append("No hay usuarios registrados")
            
            # Verificar productos
            self.cursor.execute("SELECT COUNT(*) FROM Productos")
            total_productos = self.cursor.fetchone()[0]
            
            if total_productos == 0:
                problemas.append("No hay productos registrados")
            
        except Exception as e:
            problemas.append(f"Error en verificación: {e}")
        
        # Mostrar reporte
        if not problemas and not warnings:
            print("   🎉 SISTEMA SALUDABLE: No se detectaron problemas")
        else:
            if problemas:
                print("   🚨 PROBLEMAS CRÍTICOS:")
                for problema in problemas:
                    print(f"      • {problema}")
            
            if warnings:
                print("   ⚠️ ADVERTENCIAS:")
                for warning in warnings:
                    print(f"      • {warning}")
        
        # Recomendaciones
        print("\n💡 RECOMENDACIONES:")
        if ventas_sin_detalles > 0:
            print("   • Implementar la corrección de transacciones en VentaRepository")
            print("   • Ejecutar limpieza de ventas huérfanas")
        
        print("   • Realizar backup regular de la base de datos")
        print("   • Monitorear logs de aplicación durante las ventas")
        print("   • Verificar conectividad de red si hay errores intermitentes")
    
    def limpiar_ventas_huerfanas(self, confirmar: bool = False):
        """Limpia ventas sin detalles (USAR CON PRECAUCIÓN)"""
        
        if not confirmar:
            print("⚠️ ADVERTENCIA: Esta función eliminará ventas sin detalles")
            print("   Ejecute con confirmar=True si está seguro")
            return
        
        try:
            # Obtener ventas huérfanas
            self.cursor.execute("""
                SELECT v.id FROM Ventas v
                LEFT JOIN DetallesVentas dv ON v.id = dv.Id_Venta
                WHERE dv.Id_Venta IS NULL
            """)
            ventas_huerfanas = [row[0] for row in self.cursor.fetchall()]
            
            if ventas_huerfanas:
                # Eliminar ventas huérfanas
                for venta_id in ventas_huerfanas:
                    self.cursor.execute("DELETE FROM Ventas WHERE id = ?", (venta_id,))
                
                self.conn.commit()
                print(f"   🗑️ {len(ventas_huerfanas)} ventas huérfanas eliminadas")
            else:
                print("   ✅ No hay ventas huérfanas para limpiar")
                
        except Exception as e:
            self.conn.rollback()
            print(f"   ❌ Error limpiando ventas huérfanas: {e}")
    
    def verificar_venta_especifica(self, venta_id: int):
        """Verifica una venta específica en detalle"""
        
        if not self.conectar():
            return
        
        try:
            print(f"\n🔍 VERIFICANDO VENTA ID: {venta_id}")
            print("-" * 50)
            
            # Datos de la venta
            self.cursor.execute("""
                SELECT v.*, u.Nombre + ' ' + u.Apellido_Paterno as Vendedor
                FROM Ventas v
                LEFT JOIN Usuario u ON v.Id_Usuario = u.id
                WHERE v.id = ?
            """, (venta_id,))
            
            venta = self.cursor.fetchone()
            
            if not venta:
                print(f"   ❌ Venta {venta_id} no encontrada")
                return
            
            print(f"   📋 Venta encontrada:")
            print(f"      ID: {venta[0]}")
            print(f"      Fecha: {venta[2]}")
            print(f"      Total: ${venta[3]}")
            print(f"      Vendedor: {venta[4] if venta[4] else 'N/A'}")
            
            # Detalles de la venta
            self.cursor.execute("""
                SELECT 
                    dv.id,
                    dv.Cantidad_Unitario,
                    dv.Precio_Unitario,
                    dv.Cantidad_Unitario * dv.Precio_Unitario as Subtotal,
                    p.Codigo,
                    p.Nombre as Producto_Nombre
                FROM DetallesVentas dv
                INNER JOIN Lote l ON dv.Id_Lote = l.id
                INNER JOIN Productos p ON l.Id_Producto = p.id
                WHERE dv.Id_Venta = ?
            """, (venta_id,))
            
            detalles = self.cursor.fetchall()
            
            if detalles:
                print(f"   📦 Detalles ({len(detalles)} productos):")
                total_calculado = 0
                for detalle in detalles:
                    print(f"      • {detalle[4]}: {detalle[5]} x{detalle[1]} @ ${detalle[2]} = ${detalle[3]}")
                    total_calculado += detalle[3]
                
                print(f"   💰 Total calculado: ${total_calculado}")
                print(f"   💰 Total en BD: ${venta[3]}")
                
                diferencia = abs(total_calculado - venta[3])
                if diferencia > 0.01:
                    print(f"   🚨 INCONSISTENCIA: Diferencia de ${diferencia}")
                else:
                    print(f"   ✅ Totales coinciden")
            else:
                print(f"   ❌ PROBLEMA: Venta sin detalles")
                
        except Exception as e:
            print(f"   ❌ Error verificando venta: {e}")
        finally:
            self.conn.close()
    
    def generar_backup_ventas(self):
        """Genera un backup de las ventas problemáticas"""
        
        if not self.conectar():
            return
        
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            
            # Exportar ventas huérfanas
            self.cursor.execute("""
                SELECT v.* FROM Ventas v
                LEFT JOIN DetallesVentas dv ON v.id = dv.Id_Venta
                WHERE dv.Id_Venta IS NULL
            """)
            
            ventas_huerfanas = self.cursor.fetchall()
            
            if ventas_huerfanas:
                filename = f"ventas_huerfanas_backup_{timestamp}.json"
                
                backup_data = {
                    'timestamp': timestamp,
                    'total_ventas': len(ventas_huerfanas),
                    'ventas': []
                }
                
                for venta in ventas_huerfanas:
                    backup_data['ventas'].append({
                        'id': venta[0],
                        'id_usuario': venta[1],
                        'fecha': str(venta[2]),
                        'total': float(venta[3])
                    })
                
                with open(filename, 'w', encoding='utf-8') as f:
                    json.dump(backup_data, f, indent=2, ensure_ascii=False)
                
                print(f"   💾 Backup generado: {filename}")
                print(f"   📊 {len(ventas_huerfanas)} ventas huérfanas respaldadas")
            else:
                print("   ✅ No hay ventas huérfanas para respaldar")
                
        except Exception as e:
            print(f"   ❌ Error generando backup: {e}")
        finally:
            self.conn.close()
    
    def probar_conexion_sistema(self):
        """Prueba la conexión usando la misma configuración del sistema"""
        
        print("🔌 PROBANDO CONEXIÓN CON CONFIGURACIÓN DEL SISTEMA...")
        print(f"   📡 Servidor: 192.168.0.105")
        print(f"   🗄️ Base de datos: ClinicaMariaInmaculada")
        print(f"   👤 Usuario: ADMIN")
        
        try:
            # Intentar conexión
            conn = pyodbc.connect(self.conn_string)
            cursor = conn.cursor()
            
            # Probar query simple
            cursor.execute("SELECT GETDATE() as FechaServidor, @@VERSION as VersionSQL")
            result = cursor.fetchone()
            
            print(f"   ✅ Conexión exitosa")
            print(f"   📅 Fecha del servidor: {result[0]}")
            print(f"   💿 Versión SQL Server: {result[1][:50]}...")
            
            conn.close()
            return True
            
        except Exception as e:
            print(f"   ❌ Error de conexión: {e}")
            print("   🔧 Verificar:")
            print("      • Red/firewall al servidor 192.168.0.105")
            print("      • Credenciales ADMIN/admin")
            print("      • SQL Server corriendo en el servidor")
            return False

def main():
    """Función principal para ejecutar el diagnóstico"""
    
    print("🏥 DIAGNÓSTICO DEL SISTEMA DE VENTAS - CLÍNICA MARÍA INMACULADA")
    print("📡 Servidor: 192.168.0.105 | Base de Datos: ClinicaMariaInmaculada")
    print("=" * 70)
    
    # Crear instancia del diagnóstico con configuración automática
    diagnostico = DiagnosticoVentas()
    
    # Ejecutar diagnóstico completo
    diagnostico.ejecutar_diagnostico_completo()
    
    print("\n🔧 Para aplicar las correcciones, implemente los archivos corregidos:")
    print("   • venta_repository.py (versión con transacciones)")
    print("   • venta_model.py (versión con validaciones mejoradas)")
    
    print("\n🛠️ COMANDOS ADICIONALES DISPONIBLES:")
    print("   • Para limpiar ventas huérfanas: diagnostico.limpiar_ventas_huerfanas(confirmar=True)")
    print("   • Para verificar una venta específica: diagnostico.verificar_venta_especifica(ID)")
    print("   • Para generar backup de seguridad: diagnostico.generar_backup_ventas()")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        # Ejecutar comandos específicos
        comando = sys.argv[1].lower()
        diagnostico = DiagnosticoVentas()
        
        if comando == "conexion":
            diagnostico.probar_conexion_sistema()
        elif comando == "venta" and len(sys.argv) > 2:
            venta_id = int(sys.argv[2])
            diagnostico.verificar_venta_especifica(venta_id)
        elif comando == "backup":
            diagnostico.generar_backup_ventas()
        elif comando == "limpiar":
            print("⚠️ Para confirmar limpieza, use: python diagnostico.py limpiar-confirmar")
        elif comando == "limpiar-confirmar":
            diagnostico.limpiar_ventas_huerfanas(confirmar=True)
        else:
            print("Comandos disponibles:")
            print("  python diagnostico.py conexion")
            print("  python diagnostico.py venta [ID]")
            print("  python diagnostico.py backup")
            print("  python diagnostico.py limpiar-confirmar")
    else:
        # Ejecutar diagnóstico completo
        main()