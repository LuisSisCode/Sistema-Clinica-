"""
Módulo para generar reportes PDF profesionales - VERSIÓN MEJORADA
Sistema de Gestión Médica - Clínica María Inmaculada
Versión 4.1 - Diseño profesional estilo informe gubernamental mejorado
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
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Image

# Colores profesionales mejorados
COLOR_AZUL_PRINCIPAL = colors.Color(0.12, 0.31, 0.52)  # Azul institucional
COLOR_AZUL_CLARO = colors.Color(0.85, 0.92, 0.97)      # Azul claro para fondos
COLOR_ROJO_ACENTO = colors.Color(0.8, 0.2, 0.2)        # Rojo para acentos
COLOR_GRIS_OSCURO = colors.Color(0.2, 0.2, 0.2)        # Gris oscuro
COLOR_GRIS_CLARO = colors.Color(0.95, 0.95, 0.95)      # Gris claro
COLOR_VERDE_POSITIVO = colors.Color(0.13, 0.54, 0.13)  # Verde para valores positivos

class CanvasNumerosPaginaProfesional(canvas.Canvas):
    """Canvas personalizado con diseño profesional estilo gubernamental"""
    
    def __init__(self, *args, **kwargs):
        canvas.Canvas.__init__(self, *args, **kwargs)
        self._saved_page_states = []
        self.logo_path = None
        self.titulo_reporte = ""
        self.fecha_desde = ""
        self.fecha_hasta = ""
        self.fecha_generacion = ""
        
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
        """Dibuja pie de página profesional"""
        # Línea superior del pie de página
        self.setStrokeColor(COLOR_AZUL_PRINCIPAL)
        self.setLineWidth(2)
        self.line(25*mm, 35*mm, letter[0]-25*mm, 35*mm)
        
        # Información del pie de página
        self.setFont("Helvetica", 9)
        self.setFillColor(COLOR_GRIS_OSCURO)
        
        # Página (izquierda)
        self.drawString(25*mm, 28*mm, f"Página {page_num} de {total_pages}")
        
        # Fecha de generación (derecha)
        fecha_texto = f"Generado: {self.fecha_generacion}"
        text_width = self.stringWidth(fecha_texto, "Helvetica", 9)
        self.drawString(letter[0]-25*mm-text_width, 28*mm, fecha_texto)
        
        # Texto del sistema (centro)
        self.setFont("Helvetica", 8)
        self.setFillColor(COLOR_GRIS_OSCURO)
        texto_sistema = "Sistema de Gestión Médica - Documento Oficial"
        text_width = self.stringWidth(texto_sistema, "Helvetica", 8)
        self.drawString((letter[0] - text_width) / 2, 20*mm, texto_sistema)

class GeneradorReportesPDF:
    """
    Generador de reportes PDF con diseño profesional estilo gubernamental mejorado
    VERSIÓN MEJORADA - Mantiene compatibilidad con versión anterior
    """
    
    def __init__(self):
        """Inicializar el generador de PDFs"""
        self.setup_directories()
        self.setup_logo()
    
    def setup_directories(self):
        """Crear directorios necesarios"""
        try:
            project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            self.assets_dir = os.path.join(project_dir, "assets")
            os.makedirs(self.assets_dir, exist_ok=True)
            
            home_dir = os.path.expanduser("~")
            self.pdf_dir = os.path.join(home_dir, "Documents", "Reportes_CMI")
            os.makedirs(self.pdf_dir, exist_ok=True)
            
            print(f"📁 Directorio de assets: {self.assets_dir}")
            print(f"📁 Directorio de reportes: {self.pdf_dir}")
            
        except Exception as e:
            print(f"⚠️ Error creando directorios: {e}")
            self.assets_dir = os.path.join(os.getcwd(), "assets")
            self.pdf_dir = os.path.join(os.getcwd(), "Reportes_CMI")
            os.makedirs(self.assets_dir, exist_ok=True)
            os.makedirs(self.pdf_dir, exist_ok=True)
    
    def setup_logo(self):
        """Configurar logo para PDF"""
        logo_path_directo = r"Resources/iconos/Logo_de_Emergencia_Médica_RGL-removebg-preview.png"
        current_dir = os.path.dirname(os.path.abspath(__file__))
        
        logo_paths = [
            logo_path_directo,
            os.path.join(current_dir, "..", "Resources", "iconos", "logo.png"),
            os.path.join(current_dir, "..", "Resources", "iconos", "logo_CMI.png"),
            os.path.join(current_dir, "..", "Resources", "iconos", "logo_CMI.svg"),
        ]
        
        self.logo_path = None
        for logo_path in logo_paths:
            if os.path.exists(logo_path):
                self.logo_path = logo_path
                print(f"✅ Logo encontrado: {logo_path}")
                break
        
        if not self.logo_path:
            print("⚠️ Logo no encontrado, usando logo profesional")
    
    def generar_reporte_pdf(self, datos_json, tipo_reporte, fecha_desde, fecha_hasta):
        """Método principal para generar un PDF del reporte"""
        try:
            print(f"📄 Iniciando generación de PDF profesional mejorado - Tipo: {tipo_reporte}")
            
            datos = json.loads(datos_json)
            tipo_reporte_int = int(tipo_reporte)
            
            filename = self._generar_nombre_archivo(tipo_reporte_int, fecha_desde, fecha_hasta)
            filepath = os.path.join(self.pdf_dir, filename)
            
            success = self._crear_pdf_profesional_mejorado(
                filepath, datos, tipo_reporte_int, fecha_desde, fecha_hasta
            )
            
            if success:
                print(f"✅ PDF profesional mejorado generado: {filepath}")
                return filepath
            else:
                print("⚠️ Error al generar PDF")
                return ""
                
        except Exception as e:
            print(f"⚠️ Error en generar_reporte_pdf: {e}")
            import traceback
            traceback.print_exc()
            return ""
    
    def _generar_nombre_archivo(self, tipo_reporte, fecha_desde, fecha_hasta):
        """Genera nombre único para el archivo PDF"""
        fecha_limpia_desde = fecha_desde.replace("/", "")
        fecha_limpia_hasta = fecha_hasta.replace("/", "")
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        nombre_tipo = self._obtener_nombre_tipo_reporte(tipo_reporte)
        filename = f"CMI_INFORME_{nombre_tipo}_{fecha_limpia_desde}_{fecha_limpia_hasta}_{timestamp}.pdf"
        
        return filename
    
    def _obtener_nombre_tipo_reporte(self, tipo_reporte):
        """Obtiene el nombre del tipo de reporte para el archivo (simplificado)"""
        tipos = {
            1: "VENTAS_FARMACIA",
            2: "INVENTARIO_FARMACIA", 
            3: "COMPRAS_FARMACIA",
            4: "CONSULTAS_MEDICAS",
            5: "LABORATORIO",
            6: "ENFERMERIA",
            7: "GASTOS_OPERATIVOS",
            8: "FINANCIERO_CONSOLIDADO"
        }
        return tipos.get(tipo_reporte, "GENERAL")
    
    def _obtener_modulo_reporte(self, tipo_reporte):
        """Obtiene el módulo del sistema para el reporte sin redundancia"""
        modulos = {
            1: "Farmacia - Ventas",
            2: "Farmacia - Inventario", 
            3: "Farmacia - Compras",
            4: "Consultas Médicas",
            5: "Laboratorio",
            6: "Enfermería",
            7: "Servicios Básicos",
            8: "Financiero Consolidado"
        }
        return modulos.get(tipo_reporte, "General")
    
    def _obtener_titulo_reporte(self, tipo_reporte):
        """Obtiene el título principal del reporte (simplificado para evitar redundancia)"""
        titulos = {
            1: "INFORME DE VENTAS",
            2: "INFORME DE INVENTARIO", 
            3: "INFORME DE COMPRAS",
            4: "INFORME DE CONSULTAS MÉDICAS",
            5: "INFORME DE ANÁLISIS DE LABORATORIO",
            6: "INFORME DE ENFERMERÍA",
            7: "INFORME DE GASTOS OPERATIVOS",
            8: "INFORME FINANCIERO CONSOLIDADO"
        }
        return titulos.get(tipo_reporte, "INFORME GENERAL")
    
    def _crear_pdf_profesional_mejorado(self, filepath, datos, tipo_reporte, fecha_desde, fecha_hasta):
        """Crea el archivo PDF con diseño profesional mejorado"""
        try:
            print(f"📊 Creando PDF: {filepath}")
            print(f"📊 Datos: {len(datos)} registros")
            
            # Crear documento con márgenes optimizados
            doc = BaseDocTemplate(
                filepath,
                pagesize=letter,
                rightMargin=20*mm,     # Reducido de 25mm
                leftMargin=20*mm,      # Reducido de 25mm  
                topMargin=50*mm,
                bottomMargin=45*mm
            )
            
            # Frame para el contenido
            frame = Frame(
                20*mm, 45*mm,                          # Ajustado a nuevos márgenes
                letter[0]-40*mm, letter[1]-95*mm,      # Ancho ajustado
                id='normal'
            )
            
            # Template de página profesional
            template = PageTemplate(
                id='todas_paginas',
                frames=[frame],
                onPage=self._crear_encabezado_profesional_mejorado,
                pagesize=letter
            )
            
            doc.addPageTemplates([template])
            
            # Información para el encabezado
            self._titulo_reporte = self._obtener_titulo_reporte(tipo_reporte)
            self._fecha_desde = fecha_desde
            self._fecha_hasta = fecha_hasta
            self._fecha_generacion = datetime.now().strftime("%d/%m/%Y %H:%M")
            self._tipo_reporte = tipo_reporte
            self._datos = datos
            
            # Story principal
            story = []
            
            print("📄 Construyendo contenido del PDF...")
            
            # Espaciador inicial para asegurar separación del encabezado
            story.append(Spacer(1, 4*mm))  # Reducido de 8mm a 4mm
            
            # Información del reporte (NO en tabla, estilo normal)
            print("📋 Agregando información del reporte...")
            info_elementos = self._crear_informacion_reporte_mejorada()
            story.extend(info_elementos)
            story.append(Spacer(1, 8*mm))  # Reducido de 12mm a 8mm
            
            # Contenido principal
            if datos and len(datos) > 0:
                print("📊 Agregando tabla principal...")
                story.append(self._crear_tabla_profesional_mejorada(datos, tipo_reporte))
                story.append(Spacer(1, 8*mm))
                
                # Análisis y conclusiones
                print("📝 Agregando análisis y conclusiones...")
                story.append(self._crear_analisis_conclusiones(datos))
            else:
                print("⚠️ No hay datos, agregando mensaje...")
                story.append(self._crear_mensaje_sin_datos())
            
            print(f"📄 Story completo con {len(story)} elementos")
            
            # Construir el PDF
            print("🔨 Construyendo PDF...")
            doc.build(story, canvasmaker=CanvasNumerosPaginaProfesional)
            
            print("✅ PDF creado exitosamente")
            return True
            
        except Exception as e:
            print(f"⚠️ Error creando PDF profesional mejorado: {e}")
            print(f"🔍 Error en tipo de reporte: {tipo_reporte}")
            print(f"🔍 Número de registros: {len(datos) if datos else 0}")
            import traceback
            traceback.print_exc()
            return False
    
    def _crear_encabezado_profesional_mejorado(self, canvas, doc):
        """Crea encabezado profesional mejorado con logo en posición correcta"""
        canvas.saveState()
        
        # Fondo blanco del encabezado (más compacto)
        canvas.setFillColor(colors.white)
        canvas.rect(0, letter[1]-40*mm, letter[0], 40*mm, fill=1, stroke=0)  # Reducido a 40mm de altura
        
        # Franja decorativa superior (roja)
        canvas.setFillColor(COLOR_ROJO_ACENTO)
        canvas.rect(0, letter[1]-6*mm, letter[0], 6*mm, fill=1, stroke=0)
        
        # LÍNEA AZUL en la parte inferior del encabezado
        canvas.setStrokeColor(COLOR_AZUL_PRINCIPAL)
        canvas.setLineWidth(3)
        canvas.line(0, letter[1]-40*mm, letter[0], letter[1]-40*mm)  # Ajustado a 40mm
        
        # Bordes laterales azules (ajustados)
        canvas.setLineWidth(2)
        canvas.line(0, letter[1]-40*mm, 0, letter[1]-6*mm)  # Izquierdo
        canvas.line(letter[0], letter[1]-40*mm, letter[0], letter[1]-6*mm)  # Derecho
        
        # Logo (POSICIÓN CORRECTA: lado izquierdo arriba, pegado al borde, tamaño grande)
        if self.logo_path and os.path.exists(self.logo_path):
            try:
                # Logo en (5mm desde izquierda, 5mm desde arriba del encabezado) -> y = página_alto - 40mm (inicio encabezado) + 5mm (margen interior) = página_alto - 35mm
                # Tamaño: 100mm de ancho, 30mm de alto
                canvas.drawImage(
                    self.logo_path, 
                    25*mm, letter[1]-45*mm,  # ← CAMBIO: 25mm igual que el margen del documento
                    width=120*mm, height=40*mm,
                    preserveAspectRatio=True,
                    mask='auto'
                )
            except:
                self._dibujar_logo_profesional(canvas, 25*mm, letter[1]-45*mm, 120*mm, 40*mm)
        else:
            self._dibujar_logo_profesional(canvas, 25*mm, letter[1]-45*mm, 120*mm, 40*mm)
        
        # Información institucional (lado derecho, ajustada para no interferir con logo)
        canvas.setFont("Helvetica-Bold", 14)
        canvas.setFillColor(COLOR_AZUL_PRINCIPAL)
        # Ajustar la posición vertical: más abajo para que no choque con el logo
        canvas.drawRightString(letter[0]-20*mm, letter[1]-20*mm, "CLÍNICA MARÍA INMACULADA")
        
        canvas.setFont("Helvetica", 11)
        canvas.setFillColor(COLOR_GRIS_OSCURO)
        canvas.drawRightString(letter[0]-20*mm, letter[1]-28*mm, "Atención Médica Integral")
        canvas.drawRightString(letter[0]-20*mm, letter[1]-35*mm, "Villa Yapacaní, Santa Cruz - Bolivia")
        
        canvas.restoreState()
    
    def _dibujar_logo_profesional(self, canvas, x, y, ancho, alto):
        """Dibuja logo profesional con tamaño y posición personalizados"""
        # Texto del logo en azul sobre fondo blanco
        canvas.setFillColor(COLOR_AZUL_PRINCIPAL)
        canvas.setFont("Helvetica-Bold", 28)
        canvas.drawCentredText(x + ancho/2, y + alto/2 + 10, "CMI")
        
        canvas.setFont("Helvetica", 14)
        canvas.drawCentredText(x + ancho/2, y + alto/2 - 5, "CLÍNICA MARÍA")
        canvas.drawCentredText(x + ancho/2, y + alto/2 - 20, "INMACULADA")
        
        # Marco decorativo azul
        canvas.setStrokeColor(COLOR_AZUL_PRINCIPAL)
        canvas.setLineWidth(2)
        canvas.rect(x, y, ancho, alto, fill=0, stroke=1)
    
    def _crear_informacion_reporte_mejorada(self):
        """Crea sección de información del reporte SIN tabla, estilo normal y sin redundancias"""
        try:
            styles = getSampleStyleSheet()
            
            # Estilo para el título específico del reporte (centrado)
            titulo_especifico_style = ParagraphStyle(
                'TituloEspecifico',
                parent=styles['Normal'],
                fontSize=16,
                fontName='Helvetica-Bold',
                textColor=COLOR_AZUL_PRINCIPAL,
                spaceAfter=12,
                alignment=TA_CENTER
            )
            
            # Estilo para la información (alineación mejorada)
            info_style = ParagraphStyle(
                'InfoReporte',
                parent=styles['Normal'],
                fontSize=11,
                fontName='Helvetica',
                textColor=COLOR_GRIS_OSCURO,
                spaceAfter=6,
                leftIndent=0,  # Sin indentación para mejor alineación
                alignment=TA_LEFT
            )
            
            # Crear contenido
            contenido = []
            
            # Título específico del tipo de reporte (centrado)
            titulo_reporte = self._obtener_titulo_reporte(self._tipo_reporte)
            contenido.append(Paragraph(titulo_reporte, titulo_especifico_style))
            
            # Información esencial (sin redundancias)
            contenido.append(Paragraph(f"<b>Período de Análisis:</b> {self._fecha_desde} al {self._fecha_hasta}", info_style))
            contenido.append(Paragraph(f"<b>Fecha de Generación:</b> {self._fecha_generacion}", info_style))
            contenido.append(Paragraph(f"<b>Responsable:</b> Sistema de Gestión Médica", info_style))
            
            print(f"📋 Información del reporte creada: {len(contenido)} elementos")
            return contenido
            
        except Exception as e:
            print(f"⚠️ Error creando información del reporte: {e}")
            # Retornar contenido básico en caso de error
            styles = getSampleStyleSheet()
            return [Paragraph("INFORMACIÓN DEL REPORTE", styles['Heading2'])]
        
    def _crear_tabla_profesional_mejorada(self, datos, tipo_reporte):
        """Crea tabla con TOTAL GENERAL visible en PDF - VERSIÓN CORREGIDA"""
        from reportlab.platypus import Table, TableStyle
        from reportlab.lib import colors
        
        # Obtener definición de columnas
        columnas_def = self._obtener_columnas_reporte(tipo_reporte)
        
        # Crear encabezados
        encabezados = [col[0] for col in columnas_def]
        anchos_columnas = [col[1]*mm for col in columnas_def]
        
        # Preparar datos
        tabla_datos = [encabezados]
        total_valor = 0
        
        # Agregar filas de datos
        for i, registro in enumerate(datos):
            fila = []
            for col_titulo, ancho, alineacion in columnas_def:
                valor = self._obtener_valor_campo(registro, col_titulo, tipo_reporte)
                fila.append(valor)
                
            tabla_datos.append(fila)
            
            # CÁLCULO DE TOTALES
            try:
                valor_monetario = 0
                if 'valor' in registro and registro['valor']:
                    valor_monetario = float(registro['valor'])
                elif 'Monto' in registro and registro['Monto']:
                    valor_monetario = float(registro['Monto'])
                elif 'Total' in registro and registro['Total']:
                    valor_monetario = float(registro['Total'])
                
                total_valor += valor_monetario
                
            except (ValueError, TypeError):
                continue
        
        # ==========================================
        # NUEVA LÓGICA SIMPLIFICADA PARA EL TOTAL
        # ==========================================
        
        print(f"🔍 DEBUG - Tipo reporte PDF: {tipo_reporte}")
        print(f"🔍 DEBUG - Columnas: {[col[0] for col in columnas_def]}")
        print(f"🔍 DEBUG - Total calculado: Bs {total_valor:,.2f}")
        
        # Crear fila de total inicializada vacía
        fila_total = [""] * len(columnas_def)
        
        # ENCONTRAR LA COLUMNA DE VALOR MONETARIO
        columna_valor_index = -1
        columna_descripcion_index = -1
        
        for i, (col_titulo, ancho, alineacion) in enumerate(columnas_def):
            if any(palabra in col_titulo.upper() for palabra in ["TOTAL", "MONTO", "PRECIO", "VALOR"]):
                columna_valor_index = i
                print(f"✅ Columna de valor encontrada en índice {i}: {col_titulo}")
            
            if "DESCRIPCIÓN" in col_titulo.upper():
                columna_descripcion_index = i
                print(f"✅ Columna de descripción encontrada en índice {i}")
        
        # ASIGNAR VALORES A LA FILA DE TOTAL
        if columna_valor_index != -1:
            fila_total[columna_valor_index] = f"Bs {total_valor:,.2f}"
            print(f"💰 Total asignado en columna {columna_valor_index}")
        
        # PARA GASTOS: "TOTAL GENERAL:" en DESCRIPCIÓN
        if tipo_reporte == 7 and columna_descripcion_index != -1:
            fila_total[columna_descripcion_index] = "TOTAL GENERAL:"
            print(f"📝 TOTAL GENERAL asignado en descripción para gastos")
        
        # PARA OTROS REPORTES: "TOTAL GENERAL:" en PENÚLTIMA columna (si no es la de valor)
        elif tipo_reporte != 7 and len(columnas_def) >= 2:
            penultima_columna = len(columnas_def) - 2
            if penultima_columna != columna_valor_index and penultima_columna >= 0:
                fila_total[penultima_columna] = "TOTAL GENERAL:"
                print(f"📝 TOTAL GENERAL asignado en penúltima columna {penultima_columna}")
        
        # Si no se pudo asignar en penúltima, usar la primera columna disponible
        elif tipo_reporte != 7 and columna_valor_index != -1 and columna_valor_index > 0:
            fila_total[columna_valor_index - 1] = "TOTAL GENERAL:"
            print(f"📝 TOTAL GENERAL asignado en columna anterior al valor")
        
        print(f"🔍 Fila de total final: {fila_total}")
        tabla_datos.append(fila_total)
        
        # ==========================================
        # CREAR TABLA CON MÁRGENES MEJORADOS
        # ==========================================
        
        # Calcular ancho total para centrado
        ancho_total = sum(anchos_columnas)
        margen_disponible = letter[0] - 40*mm  # Considerando márgenes de 20mm cada lado
        h_align = 'LEFT' if ancho_total > margen_disponible else 'CENTER'
        
        tabla = Table(
            tabla_datos, 
            colWidths=anchos_columnas, 
            repeatRows=1,
            splitByRow=1,
            spaceAfter=12,
            spaceBefore=12,
            hAlign=h_align
        )
        
        # ==========================================
        # ESTILOS MEJORADOS - EVITAR SOLAPAMIENTO
        # ==========================================
        
        estilos_tabla = [
            # Encabezado principal
            ('BACKGROUND', (0, 0), (-1, 0), COLOR_AZUL_PRINCIPAL),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 9),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('TOPPADDING', (0, 0), (-1, 0), 12),
            
            # Datos principales - ESPACIADO MEJORADO
            ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -2), 9),
            ('TOPPADDING', (0, 1), (-1, -2), 10),  # Reducido de 14 a 10
            ('BOTTOMPADDING', (0, 1), (-1, -2), 10), # Reducido de 14 a 10
            ('LEFTPADDING', (0, 1), (-1, -2), 6),   # Reducido de 8 a 6
            ('RIGHTPADDING', (0, 1), (-1, -2), 6),  # Reducido de 8 a 6
            ('VALIGN', (0, 1), (-1, -2), 'MIDDLE'),
            ('ROWHEIGHT', (0, 1), (-1, -2), 35),    # Reducido de 40 a 35
            
            # FILA DE TOTAL - ESTILO SIMPLIFICADO
            ('BACKGROUND', (0, -1), (-1, -1), COLOR_AZUL_PRINCIPAL),
            ('TEXTCOLOR', (0, -1), (-1, -1), colors.white),
            ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
            ('FONTSIZE', (0, -1), (-1, -1), 11),    # Reducido de 12 a 11
            ('TOPPADDING', (0, -1), (-1, -1), 8),   # Reducido
            ('BOTTOMPADDING', (0, -1), (-1, -1), 8), # Reducido
            
            # Configuración general
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('GRID', (0, 0), (-1, -2), 1, colors.black),  # Líneas más delgadas
            ('LINEBELOW', (0, 0), (-1, 0), 2, COLOR_AZUL_PRINCIPAL),
            ('LINEABOVE', (0, -1), (-1, -1), 2, COLOR_AZUL_PRINCIPAL),
            
            # Zebra striping más sutil
            ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, colors.HexColor(0xF5F5F5)]),
        ]
        
        # Aplicar alineaciones específicas por columna
        for col_idx, (col_titulo, ancho, alineacion) in enumerate(columnas_def):
            align_map = {'LEFT': 'LEFT', 'RIGHT': 'RIGHT', 'CENTER': 'CENTER'}
            tabla_align = align_map.get(alineacion, 'LEFT')
            
            # Alineación para datos normales
            estilos_tabla.append(('ALIGN', (col_idx, 1), (col_idx, -2), tabla_align))
            
            # Alineación especial para fila de total
            if col_idx == columna_valor_index:
                estilos_tabla.append(('ALIGN', (col_idx, -1), (col_idx, -1), 'RIGHT'))
            elif (tipo_reporte == 7 and col_idx == columna_descripcion_index) or \
                (tipo_reporte != 7 and col_idx == len(columnas_def) - 2):
                estilos_tabla.append(('ALIGN', (col_idx, -1), (col_idx, -1), 'RIGHT'))
            else:
                estilos_tabla.append(('ALIGN', (col_idx, -1), (col_idx, -1), 'CENTER'))
        
        # Aplicar estilos
        tabla.setStyle(TableStyle(estilos_tabla))
        
        print(f"✅ Tabla PDF creada exitosamente: {len(datos)} filas + total")
        
        return tabla


    def _crear_analisis_conclusiones(self, datos):
        """Crea sección de análisis simple como antes"""
        try:
            # Cálculo básico de totales
            total_valor = sum(float(item.get('valor', 0)) for item in datos)
            total_registros = len(datos)
            
            conclusion_text = f"""
            <b>ANÁLISIS Y CONCLUSIONES:</b><br/>
            
            El presente informe presenta el análisis de {total_registros} registros correspondientes al período establecido. 
            El valor total procesado asciende a Bs {total_valor:,.2f}.<br/>
            
            <b>Observaciones:</b> Los datos han sido procesados y validados por el sistema. 
            El informe refleja la situación al momento de la generación. 
            Todos los valores están expresados en Bolivianos (Bs).<br/>
            
            <b>Estado:</b> INFORME COMPLETADO - DOCUMENTO OFICIAL
            """
            
            styles = getSampleStyleSheet()
            conclusion_style = ParagraphStyle(
                'Conclusion',
                parent=styles['Normal'],
                fontSize=9,
                spaceAfter=6,
                alignment=TA_JUSTIFY,
                leftIndent=8,
                rightIndent=8
            )
            
            return Paragraph(conclusion_text, conclusion_style)
            
        except Exception as e:
            print(f"Error creando análisis: {e}")
            # Retornar párrafo simple en caso de error
            styles = getSampleStyleSheet()
            return Paragraph("Análisis completado.", styles['Normal'])
    
    def _crear_mensaje_sin_datos(self):
        """Crea mensaje cuando no hay datos"""
        styles = getSampleStyleSheet()
        sin_datos_style = ParagraphStyle(
            'SinDatos',
            parent=styles['Normal'],
            fontSize=12,
            spaceAfter=20*mm,
            alignment=TA_CENTER,
            textColor=COLOR_GRIS_OSCURO
        )
        
        mensaje = """
        <b>INFORME SIN DATOS</b><br/><br/>
        No se encontraron registros para el período seleccionado.<br/>
        Verifique los criterios de búsqueda y el rango de fechas.
        """
        
        return Paragraph(mensaje, sin_datos_style)
            
    def _obtener_columnas_reporte(self, tipo_reporte):
        """Define las columnas con TÍTULOS CORTOS Y ANCHOS OPTIMIZADOS"""
        columnas = {
            1: [  # Ventas de Farmacia
                ("FECHA", 22, 'LEFT'),
                ("Nº VENTA", 22, 'LEFT'), 
                ("DESCRIPCIÓN", 55, 'LEFT'),
                ("CANTIDAD", 18, 'RIGHT'),
                ("TOTAL (Bs)", 25, 'RIGHT')
            ],
            2: [  # Inventario de Productos - ✅ TÍTULOS CORTOS
                ("FECHA", 18, 'LEFT'),
                ("PRODUCTO", 40, 'LEFT'),      # Reducido para dar más espacio
                ("MARCA", 20, 'LEFT'),         # Reducido
                ("STOCK", 16, 'RIGHT'),        # Más pequeño
                ("LOTES", 12, 'CENTER'),       # Más pequeño
                ("P.UNIT", 20, 'RIGHT'),       # ✅ SIN PUNTO y más corto
                ("F.VENC", 20, 'LEFT'),        # ✅ SIN PUNTO y más corto
                ("VALOR (Bs)", 24, 'RIGHT')    # ✅ Título corto
            ],
            3: [  # Compras de Farmacia - ✅ TÍTULOS OPTIMIZADOS
                ("FECHA", 18, 'LEFT'),          
                ("PRODUCTO", 30, 'LEFT'),       # Reducido
                ("MARCA", 16, 'LEFT'),          # Reducido
                ("UNID.", 12, 'RIGHT'),         # Más pequeño
                ("PROVEEDOR", 20, 'LEFT'),      # Reducido
                ("F.VENC", 16, 'LEFT'),         # ✅ Título corto
                ("USUARIO", 16, 'LEFT'),        # Reducido
                ("TOTAL (Bs)", 16, 'RIGHT')     # Reducido
            ],
            4: [  # Consultas Médicas - ✅ TÍTULOS OPTIMIZADOS
                ("FECHA", 22, 'LEFT'),
                ("ESPECIALIDAD", 32, 'LEFT'),   # Reducido
                ("DESCRIPCIÓN", 50, 'LEFT'),    # Reducido
                ("PACIENTE", 32, 'LEFT'),       # Reducido
                ("MÉDICO", 32, 'LEFT'),         # Reducido
                ("PRECIO (Bs)", 26, 'RIGHT')    # Reducido
            ],
            5: [  # Laboratorio - ✅ TÍTULOS OPTIMIZADOS
                ("FECHA", 20, 'LEFT'),
                ("TIPO ANÁLISIS", 30, 'LEFT'),  # Reducido
                ("DESCRIPCIÓN", 50, 'LEFT'),    # Reducido
                ("PACIENTE", 30, 'LEFT'),       # Reducido
                ("TÉCNICO", 30, 'LEFT'),        # Reducido
                ("PRECIO (Bs)", 26, 'RIGHT')    # Reducido
            ],
            6: [  # Enfermería - ✅ TÍTULOS OPTIMIZADOS
                ("FECHA", 20, 'LEFT'),
                ("TIPO PROC.", 30, 'LEFT'),     # ✅ Título muy corto
                ("DESCRIPCIÓN", 50, 'LEFT'),    # Reducido
                ("PACIENTE", 30, 'LEFT'),       # Reducido
                ("ENFERMERO/A", 30, 'LEFT'),    # Reducido
                ("PRECIO (Bs)", 26, 'RIGHT')    # Reducido
            ],
            7: [  # Gastos Operativos - ✅ TÍTULOS OPTIMIZADOS
                ("FECHA", 22, 'LEFT'),
                ("TIPO GASTO", 30, 'LEFT'),     # ✅ Título corto (sin "DE")
                ("DESCRIPCIÓN", 50, 'LEFT'),    # Reducido
                ("MONTO (Bs)", 26, 'RIGHT'),    # Reducido
                ("PROVEEDOR", 30, 'LEFT')       # Reducido
            ],
            8: [  # Consolidado
                ("FECHA", 20, 'LEFT'),
                ("TIPO", 22, 'CENTER'),
                ("DESCRIPCIÓN", 50, 'LEFT'),    # Reducido
                ("CANTIDAD", 18, 'RIGHT'),
                ("VALOR (Bs)", 26, 'RIGHT')     # Reducido
            ]
        }
        return columnas.get(tipo_reporte, [
            ("FECHA", 25, 'LEFT'),
            ("DESCRIPCIÓN", 70, 'LEFT'),        # Reducido
            ("CANTIDAD", 20, 'RIGHT'),
            ("VALOR (Bs)", 26, 'RIGHT')         # Reducido
        ])

    def _obtener_valor_campo(self, registro, campo_titulo, tipo_reporte):
        """Extrae valores con MAPEO ACTUALIZADO para títulos cortos"""
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.platypus import Paragraph
        from reportlab.lib.enums import TA_LEFT
        
        # ✅ MAPEO ACTUALIZADO CON TÍTULOS CORTOS
        mapeo_campos = {
            # CAMPOS BÁSICOS
            "FECHA": "fecha",
            "DESCRIPCIÓN": "descripcion",
            "CANTIDAD": "cantidad",
            
            # VALORES MONETARIOS
            "PRECIO (Bs)": "valor",
            "TOTAL (Bs)": "valor", 
            "VALOR (Bs)": "valor",          # ✅ Nuevo título corto
            "MONTO (Bs)": "valor",
            
            # VENTAS
            "Nº VENTA": "numeroVenta",
            
            # INVENTARIO - ✅ NUEVOS TÍTULOS CORTOS
            "PRODUCTO": "descripcion",
            "STOCK": "cantidad",
            "P.UNIT": "precioUnitario",      # ✅ Sin punto
            "F.VENC": "fecha_vencimiento",   # ✅ Sin punto
            "LOTES": "lotes",
            
            # COMPRAS
            "Nº COMPRA": "numeroCompra",
            "MARCA": "marca",
            "UNID.": "cantidad",
            "PROVEEDOR": "proveedor",
            "USUARIO": "usuario",
            
            # CONSULTAS
            "ESPECIALIDAD": "especialidad",
            "PACIENTE": "paciente",
            "MÉDICO": "doctor_nombre",
            
            # LABORATORIO
            "TIPO ANÁLISIS": "tipoAnalisis",
            "TÉCNICO": "tecnico",
            
            # ENFERMERÍA
            "TIPO PROC.": "tipoProcedimiento",   # ✅ Título corto
            "ENFERMERO/A": "enfermero",
            
            # GASTOS
            "TIPO GASTO": "categoria",           # ✅ Sin "DE"
            
            # CONSOLIDADO
            "TIPO": "tipo",
        }
        
        campo_dato = mapeo_campos.get(campo_titulo, campo_titulo.lower())
        valor = registro.get(campo_dato, "")
        valor = str(valor) if valor else ""

        def crear_parrafo(texto):
            if not texto or len(str(texto).strip()) == 0:
                return ""
            styles = getSampleStyleSheet()
            style = ParagraphStyle(
                'CellParagraph',
                parent=styles['Normal'],
                fontSize=8,
                leading=9,
                alignment=TA_LEFT,
                wordWrap='LTR',
                splitLongWords=True
            )
            return Paragraph(str(texto), style)

        # ✅ PROCESAMIENTO ACTUALIZADO PARA TÍTULOS CORTOS

        # 1. Campos monetarios
        if any(palabra in campo_titulo.upper() for palabra in ["PRECIO", "TOTAL", "VALOR", "MONTO"]):
            try:
                return f"Bs {float(valor):,.2f}"
            except:
                return "Bs 0.00"
        
        # 2. Campos numéricos
        elif campo_titulo in ["CANTIDAD", "STOCK", "UNID.", "LOTES"]:
            try:
                if valor == "" or valor is None or str(valor).strip() == "":
                    return "0"
                valor_num = float(valor)
                return f"{int(valor_num):,}"
            except:
                return "0"
            
        # 3. Precio unitario (nuevo título corto)
        elif campo_titulo == "P.UNIT":  # ✅ Sin punto
            try:
                return f"Bs {float(valor):,.2f}"
            except:
                return "Bs 0.00"
        
        # 4. Fecha de vencimiento (nuevo título corto)
        elif campo_titulo == "F.VENC":  # ✅ Sin punto
            if not valor or valor in ["", "None", "null"]:
                return "Sin venc."
            return valor
        
        # 5. Campos con nombres largos (usar Paragraph para texto largo)
        elif campo_titulo in ["PACIENTE", "MÉDICO", "TÉCNICO", "ENFERMERO/A"]:
            if not valor:
                defaults = {
                    "PACIENTE": "Paciente",
                    "MÉDICO": "Sin médico",
                    "TÉCNICO": "Sin asignar", 
                    "ENFERMERO/A": "Sin asignar"
                }
                valor = defaults.get(campo_titulo, "Sin asignar")
            return crear_parrafo(valor)
        
        # 6. Descripciones (usar Paragraph)
        elif campo_titulo in ["DESCRIPCIÓN", "PRODUCTO"]:
            if not valor:
                valor = "Sin detalles"
            return crear_parrafo(valor)
        
        # 7. Campos medianos
        elif campo_titulo in ["ESPECIALIDAD", "TIPO GASTO", "TIPO ANÁLISIS", "TIPO PROC."]:  # ✅ Incluir nuevos títulos
            if not valor:
                if campo_titulo == "TIPO GASTO":
                    valor = registro.get('tipo_nombre', 'General')
                else:
                    valor = "General"
            
            if len(valor) > 15:  # Reducido de 18 a 15 por columnas más pequeñas
                return crear_parrafo(valor)
            return valor
        
        # 8. Otros campos
        elif campo_titulo == "MARCA":
            if not valor:
                valor = "Sin marca"
            if len(valor) > 10:  # Reducido por columna más pequeña
                return crear_parrafo(valor)
            return valor
        
        elif campo_titulo == "PROVEEDOR":
            if not valor:
                valor = "Sin proveedor"
            if len(valor) > 12:  # Reducido por columna más pequeña
                return crear_parrafo(valor)
            return valor
        
        elif campo_titulo == "USUARIO":
            if not valor:
                valor = "Sin usuario"
            if len(valor) > 10:  # Reducido por columna más pequeña
                return crear_parrafo(valor)
            return valor
        
        # 9. Campos simples
        elif campo_titulo == "FECHA":
            return valor if valor else "---"
        elif campo_titulo in ["Nº VENTA", "Nº COMPRA"]:
            if not valor:
                prefijo = "V" if "VENTA" in campo_titulo else "C"
                valor = f"{prefijo}{registro.get('id', '001'):03d}"
            return valor
        elif campo_titulo == "TIPO":
            return valor if valor else "Normal"
        
        # 10. Genérico
        if not valor:
            return "---"
        
        if len(str(valor)) > 20:  # Reducido de 25 a 20 por columnas más pequeñas
            return crear_parrafo(str(valor))
        
        return str(valor)
    
# Funciones de utilidad
def crear_generador_pdf():
    """Función factoría para crear una instancia del generador de PDFs"""
    return GeneradorReportesPDF()

def generar_pdf_reporte(datos_json, tipo_reporte, fecha_desde, fecha_hasta):
    """Función de conveniencia para generar un PDF directamente"""
    generador = GeneradorReportesPDF()
    return generador.generar_reporte_pdf(datos_json, tipo_reporte, fecha_desde, fecha_hasta)