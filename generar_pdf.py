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
            5: "INFORME DE LABORATORIO",
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
                rightMargin=25*mm,
                leftMargin=25*mm,
                topMargin=50*mm,  # Reducido de 55mm a 50mm
                bottomMargin=45*mm
            )
            
            # Frame para el contenido
            frame = Frame(
                25*mm, 45*mm, 
                letter[0]-50*mm, letter[1]-95*mm,  # Ajustado para nuevo topMargin
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
        """Crea tabla principal con diseño profesional mejorado"""
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
            
            # Sumar valores
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
        
        # Estilos profesionales mejorados
        estilos_tabla = [
            # Encabezado principal (cambio de negro a azul)
            ('BACKGROUND', (0, 0), (-1, 0), COLOR_AZUL_PRINCIPAL),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 10),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
            ('TOPPADDING', (0, 0), (-1, 0), 8),
            
            # Datos principales
            ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -2), 9),
            ('TOPPADDING', (0, 1), (-1, -2), 5),
            ('BOTTOMPADDING', (0, 1), (-1, -2), 5),
            ('LEFTPADDING', (0, 1), (-1, -2), 6),
            ('RIGHTPADDING', (0, 1), (-1, -2), 6),
            
            # Fila de total (SIN LÍNEAS como solicitaste)
            ('BACKGROUND', (0, -1), (-1, -1), COLOR_AZUL_PRINCIPAL),  # Cambio a azul
            ('TEXTCOLOR', (0, -1), (-1, -1), colors.white),
            ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
            ('FONTSIZE', (0, -1), (-1, -1), 10),
            ('TOPPADDING', (0, -1), (-1, -1), 6),
            ('BOTTOMPADDING', (0, -1), (-1, -1), 6),
            ('ALIGN', (-2, -1), (-1, -1), 'RIGHT'),
            
            # Bordes profesionales (solo para datos, no para total)
            ('GRID', (0, 0), (-1, -2), 1, COLOR_AZUL_PRINCIPAL),
            ('LINEBELOW', (0, 0), (-1, 0), 2, COLOR_AZUL_PRINCIPAL),
        ]
        
        # Zebra striping profesional
        for i in range(1, len(tabla_datos) - 1):
            if i % 2 == 0:
                estilos_tabla.append(('BACKGROUND', (0, i), (-1, i), COLOR_AZUL_CLARO))
        
        # Aplicar alineaciones específicas
        for col_idx, (col_titulo, ancho, alineacion) in enumerate(columnas_def):
            align_map = {'LEFT': 'LEFT', 'RIGHT': 'RIGHT', 'CENTER': 'CENTER'}
            tabla_align = align_map.get(alineacion, 'LEFT')
            estilos_tabla.append(('ALIGN', (col_idx, 1), (col_idx, -2), tabla_align))
        
        tabla.setStyle(TableStyle(estilos_tabla))
        return tabla
    
    def _crear_analisis_conclusiones(self, datos):
        """Crea sección de análisis y conclusiones compacta"""
        try:
            # Análisis automático básico
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
            print(f"⚠️ Error creando análisis: {e}")
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
        """Define las columnas para cada tipo de reporte"""
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
        
        # Truncar texto largo
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