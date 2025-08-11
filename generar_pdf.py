"""
Módulo para generar reportes en PDF
Sistema de Gestión Médica - Clínica María Inmaculada
"""

import os
import json
from datetime import datetime
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, mm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT

class GeneradorReportesPDF:
    """
    Clase encargada de generar reportes en formato PDF
    """
    
    def __init__(self):
        """Inicializar el generador de PDFs"""
        self.setup_directories()
    
    def setup_directories(self):
        """Crear directorio de reportes si no existe"""
        try:
            home_dir = os.path.expanduser("~")
            self.pdf_dir = os.path.join(home_dir, "Documents", "Reportes_CMI")
            os.makedirs(self.pdf_dir, exist_ok=True)
            print(f"📁 Directorio de reportes: {self.pdf_dir}")
        except Exception as e:
            print(f"❌ Error creando directorio: {e}")
            # Fallback a directorio actual
            self.pdf_dir = os.path.join(os.getcwd(), "Reportes_CMI")
            os.makedirs(self.pdf_dir, exist_ok=True)
    
    def generar_reporte_pdf(self, datos_json, tipo_reporte, fecha_desde, fecha_hasta):
        """
        Método principal para generar un PDF del reporte
        
        Args:
            datos_json (str): Datos del reporte en formato JSON
            tipo_reporte (str): Tipo de reporte (1-8)
            fecha_desde (str): Fecha inicio del período
            fecha_hasta (str): Fecha fin del período
            
        Returns:
            str: Ruta del archivo PDF generado o string vacío si hay error
        """
        try:
            print(f"📄 Iniciando generación de PDF - Tipo: {tipo_reporte}")
            
            # Parsear datos del reporte
            datos = json.loads(datos_json)
            tipo_reporte_int = int(tipo_reporte)
            
            # Generar nombre del archivo
            filename = self._generar_nombre_archivo(tipo_reporte_int, fecha_desde, fecha_hasta)
            filepath = os.path.join(self.pdf_dir, filename)
            
            # Generar el PDF
            success = self._crear_pdf_reporte(filepath, datos, tipo_reporte_int, fecha_desde, fecha_hasta)
            
            if success:
                print(f"✅ PDF generado exitosamente: {filepath}")
                return filepath
            else:
                print("❌ Error al generar PDF")
                return ""
                
        except Exception as e:
            print(f"❌ Error en generar_reporte_pdf: {e}")
            import traceback
            traceback.print_exc()
            return ""
    
    def _generar_nombre_archivo(self, tipo_reporte, fecha_desde, fecha_hasta):
        """Genera un nombre único para el archivo PDF"""
        fecha_limpia_desde = fecha_desde.replace("/", "")
        fecha_limpia_hasta = fecha_hasta.replace("/", "")
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        nombre_tipo = self._obtener_nombre_tipo_reporte(tipo_reporte)
        filename = f"reporte_{nombre_tipo}_{fecha_limpia_desde}_{fecha_limpia_hasta}_{timestamp}.pdf"
        
        return filename
    
    def _obtener_nombre_tipo_reporte(self, tipo_reporte):
        """Obtiene el nombre del tipo de reporte para el archivo"""
        tipos = {
            1: "ventas_farmacia",
            2: "inventario_productos", 
            3: "compras_farmacia",
            4: "consultas_medicas",
            5: "analisis_laboratorio",
            6: "procedimientos_enfermeria",
            7: "gastos_operativos",
            8: "financiero_consolidado"
        }
        return tipos.get(tipo_reporte, "general")
    
    def _obtener_titulo_reporte(self, tipo_reporte):
        """Obtiene el título completo del reporte"""
        titulos = {
            1: "REPORTE DE VENTAS DE FARMACIA",
            2: "REPORTE DE INVENTARIO VALORIZADO", 
            3: "REPORTE DE COMPRAS DE FARMACIA",
            4: "REPORTE DE CONSULTAS MÉDICAS",
            5: "REPORTE DE ANÁLISIS DE LABORATORIO",
            6: "REPORTE DE PROCEDIMIENTOS DE ENFERMERÍA",
            7: "REPORTE DE GASTOS OPERATIVOS",
            8: "REPORTE FINANCIERO CONSOLIDADO"
        }
        return titulos.get(tipo_reporte, "REPORTE GENERAL")
    
    def _obtener_columnas_reporte_carta(self, tipo_reporte):
        """Define las columnas optimizadas para tamaño CARTA (8.5" x 11")"""
        # Ancho total disponible en carta: ~175mm (descontando márgenes)
        
        columnas = {
            1: [  # Ventas - Total: 175mm
                ("FECHA", 25),
                ("N° VENTA", 25), 
                ("CLIENTE/DESCRIPCIÓN", 80),
                ("CANT.", 20),
                ("TOTAL (Bs)", 25)
            ],
            2: [  # Inventario - Total: 175mm  
                ("CÓDIGO", 22),
                ("PRODUCTO", 75),
                ("UM", 15),
                ("STOCK", 20),
                ("P.U.", 20),
                ("STOCK VAL.", 23)
            ],
            3: [  # Compras - Total: 175mm
                ("FECHA", 25),
                ("N° COMPRA", 25),
                ("PROVEEDOR", 85), 
                ("CANT.", 20),
                ("TOTAL (Bs)", 20)
            ],
            4: [  # Consultas - Total: 175mm
                ("FECHA", 25),
                ("ESPECIALIDAD", 40),
                ("MÉDICO", 60),
                ("PACIENTE", 30),
                ("VALOR (Bs)", 20)
            ],
            5: [  # Laboratorio - Total: 175mm
                ("FECHA", 25),
                ("EXAMEN", 70),
                ("PACIENTE", 35),
                ("ESTADO", 25),
                ("VALOR (Bs)", 20)
            ],
            6: [  # Enfermería - Total: 175mm
                ("FECHA", 25),
                ("PROCEDIMIENTO", 75),
                ("PACIENTE", 35),
                ("CANT.", 20),
                ("TOTAL (Bs)", 20)
            ],
            7: [  # Gastos - Total: 175mm
                ("FECHA", 25),
                ("CATEGORÍA", 35),
                ("DESCRIPCIÓN", 95),
                ("MONTO (Bs)", 20)
            ],
            8: [  # Consolidado - Total: 175mm
                ("FECHA", 25),
                ("TIPO", 25),
                ("DESCRIPCIÓN", 75),
                ("REGISTROS", 25),
                ("VALOR (Bs)", 25)
            ]
        }
        return columnas.get(tipo_reporte, [
            ("FECHA", 25),
            ("DESCRIPCIÓN", 110), 
            ("CANT.", 20),
            ("VALOR (Bs)", 20)
        ])
    
    def _crear_pdf_reporte(self, filepath, datos, tipo_reporte, fecha_desde, fecha_hasta):
        """
        Crea el archivo PDF del reporte usando ReportLab - Optimizado para tamaño CARTA
        """
        try:
            # Configurar el documento para CARTA (8.5" x 11")
            doc = SimpleDocTemplate(
                filepath,
                pagesize=letter,  # Letter size
                rightMargin=15*mm,  # Márgenes más pequeños para carta
                leftMargin=15*mm,
                topMargin=20*mm,
                bottomMargin=20*mm
            )
            
            # Estilos optimizados para carta
            styles = getSampleStyleSheet()
            
            # Estilo para título principal
            titulo_style = ParagraphStyle(
                'TituloPersonalizado',
                parent=styles['Title'],
                fontSize=13,  # Reducido para carta
                spaceAfter=8*mm,
                alignment=TA_CENTER,
                fontName='Helvetica-Bold'
            )
            
            # Estilo para subtítulos
            subtitulo_style = ParagraphStyle(
                'SubtituloPersonalizado',
                parent=styles['Normal'],
                fontSize=9,  # Reducido
                spaceBefore=2*mm,
                spaceAfter=2*mm,
                alignment=TA_CENTER,
                fontName='Helvetica'
            )
            
            # Lista de elementos del documento
            story = []
            
            # === ENCABEZADO ===
            titulo_reporte = self._obtener_titulo_reporte(tipo_reporte)
            story.append(Paragraph(titulo_reporte, titulo_style))
            
            # Línea separadora
            story.append(Spacer(1, 2*mm))
            
            # Información del período
            fecha_actual = datetime.now().strftime("%d/%m/%Y")
            periodo_text = f"PERÍODO: {fecha_desde} al {fecha_hasta}"
            fecha_text = f"Fecha: {fecha_actual}"
            
            story.append(Paragraph(periodo_text, subtitulo_style))
            story.append(Paragraph(fecha_text, subtitulo_style))
            story.append(Spacer(1, 4*mm))  # Reducido
            
            # === TABLA DE DATOS ===
            if datos and len(datos) > 0:
                # Obtener definición de columnas OPTIMIZADA para carta
                columnas_def = self._obtener_columnas_reporte_carta(tipo_reporte)
                
                # Crear encabezados de tabla
                encabezados = [col[0] for col in columnas_def]
                anchos_columnas = [col[1] for col in columnas_def]
                
                # Preparar datos para la tabla
                tabla_datos = [encabezados]
                
                total_valor = 0
                
                # Agregar filas de datos
                for registro in datos:
                    fila = []
                    for i, (campo, ancho) in enumerate(columnas_def):
                        valor = self._obtener_valor_campo(registro, campo, tipo_reporte)
                        # Truncar texto largo para ajustarse a carta
                        if len(str(valor)) > 25 and i == 1:  # Descripción/Producto
                            valor = str(valor)[:22] + "..."
                        fila.append(valor)
                    
                    tabla_datos.append(fila)
                    
                    # Sumar valores para total
                    if 'valor' in registro:
                        try:
                            total_valor += float(registro['valor'])
                        except:
                            pass
                
                # Fila de total
                fila_total = [""] * (len(columnas_def) - 2)
                fila_total.append("TOTAL GENERAL:")
                fila_total.append(f"{total_valor:.2f}")
                tabla_datos.append(fila_total)
                
                # Crear tabla con anchos optimizados para carta
                tabla = Table(tabla_datos, colWidths=[w*mm for w in anchos_columnas])
                
                # Aplicar estilos a la tabla (optimizados para carta)
                tabla.setStyle(TableStyle([
                    # Estilo para encabezados
                    ('BACKGROUND', (0, 0), (-1, 0), colors.lightgrey),
                    ('TEXTCOLOR', (0, 0), (-1, 0), colors.black),
                    ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                    ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                    ('FONTSIZE', (0, 0), (-1, 0), 8),  # Reducido para carta
                    ('BOTTOMPADDING', (0, 0), (-1, 0), 6),
                    
                    # Estilo para datos
                    ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
                    ('FONTSIZE', (0, 1), (-1, -2), 7),  # Reducido para carta
                    ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, colors.beige]),
                    ('TOPPADDING', (0, 1), (-1, -2), 3),
                    ('BOTTOMPADDING', (0, 1), (-1, -2), 3),
                    
                    # Estilo para fila de total
                    ('BACKGROUND', (0, -1), (-1, -1), colors.lightgrey),
                    ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
                    ('FONTSIZE', (0, -1), (-1, -1), 8),
                    ('ALIGN', (-2, -1), (-1, -1), 'RIGHT'),
                    
                    # Bordes
                    ('GRID', (0, 0), (-1, -1), 0.5, colors.black),  # Bordes más finos
                    ('LINEBELOW', (0, 0), (-1, 0), 1.5, colors.black),
                    ('LINEABOVE', (0, -1), (-1, -1), 1.5, colors.black),
                ]))
                
                story.append(tabla)
                story.append(Spacer(1, 4*mm))
                
                # === RESUMEN ===
                resumen_text = f"""
                <b>Total de Registros:</b> {len(datos)}<br/>
                <b>Valor Total:</b> Bs {total_valor:.2f}
                """
                
                resumen_style = ParagraphStyle(
                    'ResumenStyle',
                    parent=styles['Normal'],
                    fontSize=8,  # Reducido
                    spaceBefore=2*mm,
                    alignment=TA_LEFT
                )
                
                story.append(Paragraph(resumen_text, resumen_style))
                
            else:
                # Sin datos
                story.append(Paragraph("No se encontraron datos para el período seleccionado.", styles['Normal']))
            
            story.append(Spacer(1, 8*mm))
            
            # === PIE DE PÁGINA ===
            pie_texto = """
            <b>Sistema de Gestión Médica - Clínica María Inmaculada</b><br/>
            Villa Yapacaní, Santa Cruz - Bolivia<br/>
            Documento generado automáticamente el %s
            """ % datetime.now().strftime("%d/%m/%Y %H:%M:%S")
            
            pie_style = ParagraphStyle(
                'PieStyle',
                parent=styles['Normal'],
                fontSize=7,  # Reducido
                alignment=TA_CENTER,
                textColor=colors.grey
            )
            
            story.append(Paragraph(pie_texto, pie_style))
            
            # Construir el PDF
            doc.build(story)
            
            return True
            
        except Exception as e:
            print(f"❌ Error creando PDF: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def _obtener_valor_campo(self, registro, campo_titulo, tipo_reporte):
        """Extrae el valor correcto del registro según el campo y tipo de reporte"""
        
        # Mapear títulos de columnas a campos de datos
        mapeo_campos = {
            "FECHA": "fecha",
            "N° VENTA": "numeroVenta", 
            "N° COMPRA": "numeroCompra",
            "CLIENTE/DESCRIPCIÓN": "descripcion",
            "DESCRIPCIÓN": "descripcion",
            "PRODUCTO": "descripcion",
            "PROVEEDOR": "descripcion",
            "EXAMEN": "descripcion",
            "PROCEDIMIENTO": "descripcion",
            "CANT.": "cantidad",
            "CANTIDAD": "cantidad",
            "TOTAL (Bs)": "valor",
            "VALOR (Bs)": "valor",
            "MONTO (Bs)": "valor",
            "STOCK VAL.": "valor",
            "CÓDIGO": "codigo",
            "UM": "unidad", 
            "STOCK": "cantidad",
            "P.U.": "precioUnitario",
            "ESPECIALIDAD": "especialidad",
            "MÉDICO": "descripcion",
            "PACIENTE": "paciente",
            "ESTADO": "estado",
            "CATEGORÍA": "categoria",
            "TIPO": "tipo",
            "REGISTROS": "cantidad"
        }
        
        campo_dato = mapeo_campos.get(campo_titulo, campo_titulo.lower())
        
        # Obtener valor del registro
        valor = registro.get(campo_dato, "")
        
        # Formatear valores especiales
        if "valor" in campo_dato.lower() or "monto" in campo_dato.lower() or "total" in campo_dato.lower():
            try:
                return f"{float(valor):.2f}"
            except:
                return "0.00"
        elif campo_dato == "cantidad":
            try:
                return str(int(float(valor)))
            except:
                return "0"
        elif campo_dato == "precioUnitario":
            try:
                return f"{float(valor):.2f}"
            except:
                return "0.00"
        
        # Valores por defecto si no existen
        if not valor:
            if campo_dato == "numeroVenta":
                return f"V{registro.get('id', '001')}"
            elif campo_dato == "numeroCompra": 
                return f"C{registro.get('id', '001')}"
            elif campo_dato == "codigo":
                return f"COD{registro.get('id', '001')}"
            elif campo_dato == "unidad":
                return "UND"
            elif campo_dato == "especialidad":
                return "General"
            elif campo_dato == "paciente":
                return "Paciente"
            elif campo_dato == "estado":
                return "Procesado"
            elif campo_dato == "categoria":
                return "General"
            elif campo_dato == "tipo":
                return "INGRESO" if float(registro.get('valor', 0)) >= 0 else "EGRESO"
        
        return str(valor)

# Funciones de utilidad para usar desde otros módulos
def crear_generador_pdf():
    """Función factoría para crear una instancia del generador de PDFs"""
    return GeneradorReportesPDF()

def generar_pdf_reporte(datos_json, tipo_reporte, fecha_desde, fecha_hasta):
    """Función de conveniencia para generar un PDF directamente"""
    generador = GeneradorReportesPDF()
    return generador.generar_reporte_pdf(datos_json, tipo_reporte, fecha_desde, fecha_hasta)