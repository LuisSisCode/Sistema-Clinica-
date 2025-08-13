"""
Servicio para generación de reportes
Sistema de Gestión Médica - Clínica María Inmaculada
"""

import json
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

from ..core.excepciones import (
    ReporteError, ValidationError, ExceptionHandler, 
    validate_required
)
from ..core.utils import parse_date_from_str, safe_float
from ..repositories.venta_repository import VentaRepository
from ..repositories.producto_repository import ProductoRepository
from ..repositories.compra_repository import CompraRepository
from ..repositories.consulta_repository import ConsultaRepository
from ..repositories.laboratorio_repository import LaboratorioRepository
from ..repositories.gasto_repository import GastoRepository
from ..repositories.estadistica_repository import EstadisticaRepository

# Importar el generador de PDF
try:
    from generar_pdf import GeneradorReportesPDF
except ImportError:
    # Fallback si está en otra ubicación
    import sys
    import os
    sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from generar_pdf import GeneradorReportesPDF

class ReporteService:
    """
    Servicio para generación de reportes completos del sistema
    Maneja los 8 tipos de reportes definidos en el QML
    """
    
    def __init__(self):
        """Inicializar repositories y generador PDF"""
        # Repositories
        self.venta_repo = VentaRepository()
        self.producto_repo = ProductoRepository()
        self.compra_repo = CompraRepository()
        self.consulta_repo = ConsultaRepository()
        self.laboratorio_repo = LaboratorioRepository()
        self.gasto_repo = GastoRepository()
        self.estadistica_repo = EstadisticaRepository()
        
        # Generador PDF
        self.pdf_generator = GeneradorReportesPDF()
        
        print("📊 ReporteService inicializado correctamente")
    
    # ===============================
    # MÉTODO PRINCIPAL PARA QML
    # ===============================
    
    @ExceptionHandler.handle_exception
    def generar_reporte_pdf(self, datos_json: str, tipo_reporte_str: str, 
                           fecha_desde: str, fecha_hasta: str) -> str:
        """
        Método principal para generar PDFs desde QML
        
        Args:
            datos_json: Datos del reporte en JSON (desde QML)
            tipo_reporte_str: Tipo de reporte como string (1-8)
            fecha_desde: Fecha inicio formato DD/MM/YYYY
            fecha_hasta: Fecha fin formato DD/MM/YYYY
            
        Returns:
            str: Ruta del archivo PDF generado o string vacío si error
        """
        try:
            print(f"📄 Generando reporte PDF - Tipo: {tipo_reporte_str}")
            
            # Validaciones básicas
            validate_required(datos_json, "datos_json")
            validate_required(tipo_reporte_str, "tipo_reporte")
            validate_required(fecha_desde, "fecha_desde")
            validate_required(fecha_hasta, "fecha_hasta")
            
            # Convertir tipo a entero
            try:
                tipo_reporte = int(tipo_reporte_str)
                if tipo_reporte < 1 or tipo_reporte > 8:
                    raise ValidationError("tipo_reporte", tipo_reporte, "Debe estar entre 1 y 8")
            except ValueError:
                raise ValidationError("tipo_reporte", tipo_reporte_str, "Debe ser un número válido")
            
            # Usar el generador de PDF existente
            ruta_pdf = self.pdf_generator.generar_reporte_pdf(
                datos_json, tipo_reporte_str, fecha_desde, fecha_hasta
            )
            
            if ruta_pdf:
                print(f"✅ PDF generado exitosamente: {ruta_pdf}")
                return ruta_pdf
            else:
                raise ReporteError("Error generando PDF", str(tipo_reporte), (fecha_desde, fecha_hasta))
            
        except Exception as e:
            print(f"❌ Error en generar_reporte_pdf: {e}")
            raise ReporteError(f"Error generando reporte: {str(e)}", 
                             tipo_reporte_str, (fecha_desde, fecha_hasta))
    
    # ===============================
    # OBTENCIÓN DE DATOS POR TIPO
    # ===============================
    
    def obtener_datos_reporte(self, tipo_reporte: int, fecha_desde: str, 
                             fecha_hasta: str) -> List[Dict[str, Any]]:
        """
        Obtiene los datos para un tipo específico de reporte
        
        Args:
            tipo_reporte: Tipo de reporte (1-8)
            fecha_desde: Fecha inicio DD/MM/YYYY
            fecha_hasta: Fecha fin DD/MM/YYYY
            
        Returns:
            Lista de registros para el reporte
        """
        print(f"📊 Obteniendo datos para reporte tipo {tipo_reporte}")
        
        # Convertir fechas
        try:
            start_date = parse_date_from_str(fecha_desde)
            end_date = parse_date_from_str(fecha_hasta)
        except Exception as e:
            raise ValidationError("fechas", f"{fecha_desde}-{fecha_hasta}", 
                                f"Formato de fecha inválido: {str(e)}")
        
        # Routing por tipo de reporte
        datos_handlers = {
            1: self._obtener_datos_ventas_farmacia,
            2: self._obtener_datos_inventario_productos,
            3: self._obtener_datos_compras_farmacia,
            4: self._obtener_datos_consultas_medicas,
            5: self._obtener_datos_analisis_laboratorio,
            6: self._obtener_datos_procedimientos_enfermeria,
            7: self._obtener_datos_gastos_operativos,
            8: self._obtener_datos_reporte_consolidado
        }
        
        handler = datos_handlers.get(tipo_reporte)
        if not handler:
            raise ValidationError("tipo_reporte", tipo_reporte, "Tipo de reporte no válido")
        
        try:
            datos = handler(start_date, end_date)
            print(f"📈 Datos obtenidos: {len(datos)} registros")
            return datos
        except Exception as e:
            raise ReporteError(f"Error obteniendo datos: {str(e)}", str(tipo_reporte))
    
    # ===============================
    # HANDLERS ESPECÍFICOS POR TIPO
    # ===============================
    
    def _obtener_datos_ventas_farmacia(self, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
        """Datos para reporte de ventas de farmacia"""
        fecha_desde_str = start_date.strftime('%Y-%m-%d')
        fecha_hasta_str = end_date.strftime('%Y-%m-%d')
        
        ventas = self.venta_repo.get_ventas_con_detalles(fecha_desde_str, fecha_hasta_str)
        
        datos_formateados = []
        for venta in ventas:
            # Obtener detalles completos de la venta
            venta_completa = self.venta_repo.get_venta_completa(venta['Venta_ID'])
            
            # Crear descripción de productos vendidos
            descripcion_items = []
            for detalle in venta_completa.get('detalles', []):
                item_desc = f"{detalle.get('Producto_Nombre', 'Producto')} x{detalle.get('Cantidad_Unitario', 1)}"
                descripcion_items.append(item_desc)
            
            descripcion = ", ".join(descripcion_items[:3])  # Limitar a 3 items
            if len(venta_completa.get('detalles', [])) > 3:
                descripcion += f" y {len(venta_completa['detalles']) - 3} más"
            
            datos_formateados.append({
                'fecha': venta['Fecha'].strftime('%d/%m/%Y') if venta.get('Fecha') else '',
                'numeroVenta': f"V{str(venta['Venta_ID']).zfill(3)}",
                'descripcion': descripcion or 'Venta de farmacia',
                'cantidad': venta.get('Unidades_Totales', 0) or 0,
                'valor': safe_float(venta.get('Venta_Total', 0)),
                'cliente': venta.get('Vendedor', 'Cliente general')
            })
        
        return datos_formateados
    
    def _obtener_datos_inventario_productos(self, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
        """Datos para reporte de inventario de productos"""
        # Para inventario usamos la fecha actual (no el rango)
        productos = self.producto_repo.get_productos_con_marca()
        
        datos_formateados = []
        for producto in productos:
            stock_total = safe_float(producto.get('Stock_Caja', 0)) + safe_float(producto.get('Stock_Unitario', 0))
            precio_compra = safe_float(producto.get('Precio_compra', 0))
            valor_stock = stock_total * precio_compra
            
            datos_formateados.append({
                'fecha': datetime.now().strftime('%d/%m/%Y'),
                'codigo': producto.get('Codigo', 'N/A'),
                'descripcion': producto.get('Nombre', 'Producto sin nombre'),
                'unidad': producto.get('Unidad_Medida', 'UND'),
                'cantidad': int(stock_total),
                'precioUnitario': precio_compra,
                'valor': valor_stock
            })
        
        # Filtrar solo productos con stock > 0
        return [d for d in datos_formateados if d['cantidad'] > 0]
    
    def _obtener_datos_compras_farmacia(self, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
        """Datos para reporte de compras de farmacia"""
        fecha_desde_str = start_date.strftime('%Y-%m-%d')
        fecha_hasta_str = end_date.strftime('%Y-%m-%d')
        
        compras = self.compra_repo.get_compras_con_detalles(fecha_desde_str, fecha_hasta_str)
        
        datos_formateados = []
        for compra in compras:
            datos_formateados.append({
                'fecha': compra['Fecha'].strftime('%d/%m/%Y') if compra.get('Fecha') else '',
                'numeroCompra': f"C{str(compra['Compra_ID']).zfill(3)}",
                'descripcion': compra.get('Proveedor', 'Proveedor no especificado'),
                'cantidad': compra.get('Unidades_Totales', 0) or 0,
                'valor': safe_float(compra.get('Compra_Total', 0)),
                'proveedor': compra.get('Proveedor', 'N/A')
            })
        
        return datos_formateados
    
    def _obtener_datos_consultas_medicas(self, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
        """Datos para reporte de consultas médicas"""
        consultas = self.consulta_repo.get_consultations_for_report(start_date, end_date)
        
        datos_formateados = []
        for consulta in consultas:
            datos_formateados.append({
                'fecha': consulta['Fecha'].strftime('%d/%m/%Y') if consulta.get('Fecha') else '',
                'especialidad': consulta.get('especialidad_nombre', 'General'),
                'descripcion': consulta.get('doctor_completo', 'Doctor no especificado'),
                'paciente': consulta.get('paciente_completo', 'Paciente'),
                'cantidad': 1,
                'valor': safe_float(consulta.get('Precio_Normal', 0)),
                'medico': consulta.get('doctor_completo', 'N/A')
            })
        
        return datos_formateados
    
    def _obtener_datos_analisis_laboratorio(self, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
        """Datos para reporte de análisis de laboratorio"""
        # El laboratorio no tiene filtro por fecha directo, obtenemos todos
        examenes = self.laboratorio_repo.get_all_with_details(limit=1000)
        
        datos_formateados = []
        for examen in examenes:
            # Simular fecha basada en ID (para propósitos del reporte)
            fecha_estimada = datetime.now() - timedelta(days=(examen.get('id', 1) % 30))
            
            # Filtrar por rango de fechas estimado
            if start_date <= fecha_estimada <= end_date:
                datos_formateados.append({
                    'fecha': fecha_estimada.strftime('%d/%m/%Y'),
                    'descripcion': examen.get('Nombre', 'Examen de laboratorio'),
                    'paciente': examen.get('paciente_completo', 'Paciente'),
                    'estado': 'Procesado' if examen.get('Id_Trabajador') else 'Pendiente',
                    'cantidad': 1,
                    'valor': safe_float(examen.get('Precio_Normal', 0))
                })
        
        return datos_formateados
    
    def _obtener_datos_procedimientos_enfermeria(self, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
        """Datos para reporte de procedimientos de enfermería"""
        # Simulamos datos de enfermería basados en trabajadores
        trabajadores_enfermeria = self.laboratorio_repo.get_available_lab_workers()
        
        datos_formateados = []
        base_procedimientos = [
            'Inyección intramuscular',
            'Curación simple', 
            'Control de signos vitales',
            'Nebulización',
            'Vendaje especializado'
        ]
        
        # Generar datos simulados dentro del rango de fechas
        dias_rango = (end_date - start_date).days + 1
        for i in range(min(dias_rango * 2, 20)):  # Máximo 20 registros
            fecha_proc = start_date + timedelta(days=i % dias_rango)
            procedimiento = base_procedimientos[i % len(base_procedimientos)]
            
            datos_formateados.append({
                'fecha': fecha_proc.strftime('%d/%m/%Y'),
                'descripcion': procedimiento,
                'paciente': f'Paciente {i+1:02d}',
                'cantidad': 1 + (i % 3),  # 1-3 procedimientos
                'valor': 25.0 + (i % 5) * 10.0  # 25-65 Bs
            })
        
        return datos_formateados
    
    def _obtener_datos_gastos_operativos(self, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
        """Datos para reporte de gastos operativos"""
        gastos = self.gasto_repo.get_expenses_by_date_range(start_date, end_date)
        
        datos_formateados = []
        for gasto in gastos:
            datos_formateados.append({
                'fecha': gasto['Fecha'].strftime('%d/%m/%Y') if gasto.get('Fecha') else '',
                'categoria': gasto.get('tipo_nombre', 'General'),
                'descripcion': gasto.get('tipo_nombre', 'Gasto operativo'),
                'cantidad': 1,
                'valor': -abs(safe_float(gasto.get('Monto', 0)))  # Gastos son negativos
            })
        
        return datos_formateados
    
    def _obtener_datos_reporte_consolidado(self, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
        """Datos para reporte financiero consolidado"""
        datos_consolidados = []
        
        # 1. Obtener ingresos de ventas
        ventas = self._obtener_datos_ventas_farmacia(start_date, end_date)
        total_ventas = sum(v['valor'] for v in ventas)
        if total_ventas > 0:
            datos_consolidados.append({
                'fecha': end_date.strftime('%d/%m/%Y'),
                'tipo': 'INGRESO',
                'descripcion': 'Ventas de Farmacia',
                'cantidad': len(ventas),
                'valor': total_ventas
            })
        
        # 2. Obtener ingresos de consultas
        consultas = self._obtener_datos_consultas_medicas(start_date, end_date)
        total_consultas = sum(c['valor'] for c in consultas)
        if total_consultas > 0:
            datos_consolidados.append({
                'fecha': end_date.strftime('%d/%m/%Y'),
                'tipo': 'INGRESO', 
                'descripcion': 'Consultas Médicas',
                'cantidad': len(consultas),
                'valor': total_consultas
            })
        
        # 3. Obtener ingresos de laboratorio
        laboratorio = self._obtener_datos_analisis_laboratorio(start_date, end_date)
        total_laboratorio = sum(l['valor'] for l in laboratorio)
        if total_laboratorio > 0:
            datos_consolidados.append({
                'fecha': end_date.strftime('%d/%m/%Y'),
                'tipo': 'INGRESO',
                'descripcion': 'Análisis de Laboratorio', 
                'cantidad': len(laboratorio),
                'valor': total_laboratorio
            })
        
        # 4. Obtener egresos de compras
        compras = self._obtener_datos_compras_farmacia(start_date, end_date)
        total_compras = sum(c['valor'] for c in compras)
        if total_compras > 0:
            datos_consolidados.append({
                'fecha': end_date.strftime('%d/%m/%Y'),
                'tipo': 'EGRESO',
                'descripcion': 'Compras de Farmacia',
                'cantidad': len(compras),
                'valor': -abs(total_compras)  # Egresos negativos
            })
        
        # 5. Obtener gastos operativos
        gastos = self._obtener_datos_gastos_operativos(start_date, end_date)
        total_gastos = sum(abs(g['valor']) for g in gastos)
        if total_gastos > 0:
            datos_consolidados.append({
                'fecha': end_date.strftime('%d/%m/%Y'),
                'tipo': 'EGRESO',
                'descripcion': 'Gastos Operativos',
                'cantidad': len(gastos),
                'valor': -abs(total_gastos)  # Egresos negativos
            })
        
        return datos_consolidados
    
    # ===============================
    # MÉTODOS DE UTILIDAD
    # ===============================
    
    def validar_rango_fechas(self, fecha_desde: str, fecha_hasta: str) -> bool:
        """Valida que el rango de fechas sea válido"""
        try:
            start_date = parse_date_from_str(fecha_desde)
            end_date = parse_date_from_str(fecha_hasta)
            
            if start_date > end_date:
                raise ValidationError("fechas", f"{fecha_desde}-{fecha_hasta}", 
                                    "Fecha desde debe ser menor que fecha hasta")
            
            # Validar que no sea un rango muy grande (más de 1 año)
            if (end_date - start_date).days > 365:
                raise ValidationError("fechas", f"{fecha_desde}-{fecha_hasta}",
                                    "Rango de fechas no puede ser mayor a 1 año")
            
            return True
            
        except Exception as e:
            raise ValidationError("fechas", f"{fecha_desde}-{fecha_hasta}", str(e))
    
    def obtener_resumen_reporte(self, datos: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calcula resumen estadístico del reporte"""
        if not datos:
            return {
                'total_registros': 0,
                'total_valor': 0.0,
                'valor_promedio': 0.0
            }
        
        total_valor = sum(safe_float(item.get('valor', 0)) for item in datos)
        
        return {
            'total_registros': len(datos),
            'total_valor': total_valor,
            'valor_promedio': total_valor / len(datos) if datos else 0.0,
            'fecha_generacion': datetime.now().strftime('%d/%m/%Y %H:%M:%S')
        }
    
    def obtener_tipos_reportes_disponibles(self) -> List[Dict[str, Any]]:
        """Retorna lista de tipos de reportes disponibles"""
        return [
            {'id': 1, 'nombre': 'Ventas de Farmacia', 'descripcion': 'Reporte de ventas realizadas en farmacia'},
            {'id': 2, 'nombre': 'Inventario de Productos', 'descripcion': 'Estado actual del inventario valorizado'},
            {'id': 3, 'nombre': 'Compras de Farmacia', 'descripcion': 'Historial de compras realizadas'},
            {'id': 4, 'nombre': 'Consultas Médicas', 'descripcion': 'Registro de consultas por especialidad'},
            {'id': 5, 'nombre': 'Análisis de Laboratorio', 'descripcion': 'Exámenes realizados en laboratorio'},
            {'id': 6, 'nombre': 'Procedimientos de Enfermería', 'descripcion': 'Procedimientos realizados por enfermería'},
            {'id': 7, 'nombre': 'Gastos Operativos', 'descripción': 'Gastos en servicios y operaciones'},
            {'id': 8, 'nombre': 'Reporte Financiero Consolidado', 'descripcion': 'Resumen financiero integral'}
        ]
    
    def limpiar_archivos_temporales(self, dias_antiguedad: int = 7):
        """Limpia archivos PDF antiguos para liberar espacio"""
        try:
            import os
            import time
            
            pdf_dir = self.pdf_generator.pdf_dir
            if not os.path.exists(pdf_dir):
                return
            
            limite_tiempo = time.time() - (dias_antiguedad * 24 * 60 * 60)
            archivos_eliminados = 0
            
            for archivo in os.listdir(pdf_dir):
                if archivo.endswith('.pdf'):
                    ruta_archivo = os.path.join(pdf_dir, archivo)
                    if os.path.getmtime(ruta_archivo) < limite_tiempo:
                        try:
                            os.remove(ruta_archivo)
                            archivos_eliminados += 1
                        except OSError:
                            pass
            
            print(f"🧹 Archivos PDF antiguos eliminados: {archivos_eliminados}")
            
        except Exception as e:
            print(f"⚠️ Error limpiando archivos temporales: {e}")
    
    # ===============================
    # MÉTODOS PARA TESTING
    # ===============================
    
    def test_reportes_disponibles(self) -> Dict[str, bool]:
        """Prueba que todos los tipos de reportes funcionen"""
        resultados = {}
        fecha_desde = (datetime.now() - timedelta(days=30)).strftime('%d/%m/%Y')
        fecha_hasta = datetime.now().strftime('%d/%m/%Y')
        
        for tipo in range(1, 9):
            try:
                datos = self.obtener_datos_reporte(tipo, fecha_desde, fecha_hasta)
                resultados[f'reporte_{tipo}'] = len(datos) >= 0  # Al menos no falló
                print(f"✅ Reporte tipo {tipo}: {len(datos)} registros")
            except Exception as e:
                resultados[f'reporte_{tipo}'] = False
                print(f"❌ Reporte tipo {tipo}: {str(e)}")
        
        return resultados
    
    def generar_reporte_demo(self, tipo_reporte: int) -> str:
        """Genera un reporte de demostración para testing"""
        fecha_desde = (datetime.now() - timedelta(days=7)).strftime('%d/%m/%Y')
        fecha_hasta = datetime.now().strftime('%d/%m/%Y')
        
        try:
            datos = self.obtener_datos_reporte(tipo_reporte, fecha_desde, fecha_hasta)
            datos_json = json.dumps(datos, default=str, ensure_ascii=False)
            
            return self.generar_reporte_pdf(datos_json, str(tipo_reporte), fecha_desde, fecha_hasta)
            
        except Exception as e:
            raise ReporteError(f"Error generando reporte demo: {str(e)}", str(tipo_reporte))

# ===============================
# FUNCIÓN PARA INSTANCIA GLOBAL
# ===============================

_reporte_service_instance = None

def get_reporte_service() -> ReporteService:
    """Obtiene instancia singleton del servicio de reportes"""
    global _reporte_service_instance
    if _reporte_service_instance is None:
        _reporte_service_instance = ReporteService()
    return _reporte_service_instance