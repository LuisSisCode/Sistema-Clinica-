"""
Módulo para generar reportes PDF profesionales - VERSIÓN MEJORADA
Sistema de Gestión Médica - Clínica María Inmaculada
Versión 3.0 - Diseño profesional basado en estructura de referencia
"""

import os
import json
from datetime import datetime
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, mm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Image
from reportlab.platypus import PageTemplate, Frame, BaseDocTemplate
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader

class CanvasNumerosPagina(canvas.Canvas):
    """Canvas personalizado para numeración automática de páginas"""
    
    def __init__(self, *args, **kwargs):
        canvas.Canvas.__init__(self, *args, **kwargs)
        self._saved_page_states = []
        self.logo_path = None
        
    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()
        
    def save(self):
        """Guarda el PDF y agrega números de página"""
        num_pages = len(self._saved_page_states)
        for (page_num, page_state) in enumerate(self._saved_page_states):
            self.__dict__.update(page_state)
            self.draw_page_number(page_num + 1, num_pages)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)
        
    def draw_page_number(self, page_num, total_pages):
        """Dibuja el número de página en la parte inferior"""
        # Línea superior del pie de página
        self.setStrokeColor(colors.black)
        self.setLineWidth(0.5)
        self.line(20*mm, 25*mm, letter[0]-20*mm, 25*mm)
        
        # Número de página (izquierda)
        self.setFont("Helvetica", 9)
        self.setFillColor(colors.black)
        self.drawString(20*mm, 18*mm, f"Página {page_num} de {total_pages}")
        
        # Fecha de generación (derecha)
        fecha_generacion = datetime.now().strftime("%d/%m/%Y %H:%M")
        text_width = self.stringWidth(f"Generado el {fecha_generacion}", "Helvetica", 9)
        self.drawString(letter[0]-20*mm-text_width, 18*mm, f"Generado el {fecha_generacion}")
        
        # Texto centrado del sistema
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.grey)
        texto_sistema = "Sistema de Gestión Médica - Documento generado automáticamente"
        text_width = self.stringWidth(texto_sistema, "Helvetica", 8)
        self.drawString((letter[0] - text_width) / 2, 10*mm, texto_sistema)

class GeneradorReportesPDF:
    """
    Clase encargada de generar reportes PDF profesionales con estructura mejorada
    """
    
    def __init__(self):
        """Inicializar el generador de PDFs"""
        self.setup_directories()
        self.setup_logo()
    
    def setup_directories(self):
        """Crear directorios necesarios"""
        try:
            # Directorio principal del proyecto
            project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            
            # Directorio de assets
            self.assets_dir = os.path.join(project_dir, "assets")
            os.makedirs(self.assets_dir, exist_ok=True)
            
            # Directorio de reportes
            home_dir = os.path.expanduser("~")
            self.pdf_dir = os.path.join(home_dir, "Documents", "Reportes_CMI")
            os.makedirs(self.pdf_dir, exist_ok=True)
            
            print(f"📁 Directorio de assets: {self.assets_dir}")
            print(f"📁 Directorio de reportes: {self.pdf_dir}")
            
        except Exception as e:
            print(f"❌ Error creando directorios: {e}")
            # Fallback a directorio actual
            self.assets_dir = os.path.join(os.getcwd(), "assets")
            self.pdf_dir = os.path.join(os.getcwd(), "Reportes_CMI")
            os.makedirs(self.assets_dir, exist_ok=True)
            os.makedirs(self.pdf_dir, exist_ok=True)
    
    def setup_logo(self):
        """Configurar logo para PDF usando ruta específica del usuario"""
        # Ruta específica del logo del usuario
        logo_path_directo = r"D:\Sistema-Clinica-\Resources\iconos\logo.png"
        
        # Rutas alternativas de búsqueda 
        current_dir = os.path.dirname(os.path.abspath(__file__))
        logo_paths = [
            logo_path_directo,  # Ruta específica del usuario
            os.path.join(current_dir, "..", "Resources", "iconos", "logo.png"),
            os.path.join(current_dir, "..", "Resources", "iconos", "logo_CMI.png"),
            os.path.join(current_dir, "..", "Resources", "iconos", "logo_CMI.svg"),
            os.path.join(current_dir, "..", "..", "Resources", "iconos", "logo.png"),
            os.path.join(current_dir, "Resources", "iconos", "logo.png"),
        ]
        
        self.logo_path = None
        
        # Buscar logo existente
        for logo_path in logo_paths:
            if os.path.exists(logo_path):
                self.logo_path = logo_path
                print(f"✅ Logo encontrado: {logo_path}")
                break
        
        # Si no se encuentra, usar texto profesional
        if not self.logo_path:
            print("⚠️ Logo no encontrado, usando texto profesional")
            self.logo_path = None
    
    def generar_reporte_pdf(self, datos_json, tipo_reporte, fecha_desde, fecha_hasta):
        """
        Método principal para generar un PDF del reporte
        """
        try:
            print(f"📄 Iniciando generación de PDF profesional - Tipo: {tipo_reporte}")
            
            # Parsear datos del reporte
            datos = json.loads(datos_json)
            tipo_reporte_int = int(tipo_reporte)
            
            # Generar nombre del archivo
            filename = self._generar_nombre_archivo(tipo_reporte_int, fecha_desde, fecha_hasta)
            filepath = os.path.join(self.pdf_dir, filename)
            
            # Generar el PDF
            success = self._crear_pdf_profesional(filepath, datos, tipo_reporte_int, 
                                                fecha_desde, fecha_hasta)
            
            if success:
                print(f"✅ PDF profesional generado: {filepath}")
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
        filename = f"CMI_reporte_{nombre_tipo}_{fecha_limpia_desde}_{fecha_limpia_hasta}_{timestamp}.pdf"
        
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
    
    def _obtener_columnas_reporte(self, tipo_reporte):
        """Define las columnas para cada tipo de reporte"""
        # Anchos en mm para carta (170mm disponible después de márgenes)
        columnas = {
            1: [  # Ventas
                ("FECHA", 25, 'LEFT'),
                ("N° VENTA", 25, 'LEFT'), 
                ("DESCRIPCIÓN", 80, 'LEFT'),
                ("CANT.", 20, 'RIGHT'),
                ("TOTAL (Bs)", 30, 'RIGHT')
            ],
            2: [  # Inventario
                ("CÓDIGO", 23, 'LEFT'),
                ("PRODUCTO", 75, 'LEFT'),
                ("UM", 15, 'CENTER'),
                ("STOCK", 22, 'RIGHT'),
                ("P.U.", 25, 'RIGHT'),
                ("VALOR (Bs)", 30, 'RIGHT')
            ],
            3: [  # Compras
                ("FECHA", 25, 'LEFT'),
                ("N° COMPRA", 28, 'LEFT'),
                ("PROVEEDOR", 80, 'LEFT'),
                ("CANT.", 20, 'RIGHT'),
                ("TOTAL (Bs)", 30, 'RIGHT')
            ],
            4: [  # Consultas
                ("FECHA", 25, 'LEFT'),
                ("ESPECIALIDAD", 42, 'LEFT'),
                ("MÉDICO", 60, 'LEFT'),
                ("PACIENTE", 33, 'LEFT'),
                ("VALOR (Bs)", 25, 'RIGHT')
            ],
            5: [  # Laboratorio
                ("FECHA", 25, 'LEFT'),
                ("EXAMEN", 70, 'LEFT'),
                ("PACIENTE", 40, 'LEFT'),
                ("ESTADO", 25, 'CENTER'),
                ("VALOR (Bs)", 25, 'RIGHT')
            ],
            6: [  # Enfermería
                ("FECHA", 25, 'LEFT'),
                ("PROCEDIMIENTO", 75, 'LEFT'),
                ("PACIENTE", 38, 'LEFT'),
                ("CANT.", 20, 'RIGHT'),
                ("TOTAL (Bs)", 25, 'RIGHT')
            ],
            7: [  # Gastos
                ("FECHA", 25, 'LEFT'),
                ("CATEGORÍA", 38, 'LEFT'),
                ("DESCRIPCIÓN", 90, 'LEFT'),
                ("MONTO (Bs)", 30, 'RIGHT')
            ],
            8: [  # Consolidado
                ("FECHA", 25, 'LEFT'),
                ("TIPO", 28, 'CENTER'),
                ("DESCRIPCIÓN", 75, 'LEFT'),
                ("REGISTROS", 25, 'RIGHT'),
                ("VALOR (Bs)", 30, 'RIGHT')
            ]
        }
        return columnas.get(tipo_reporte, [
            ("FECHA", 25, 'LEFT'),
            ("DESCRIPCIÓN", 110, 'LEFT'), 
            ("CANT.", 20, 'RIGHT'),
            ("VALOR (Bs)", 30, 'RIGHT')
        ])
    
    def _crear_pdf_profesional(self, filepath, datos, tipo_reporte, fecha_desde, fecha_hasta):
        """
        Crea el archivo PDF profesional con estructura mejorada
        """
        try:
            # Crear documento con canvas personalizado
            doc = BaseDocTemplate(
                filepath,
                pagesize=letter,
                rightMargin=20*mm,
                leftMargin=20*mm,
                topMargin=60*mm,  # Más espacio para encabezado elaborado
                bottomMargin=35*mm  # Espacio para pie de página
            )
            
            # Crear frame para el contenido
            frame = Frame(
                20*mm, 35*mm, 
                letter[0]-40*mm, letter[1]-95*mm,
                id='normal'
            )
            
            # Template de página con encabezado y pie
            template = PageTemplate(
                id='todas_paginas',
                frames=[frame],
                onPage=self._crear_encabezado_pie_pagina,
                pagesize=letter
            )
            
            doc.addPageTemplates([template])
            
            # Configurar información del documento
            titulo_reporte = self._obtener_titulo_reporte(tipo_reporte)
            
            # Almacenar información para el encabezado
            self._titulo_reporte = titulo_reporte
            self._fecha_desde = fecha_desde
            self._fecha_hasta = fecha_hasta
            
            # Story principal
            story = []
            
            # Espaciador inicial para separar del encabezado
            story.append(Spacer(1, 10*mm))
            
            # === CONTENIDO PRINCIPAL ===
            if datos and len(datos) > 0:
                # Crear tabla con paginación automática
                tabla = self._crear_tabla_profesional_mejorada(datos, tipo_reporte)
                story.append(tabla)
                
                # Espaciador
                story.append(Spacer(1, 8*mm))
                
                # Resumen ejecutivo
                resumen = self._crear_resumen_ejecutivo(datos)
                story.append(resumen)
                
            else:
                # Sin datos
                styles = getSampleStyleSheet()
                sin_datos_style = ParagraphStyle(
                    'SinDatos',
                    parent=styles['Normal'],
                    fontSize=12,
                    spaceAfter=20*mm,
                    alignment=TA_CENTER,
                    textColor=colors.grey
                )
                story.append(Paragraph("No se encontraron datos para el período seleccionado.", 
                                     sin_datos_style))
            
            # Construir el PDF con canvas personalizado
            doc.build(story, canvasmaker=CanvasNumerosPagina)
            
            return True
            
        except Exception as e:
            print(f"❌ Error creando PDF profesional: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def _crear_encabezado_pie_pagina(self, canvas, doc):
        """Crea encabezado y pie de página en cada página"""
        canvas.saveState()
        
        # === ENCABEZADO PROFESIONAL ===
        # Logo (izquierda)
        if self.logo_path and os.path.exists(self.logo_path):
            try:
                # Intentar cargar logo real
                canvas.drawImage(
                    self.logo_path, 
                    20*mm, letter[1]-45*mm,  # Posición
                    width=50*mm, height=40*mm,  # Tamaño
                    preserveAspectRatio=True,
                    mask='auto'
                )
            except Exception as e:
                print(f"⚠️ Error cargando logo: {e}")
                # Fallback a logo de texto
                self._dibujar_logo_texto(canvas, 20*mm, letter[1]-40*mm)
        else:
            # Logo de texto profesional
            self._dibujar_logo_texto(canvas, 20*mm, letter[1]-40*mm)
        
        # Información de la empresa (centro-derecha)
        canvas.setFont("Helvetica-Bold", 12)
        canvas.setFillColor(colors.black)
        
        # Nombre de la clínica
        text_width = canvas.stringWidth("CLÍNICA MARÍA INMACULADA", "Helvetica-Bold", 12)
        canvas.drawString(letter[0] - 20*mm - text_width, letter[1]-30*mm, "CLÍNICA MARÍA INMACULADA")
        
        # Dirección
        canvas.setFont("Helvetica", 9)
        canvas.setFillColor(colors.grey)
        text_width = canvas.stringWidth("Villa Yapacaní, Santa Cruz - Bolivia", "Helvetica", 9)
        canvas.drawString(letter[0] - 20*mm - text_width, letter[1]-38*mm, "Villa Yapacaní, Santa Cruz - Bolivia")
        
        # Línea separadora del encabezado
        canvas.setStrokeColor(colors.black)
        canvas.setLineWidth(2)
        canvas.line(20*mm, letter[1]-50*mm, letter[0]-20*mm, letter[1]-50*mm)
        
        # Título del reporte (centrado)
        canvas.setFont("Helvetica-Bold", 16)
        canvas.setFillColor(colors.black)
        titulo = getattr(self, '_titulo_reporte', 'REPORTE')
        text_width = canvas.stringWidth(titulo, "Helvetica-Bold", 16)
        canvas.drawString((letter[0] - text_width) / 2, letter[1]-65*mm, titulo)
        
        # Período (centrado, debajo del título)
        canvas.setFont("Helvetica", 10)
        fecha_desde = getattr(self, '_fecha_desde', '')
        fecha_hasta = getattr(self, '_fecha_hasta', '')
        periodo_text = f"PERÍODO: {fecha_desde} al {fecha_hasta}"
        text_width = canvas.stringWidth(periodo_text, "Helvetica", 10)
        canvas.drawString((letter[0] - text_width) / 2, letter[1]-75*mm, periodo_text)
        
        # Línea separadora inferior del encabezado
        canvas.setLineWidth(1)
        canvas.line(20*mm, letter[1]-80*mm, letter[0]-20*mm, letter[1]-80*mm)
        
        canvas.restoreState()
    
    def _dibujar_logo_texto(self, canvas, x, y):
        """Dibuja logo de texto cuando no hay imagen disponible"""
        # Crear un rectángulo para el logo
        canvas.setFillColor(colors.Color(0.17, 0.24, 0.31))  # Color CMI
        canvas.rect(x, y-15*mm, 35*mm, 25*mm, fill=1, stroke=0)
        
        # Texto del logo
        canvas.setFillColor(colors.white)
        canvas.setFont("Helvetica-Bold", 14)
        canvas.drawCentredText(x + 12.5*mm, y-7*mm, "CMI")
        
        canvas.setFont("Helvetica", 8)
        canvas.drawCentredText(x + 12.5*mm, y-11*mm, "CLÍNICA MARÍA")
        canvas.drawCentredText(x + 12.5*mm, y-13*mm, "INMACULADA")
    
    def _crear_tabla_profesional_mejorada(self, datos, tipo_reporte):
        """Crea tabla con estilo profesional mejorado"""
        # Obtener definición de columnas
        columnas_def = self._obtener_columnas_reporte(tipo_reporte)
        
        # Crear encabezados
        encabezados = [col[0] for col in columnas_def]
        anchos_columnas = [col[1]*mm for col in columnas_def]
        
        # Preparar datos para la tabla
        tabla_datos = [encabezados]
        total_valor = 0
        
        # Agregar filas de datos
        for registro in datos:
            fila = []
            for col_titulo, ancho, alineacion in columnas_def:
                valor = self._obtener_valor_campo(registro, col_titulo, tipo_reporte)
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
        fila_total.append(f"Bs {total_valor:,.2f}")
        tabla_datos.append(fila_total)
        
        # Crear tabla
        tabla = Table(tabla_datos, colWidths=anchos_columnas, repeatRows=1)
        
        # Aplicar estilos mejorados
        estilos_tabla = [
            # Encabezado principal
            ('BACKGROUND', (0, 0), (-1, 0), colors.black),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 9),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
            ('TOPPADDING', (0, 0), (-1, 0), 8),
            
            # Bordes del encabezado
            ('LINEBELOW', (0, 0), (-1, 0), 2, colors.black),
            ('LINEBEFORE', (0, 0), (0, 0), 1, colors.black),
            ('LINEAFTER', (-1, 0), (-1, 0), 1, colors.black),
            
            # Datos principales
            ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -2), 8),
            ('TOPPADDING', (0, 1), (-1, -2), 4),
            ('BOTTOMPADDING', (0, 1), (-1, -2), 4),
            ('LEFTPADDING', (0, 1), (-1, -2), 6),
            ('RIGHTPADDING', (0, 1), (-1, -2), 6),
            
            # Bordes verticales para todas las filas de datos
            ('GRID', (0, 1), (-1, -2), 0.5, colors.grey),
            
            # Fila de total especial
            ('BACKGROUND', (0, -1), (-1, -1), colors.lightgrey),
            ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
            ('FONTSIZE', (0, -1), (-1, -1), 9),
            ('TOPPADDING', (0, -1), (-1, -1), 6),
            ('BOTTOMPADDING', (0, -1), (-1, -1), 6),
            ('ALIGN', (-2, -1), (-1, -1), 'RIGHT'),
            
            # Bordes especiales para total
            ('LINEABOVE', (0, -1), (-1, -1), 2, colors.black),
            ('LINEBELOW', (0, -1), (-1, -1), 1, colors.black),
            ('LINEBEFORE', (0, -1), (0, -1), 1, colors.black),
            ('LINEAFTER', (-1, -1), (-1, -1), 1, colors.black),
        ]
        
        # Aplicar zebra striping (filas alternadas)
        for i in range(1, len(tabla_datos) - 1):
            if i % 2 == 0:  # Filas pares
                estilos_tabla.append(('BACKGROUND', (0, i), (-1, i), colors.Color(0.95, 0.95, 0.95)))
        
        # Aplicar alineaciones específicas por columna
        for col_idx, (col_titulo, ancho, alineacion) in enumerate(columnas_def):
            align_map = {'LEFT': 'LEFT', 'RIGHT': 'RIGHT', 'CENTER': 'CENTER'}
            tabla_align = align_map.get(alineacion, 'LEFT')
            estilos_tabla.append(('ALIGN', (col_idx, 1), (col_idx, -2), tabla_align))
        
        tabla.setStyle(TableStyle(estilos_tabla))
        
        return tabla
    
    def _crear_resumen_ejecutivo(self, datos):
        """Crea sección de resumen ejecutivo"""
        # Calcular totales
        total_registros = len(datos)
        total_valor = sum(float(item.get('valor', 0)) for item in datos)
        valor_promedio = total_valor / total_registros if total_registros > 0 else 0
        
        # Crear tabla de resumen
        resumen_datos = [
            ['RESUMEN EJECUTIVO', ''],
            ['Total de Registros:', f'{total_registros:,}'],
            ['Valor Total:', f'Bs {total_valor:,.2f}'],
            ['Valor Promedio:', f'Bs {valor_promedio:,.2f}']
        ]
        
        resumen_tabla = Table(resumen_datos, colWidths=[50*mm, 35*mm])
        resumen_tabla.setStyle(TableStyle([
            # Primera fila (título)
            ('BACKGROUND', (0, 0), (-1, 0), colors.black),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 10),
            ('SPAN', (0, 0), (-1, 0)),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
            ('TOPPADDING', (0, 0), (-1, 0), 6),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 6),
            
            # Filas de datos
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -1), 9),
            ('TOPPADDING', (0, 1), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 1), (-1, -1), 4),
            ('LEFTPADDING', (0, 1), (-1, -1), 8),
            ('RIGHTPADDING', (0, 1), (-1, -1), 8),
            ('ALIGN', (0, 1), (0, -1), 'LEFT'),
            ('ALIGN', (1, 1), (1, -1), 'RIGHT'),
            ('FONTNAME', (1, 1), (1, -1), 'Helvetica-Bold'),
            
            # Bordes
            ('LINEBELOW', (0, 0), (-1, 0), 1, colors.black),
            ('GRID', (0, 1), (-1, -1), 0.5, colors.grey),
            ('BACKGROUND', (0, 1), (-1, -1), colors.Color(0.98, 0.98, 0.98))
        ]))
        
        return resumen_tabla
    
    def _obtener_valor_campo(self, registro, campo_titulo, tipo_reporte):
        """Extrae el valor correcto del registro según el campo y tipo de reporte"""
        
        # Mapear títulos de columnas a campos de datos
        mapeo_campos = {
            "FECHA": "fecha",
            "N° VENTA": "numeroVenta", 
            "N° COMPRA": "numeroCompra",
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
        valor = registro.get(campo_dato, "")
        
        # Formatear valores especiales
        if "valor" in campo_dato.lower() or "monto" in campo_dato.lower() or "total" in campo_dato.lower():
            try:
                return f"Bs {float(valor):,.2f}"
            except:
                return "Bs 0.00"
        elif campo_dato == "cantidad" or campo_dato == "registros":
            try:
                return f"{int(float(valor)):,}"
            except:
                return "0"
        elif campo_dato == "precioUnitario":
            try:
                return f"Bs {float(valor):,.2f}"
            except:
                return "Bs 0.00"
        
        # Valores por defecto si no existen
        if not valor:
            defaults = {
                "numeroVenta": f"V{registro.get('id', '001')}",
                "numeroCompra": f"C{registro.get('id', '001')}", 
                "codigo": f"COD{registro.get('id', '001')}",
                "unidad": "UND",
                "especialidad": "General",
                "paciente": "Paciente",
                "estado": "Procesado",
                "categoria": "General",
                "tipo": "INGRESO" if float(registro.get('valor', 0)) >= 0 else "EGRESO"
            }
            valor = defaults.get(campo_dato, "")
        
        # Truncar texto largo para evitar desbordamiento
        if isinstance(valor, str) and len(valor) > 40:
            return valor[:37] + "..."
        
        return str(valor)

# Funciones de utilidad
def crear_generador_pdf():
    """Función factoría para crear una instancia del generador de PDFs"""
    return GeneradorReportesPDF()

def generar_pdf_reporte(datos_json, tipo_reporte, fecha_desde, fecha_hasta):
    """Función de conveniencia para generar un PDF directamente"""
    generador = GeneradorReportesPDF()
    return generador.generar_reporte_pdf(datos_json, tipo_reporte, fecha_desde, fecha_hasta)