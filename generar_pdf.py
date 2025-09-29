"""
Módulo para generar reportes PDF profesionales - VERSIÓN MEJORADA CON REPORTE DE INGRESOS Y EGRESOS
Sistema de Gestión Médica - Clínica María Inmaculada
Versión 4.2 - Reporte Financiero Mejorado y Comprensible
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
COLOR_NARANJA_EGRESO = colors.Color(0.8, 0.4, 0.1)     # Naranja para egresos

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
    Generador de reportes PDF con diseño profesional mejorado
    INCLUYE: Reporte de Ingresos y Egresos profesional y comprensible
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
        """Obtiene el nombre del tipo de reporte para el archivo"""
        tipos = {
            1: "VENTAS_FARMACIA",
            2: "INVENTARIO_FARMACIA", 
            3: "COMPRAS_FARMACIA",
            4: "CONSULTAS_MEDICAS",
            5: "LABORATORIO",
            6: "ENFERMERIA",
            7: "GASTOS_OPERATIVOS",
            8: "INGRESOS_EGRESOS",
            9: "ARQUEO_CAJA"
        }
        return tipos.get(tipo_reporte, "GENERAL")
    
    def _obtener_modulo_reporte(self, tipo_reporte):
        """Obtiene el módulo del sistema para el reporte"""
        modulos = {
            1: "Farmacia - Ventas",
            2: "Farmacia - Inventario", 
            3: "Farmacia - Compras",
            4: "Consultas Médicas",
            5: "Laboratorio",
            6: "Enfermería",
            7: "Servicios Básicos",
            8: "Análisis Financiero",  # 📄 CAMBIO: Nuevo módulo para consolidado
            9: "Cierre de Caja"
        }
        return modulos.get(tipo_reporte, "General")
    
    def _obtener_titulo_reporte(self, tipo_reporte):
        """Obtiene el título principal del reporte"""
        titulos = {
            1: "INFORME DE VENTAS",
            2: "INFORME DE INVENTARIO", 
            3: "INFORME DE COMPRAS",
            4: "INFORME DE CONSULTAS MÉDICAS",
            5: "INFORME DE ANÁLISIS DE LABORATORIO",
            6: "INFORME DE ENFERMERÍA",
            7: "INFORME DE GASTOS OPERATIVOS",
            8: "REPORTE DE INGRESOS Y EGRESOS",
            9: "ARQUEO DE CAJA DETALLADO"
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
                rightMargin=20*mm,
                leftMargin=20*mm,  
                topMargin=50*mm,
                bottomMargin=45*mm
            )
            
            # Frame para el contenido
            frame = Frame(
                20*mm, 45*mm,
                letter[0]-40*mm, letter[1]-95*mm,
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
            
            # Espaciador inicial
            story.append(Spacer(1, 4*mm))
            
            # ✅ TRATAMIENTO ESPECIAL PARA REPORTE DE INGRESOS Y EGRESOS
            if tipo_reporte == 8:
                print("💰 Generando Reporte de Ingresos y Egresos profesional...")
                story.extend(self._crear_reporte_ingresos_egresos_completo(datos, fecha_desde, fecha_hasta))
            elif tipo_reporte == 9:
                print("💰 Generando Arqueo de Caja detallado...")
                story.extend(self._crear_arqueo_caja_completo(datos, fecha_desde, fecha_hasta))
            else:
                # Información del reporte estándar
                print("📋 Agregando información del reporte...")
                info_elementos = self._crear_informacion_reporte_mejorada()
                story.extend(info_elementos)
                story.append(Spacer(1, 8*mm))
                
                # Contenido principal estándar
                if datos and len(datos) > 0:
                    print("📊 Agregando tabla principal...")
                    story.append(self._crear_tabla_profesional_mejorada(datos, tipo_reporte))
                    story.append(Spacer(1, 8*mm))
                    
                    # Análisis y conclusiones estándar
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

    def _crear_reporte_ingresos_egresos_completo(self, datos, fecha_desde, fecha_hasta):
        """
        ✅ NUEVO: Crea un reporte completo de Ingresos y Egresos con estructura profesional
        Incluye: Resumen, Detalle por categorías, Análisis y Estado final
        """
        elementos = []
        
        try:
            # 1. TÍTULO PRINCIPAL
            elementos.extend(self._crear_titulo_ingresos_egresos())
            
            
            # 2. DETALLE DE INGRESOS Y EGRESOS
            elementos.extend(self._crear_detalle_ingresos_egresos(datos))
            elementos.append(Spacer(1, 8*mm))
            
            # 3. TABLA PRINCIPAL CON TODOS LOS MOVIMIENTOS
            elementos.append(self._crear_tabla_movimientos_financieros(datos))
            elementos.append(Spacer(1, 8*mm))
            
            # 4. ANÁLISIS Y CONCLUSIONES FINANCIERAS
            elementos.extend(self._crear_analisis_financiero_profesional(datos))
            elementos.append(Spacer(1, 8*mm))
            
            print("✅ Reporte de Ingresos y Egresos completo creado")
            return elementos
            
        except Exception as e:
            print(f"⚠️ Error creando reporte de ingresos y egresos: {e}")
            import traceback
            traceback.print_exc()
            return [self._crear_mensaje_error()]

    def _crear_titulo_ingresos_egresos(self):
        """Crea título principal para reporte de ingresos y egresos - CORREGIDO"""
        try:
            styles = getSampleStyleSheet()
            
            titulo_style = ParagraphStyle(
                'TituloIngresosEgresos',
                parent=styles['Normal'],
                fontSize=18,
                fontName='Helvetica-Bold',
                textColor=COLOR_AZUL_PRINCIPAL,
                spaceAfter=16,
                alignment=TA_CENTER,
                borderWidth=2,
                borderColor=COLOR_AZUL_PRINCIPAL,
                borderPadding=8
            )
            
            subtitulo_style = ParagraphStyle(
                'SubtituloIngresosEgresos',
                parent=styles['Normal'],
                fontSize=12,
                fontName='Helvetica',
                textColor=COLOR_GRIS_OSCURO,
                spaceAfter=12,
                alignment=TA_CENTER
            )
            
            return [
                Paragraph("REPORTE DE INGRESOS Y EGRESOS", titulo_style),
                Paragraph(f"Período: {self._fecha_desde} al {self._fecha_hasta}", subtitulo_style),
                Spacer(1, 6*mm)
            ]
            
        except Exception as e:
            print(f"Error creando título: {e}")
            return []

    def _crear_detalle_ingresos_egresos(self, datos):
        """Crea detalle separado de ingresos y egresos por categorías - NUMERACIÓN CORREGIDA"""
        try:
            styles = getSampleStyleSheet()
            
            titulo_detalle_style = ParagraphStyle(
                'TituloDetalle',
                parent=styles['Normal'],
                fontSize=14,
                fontName='Helvetica-Bold',
                textColor=COLOR_AZUL_PRINCIPAL,
                spaceAfter=8,
                alignment=TA_LEFT,
                leftIndent=2*mm
            )
            
            # Separar ingresos y egresos
            ingresos, egresos = self._separar_ingresos_egresos(datos)
            
            elementos = []
            
            # ✅ CAMBIO: Numeración corregida - empieza en 1
            elementos.append(Paragraph("1. DETALLE DE INGRESOS Y EGRESOS", titulo_detalle_style))
            
            # TABLA DE INGRESOS
            elementos.append(Paragraph("1.1 DETALLE DE INGRESOS", titulo_detalle_style))
            if ingresos:
                tabla_ingresos = self._crear_tabla_categoria_financiera(ingresos, "INGRESOS", COLOR_VERDE_POSITIVO)
                elementos.append(tabla_ingresos)
            else:
                elementos.append(Paragraph("No se registraron ingresos en el período analizado.", styles['Normal']))
            
            elementos.append(Spacer(1, 6*mm))
            
            # TABLA DE EGRESOS
            elementos.append(Paragraph("1.2 DETALLE DE EGRESOS", titulo_detalle_style))
            if egresos:
                tabla_egresos = self._crear_tabla_categoria_financiera(egresos, "EGRESOS", COLOR_NARANJA_EGRESO)
                elementos.append(tabla_egresos)
            else:
                elementos.append(Paragraph("No se registraron egresos en el período analizado.", styles['Normal']))
            
            return elementos
            
        except Exception as e:
            print(f"Error creando detalle de ingresos y egresos: {e}")
            return []

    def _crear_tabla_categoria_financiera(self, datos_categoria, tipo_categoria, color_header):
        """Crea tabla específica para una categoría financiera - ANCHOS CORREGIDOS"""
        try:
            # Preparar datos de la tabla
            encabezados = ["CATEGORÍA", "CANTIDAD\nOPERACIONES", "VALOR TOTAL (Bs)", "PORCENTAJE"]
            tabla_datos = [encabezados]
            
            # Agrupar por descripción/categoría
            categorias_agrupadas = {}
            total_categoria = 0
            
            for item in datos_categoria:
                descripcion = item.get('descripcion', 'Sin categoría')
                valor = abs(float(item.get('valor', 0)))  # Usar valor absoluto para mostrar positivo
                cantidad = int(item.get('cantidad', 1))
                
                if descripcion not in categorias_agrupadas:
                    categorias_agrupadas[descripcion] = {'valor': 0, 'cantidad': 0}
                
                categorias_agrupadas[descripcion]['valor'] += valor
                categorias_agrupadas[descripcion]['cantidad'] += cantidad
                total_categoria += valor
            
            # Agregar filas de datos
            for descripcion, datos_cat in categorias_agrupadas.items():
                porcentaje = (datos_cat['valor'] / total_categoria * 100) if total_categoria > 0 else 0
                
                fila = [
                    descripcion,
                    f"{datos_cat['cantidad']:,}",
                    f"Bs {datos_cat['valor']:,.2f}",
                    f"{porcentaje:.1f}%"
                ]
                tabla_datos.append(fila)
            
            # Fila de total
            fila_total = [
                f"TOTAL {tipo_categoria}",
                f"{sum(cat['cantidad'] for cat in categorias_agrupadas.values()):,}",
                f"Bs {total_categoria:,.2f}",
                "100.0%"
            ]
            tabla_datos.append(fila_total)
            
            # ✅ CAMBIO CRÍTICO: ANCHOS REDUCIDOS PARA EVITAR SUPERPOSICIÓN
            tabla = Table(
                tabla_datos,
                colWidths=[70*mm, 25*mm, 30*mm, 20*mm],  # ✅ REDUCIDOS: antes era 85,30,35,25
                repeatRows=1,
                hAlign='CENTER'
            )
            
            # Estilos de la tabla
            estilos = [
                # Encabezado
                ('BACKGROUND', (0, 0), (-1, 0), color_header),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 9),  # ✅ REDUCIDO: antes era 10
                ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
                
                # Datos
                ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
                ('FONTSIZE', (0, 1), (-1, -2), 8),  # ✅ REDUCIDO: antes era 9
                ('ALIGN', (1, 1), (-1, -1), 'RIGHT'),  # Alinear números a la derecha
                ('ALIGN', (0, 1), (0, -2), 'LEFT'),    # Categorías a la izquierda
                
                # Fila de total
                ('BACKGROUND', (0, -1), (-1, -1), COLOR_GRIS_CLARO),
                ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
                ('FONTSIZE', (0, -1), (-1, -1), 9),  # ✅ REDUCIDO: antes era 10
                ('TEXTCOLOR', (0, -1), (-1, -1), COLOR_GRIS_OSCURO),
                
                # Bordes y formato general
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, COLOR_GRIS_CLARO]),
            ]
            
            tabla.setStyle(TableStyle(estilos))
            
            return tabla
            
        except Exception as e:
            print(f"Error creando tabla de categoría financiera: {e}")
            # Retornar tabla básica en caso de error
            return Table([["Error", "creando", "tabla", "financiera"]], hAlign='CENTER')

    def _crear_tabla_movimientos_financieros(self, datos):
        """Crea tabla principal con todos los movimientos financieros - ANCHOS CORREGIDOS"""
        try:
            # Preparar datos
            encabezados = ["FECHA", "TIPO", "DESCRIPCIÓN", "CANT", "VALOR (Bs)"]
            tabla_datos = [encabezados]
            
            total_general = 0
            
            # Agregar filas de datos
            for item in datos:
                fecha = item.get('fecha', 'Sin fecha')
                tipo = item.get('tipo', 'Sin tipo')
                descripcion = item.get('descripcion', 'Sin descripción')
                cantidad = str(item.get('cantidad', 1))
                valor = float(item.get('valor', 0))
                
                # Formatear valor con signo
                if tipo == 'INGRESO':
                    valor_formateado = f"+Bs {abs(valor):,.2f}"
                else:
                    valor_formateado = f"-Bs {abs(valor):,.2f}"
                
                fila = [fecha, tipo, descripcion, cantidad, valor_formateado]
                tabla_datos.append(fila)
                total_general += valor
            
            # Fila de total
            signo = "+" if total_general >= 0 else ""
            fila_total = [
                "",
                "",
                "SALDO NETO DEL PERÍODO",
                "",
                f"{signo}Bs {total_general:,.2f}"
            ]
            tabla_datos.append(fila_total)
            
            # ✅ CAMBIO CRÍTICO: ANCHOS AJUSTADOS PARA EVITAR DESBORDAMIENTO
            tabla = Table(
                tabla_datos,
                colWidths=[22*mm, 22*mm, 70*mm, 18*mm, 28*mm],  # ✅ REDUCIDOS: antes era 25,25,85,20,30
                repeatRows=1,
                hAlign='CENTER'
            )
            
            # Estilos
            estilos = [
                # Encabezado
                ('BACKGROUND', (0, 0), (-1, 0), COLOR_AZUL_PRINCIPAL),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 8),  # ✅ REDUCIDO: antes era 9
                ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
                
                # Datos
                ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
                ('FONTSIZE', (0, 1), (-1, -2), 7),  # ✅ REDUCIDO: antes era 8
                ('ALIGN', (3, 1), (-1, -1), 'RIGHT'),  # Cantidad y valor a la derecha
                
                # Fila de total
                ('BACKGROUND', (0, -1), (-1, -1), COLOR_AZUL_PRINCIPAL),
                ('TEXTCOLOR', (0, -1), (-1, -1), colors.white),
                ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
                ('FONTSIZE', (0, -1), (-1, -1), 9),  # ✅ REDUCIDO: antes era 10
                ('ALIGN', (0, -1), (-1, -1), 'RIGHT'),
                ('SPAN', (0, -1), (2, -1)),  # Combinar celdas para "SALDO NETO"
                
                # Bordes
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, COLOR_GRIS_CLARO]),
            ]
            
            tabla.setStyle(TableStyle(estilos))
            
            return tabla
            
        except Exception as e:
            print(f"Error creando tabla de movimientos: {e}")
            return Table([["Error", "creando", "tabla", "de", "movimientos"]], hAlign='CENTER')

    def _crear_analisis_financiero_profesional(self, datos):
        """Crea análisis y conclusiones financieras profesionales - NUMERACIÓN CORREGIDA"""
        try:
            styles = getSampleStyleSheet()
            
            titulo_analisis_style = ParagraphStyle(
                'TituloAnalisis',
                parent=styles['Normal'],
                fontSize=14,
                fontName='Helvetica-Bold',
                textColor=COLOR_AZUL_PRINCIPAL,
                spaceAfter=8,
                alignment=TA_LEFT,
                leftIndent=2*mm
            )
            
            analisis_style = ParagraphStyle(
                'AnalisisFinanciero',
                parent=styles['Normal'],
                fontSize=11,
                fontName='Helvetica',
                spaceAfter=8,
                alignment=TA_JUSTIFY,
                leftIndent=4*mm,
                rightIndent=4*mm,
                bulletIndent=6*mm
            )
            
            # Calcular métricas
            totales = self._calcular_totales_financieros(datos)
            ingresos, egresos = self._separar_ingresos_egresos(datos)
            
            elementos = []
            
            # ✅ CAMBIO: Numeración corregida - ahora es sección 2
            elementos.append(Paragraph("2. ANÁLISIS Y CONCLUSIONES FINANCIERAS", titulo_analisis_style))
            
            # Análisis de cobertura
            if totales['total_egresos'] > 0:
                cobertura = (totales['total_ingresos'] / totales['total_egresos']) * 100
            else:
                cobertura = 100
            
            if cobertura >= 100:
                cobertura_texto = f"""
                <b>✓ Análisis de Cobertura:</b> Los ingresos del período cubren completamente 
                los gastos operativos ({cobertura:.1f}% de cobertura). La institución muestra 
                una gestión financiera saludable durante el período analizado.
                """
            else:
                cobertura_texto = f"""
                <b>⚠ Análisis de Cobertura:</b> Los ingresos del período NO cubren completamente 
                los gastos operativos ({cobertura:.1f}% de cobertura). Se requiere atención 
                inmediata para equilibrar las finanzas institucionales.
                """
            
            elementos.append(Paragraph(cobertura_texto, analisis_style))
            
            # Análisis por rubros de egresos
            if egresos:
                categorias_egresos = self._analizar_categorias_egresos(egresos)
                mayor_egreso = max(categorias_egresos.items(), key=lambda x: x[1])
                
                egresos_texto = f"""
                <b>Análisis de Egresos:</b> El rubro que representa el mayor gasto es 
                "{mayor_egreso[0]}" con Bs {mayor_egreso[1]:,.2f}, representando el 
                {(mayor_egreso[1] / totales['total_egresos'] * 100):.1f}% del total de egresos.
                """
                elementos.append(Paragraph(egresos_texto, analisis_style))
            
            # Análisis por rubros de ingresos
            if ingresos:
                categorias_ingresos = self._analizar_categorias_ingresos(ingresos)
                mayor_ingreso = max(categorias_ingresos.items(), key=lambda x: x[1])
                
                ingresos_texto = f"""
                <b>Análisis de Ingresos:</b> El área que genera mayores ingresos es 
                "{mayor_ingreso[0]}" con Bs {mayor_ingreso[1]:,.2f}, representando el 
                {(mayor_ingreso[1] / totales['total_ingresos'] * 100):.1f}% del total de ingresos.
                """
                elementos.append(Paragraph(ingresos_texto, analisis_style))
            
            # Recomendaciones
            recomendaciones = self._generar_recomendaciones_financieras(totales, ingresos, egresos)
            elementos.append(Paragraph("<b>Recomendaciones:</b>", analisis_style))
            
            for i, recomendacion in enumerate(recomendaciones, 1):
                elementos.append(Paragraph(f"• {recomendacion}", analisis_style))
            
            return elementos
            
        except Exception as e:
            print(f"Error creando análisis financiero: {e}")
            return []

    # ===== MÉTODOS AUXILIARES PARA CÁLCULOS FINANCIEROS =====
    
    def _calcular_totales_financieros(self, datos):
        """Calcula totales financieros del período"""
        try:
            total_ingresos = 0
            total_egresos = 0
            
            for item in datos:
                valor = float(item.get('valor', 0))
                tipo = item.get('tipo', '')
                
                if tipo == 'INGRESO':
                    total_ingresos += abs(valor)
                elif tipo == 'EGRESO':
                    total_egresos += abs(valor)
            
            return {
                'total_ingresos': total_ingresos,
                'total_egresos': total_egresos,
                'saldo_neto': total_ingresos - total_egresos
            }
            
        except Exception as e:
            print(f"Error calculando totales: {e}")
            return {'total_ingresos': 0, 'total_egresos': 0, 'saldo_neto': 0}
    
    def _separar_ingresos_egresos(self, datos):
        """Separa los datos en ingresos y egresos"""
        try:
            ingresos = []
            egresos = []
            
            for item in datos:
                if item.get('tipo') == 'INGRESO':
                    ingresos.append(item)
                elif item.get('tipo') == 'EGRESO':
                    egresos.append(item)
            
            return ingresos, egresos
            
        except Exception as e:
            print(f"Error separando ingresos y egresos: {e}")
            return [], []
    
    def _analizar_categorias_egresos(self, egresos):
        """Analiza y agrupa egresos por categorías"""
        try:
            categorias = {}
            
            for item in egresos:
                descripcion = item.get('descripcion', 'Sin categoría')
                valor = abs(float(item.get('valor', 0)))
                
                if descripcion in categorias:
                    categorias[descripcion] += valor
                else:
                    categorias[descripcion] = valor
            
            return categorias
            
        except Exception as e:
            print(f"Error analizando categorías de egresos: {e}")
            return {}
    
    def _analizar_categorias_ingresos(self, ingresos):
        """Analiza y agrupa ingresos por categorías"""
        try:
            categorias = {}
            
            for item in ingresos:
                descripcion = item.get('descripcion', 'Sin categoría')
                valor = abs(float(item.get('valor', 0)))
                
                if descripcion in categorias:
                    categorias[descripcion] += valor
                else:
                    categorias[descripcion] = valor
            
            return categorias
            
        except Exception as e:
            print(f"Error analizando categorías de ingresos: {e}")
            return {}
    
    def _generar_recomendaciones_financieras(self, totales, ingresos, egresos):
        """Genera recomendaciones basadas en el análisis financiero"""
        try:
            recomendaciones = []
            
            # Recomendaciones basadas en el saldo
            if totales['saldo_neto'] < 0:
                recomendaciones.append(
                    "Implementar medidas inmediatas de control de gastos para revertir el déficit financiero."
                )
                recomendaciones.append(
                    "Revisar y optimizar los procedimientos de facturación para maximizar los ingresos."
                )
            else:
                recomendaciones.append(
                    "Mantener el control financiero actual que ha permitido obtener un saldo positivo."
                )
            
            # Recomendaciones sobre egresos
            if egresos:
                categorias_egresos = self._analizar_categorias_egresos(egresos)
                mayor_egreso = max(categorias_egresos.items(), key=lambda x: x[1])
                
                if mayor_egreso[1] / totales['total_egresos'] > 0.4:  # Si representa más del 40%
                    recomendaciones.append(
                        f"Evaluar la eficiencia en '{mayor_egreso[0]}' ya que representa un alto porcentaje de los gastos."
                    )
            
            # Recomendaciones sobre ingresos
            if ingresos and len(ingresos) > 0:
                recomendaciones.append(
                    "Fortalecer las áreas generadoras de ingresos mediante estrategias de promoción y mejora de servicios."
                )
            
            # Recomendación general
            recomendaciones.append(
                "Mantener un monitoreo continuo de los indicadores financieros para garantizar la sostenibilidad institucional."
            )
            
            return recomendaciones
            
        except Exception as e:
            print(f"Error generando recomendaciones: {e}")
            return ["Continuar monitoreando la situación financiera de la institución."]
    
    def _debug_datos_arqueo(self, datos_organizados):
        """Método de debug para inspeccionar la estructura real de datos - TEMPORAL"""
        try:
            print("=" * 50)
            print("🔍 DEBUG: ESTRUCTURA DE DATOS ARQUEO")
            print("=" * 50)
            
            for categoria, items in datos_organizados.items():
                print(f"\n📊 CATEGORÍA: {categoria.upper()}")
                print(f"📈 Total items: {len(items)}")
                
                if items and len(items) > 0:
                    print("🗂️  Primer elemento:")
                    primer_item = items[0]
                    for key, value in primer_item.items():
                        print(f"   {key}: {value} ({type(value).__name__})")
                    
                    if len(items) > 1:
                        print(f"🗂️  Campos únicos en todos los elementos:")
                        all_keys = set()
                        for item in items:
                            all_keys.update(item.keys())
                        print(f"   {sorted(all_keys)}")
                else:
                    print("   ❌ Sin datos")
            
            print("=" * 50)
            return True
            
        except Exception as e:
            print(f"Error en debug: {e}")
            return False

    def _crear_arqueo_caja_completo(self, datos, fecha_desde, fecha_hasta):
        """Crea arqueo de caja detallado con todas las transacciones individuales - CORREGIDO"""
        elementos = []
        
        try:
            # 1. TÍTULO E INFORMACIÓN DEL CIERRE
            elementos.extend(self._crear_titulo_arqueo_caja(fecha_desde))
            elementos.extend(self._crear_info_cierre_arqueo(datos))
            elementos.append(Spacer(1, 6*mm))
            
            # 2. PROCESAR DATOS PARA OBTENER ESTRUCTURA CORRECTA
            datos_organizados = self._organizar_datos_por_modulos(datos)
            
            # 🔍 DEBUG: Activar solo durante desarrollo
            self._debug_datos_arqueo(datos_organizados)
            
            # 3. DETALLE DE INGRESOS POR SECCIÓN
            elementos.extend(self._crear_detalle_ventas_farmacia(datos_organizados))
            elementos.append(Spacer(1, 4*mm))
            
            elementos.extend(self._crear_detalle_consultas_medicas(datos_organizados))
            elementos.append(Spacer(1, 4*mm))
            
            elementos.extend(self._crear_detalle_laboratorio(datos_organizados))
            elementos.append(Spacer(1, 4*mm))
            
            elementos.extend(self._crear_detalle_enfermeria(datos_organizados))
            elementos.append(Spacer(1, 8*mm))
            
            # 4. DETALLE DE EGRESOS
            elementos.extend(self._crear_detalle_egresos_completo(datos_organizados))
            elementos.append(Spacer(1, 8*mm))
            
            # 5. RESUMEN FINAL Y ARQUEO FÍSICO
            elementos.extend(self._crear_resumen_arqueo_fisico(datos))
            
            return elementos
            
        except Exception as e:
            print(f"Error creando arqueo: {e}")
            return [self._crear_mensaje_error()]
        
    def _organizar_datos_por_modulos(self, datos):
        """Organiza los datos por módulos para el arqueo de caja - NUEVO MÉTODO"""
        try:
            datos_organizados = {
                'farmacia': [],
                'consultas': [],
                'laboratorio': [],
                'enfermeria': [],
                'egresos': []
            }
            
            # Obtener movimientos completos
            movimientos = datos.get('movimientos_completos', [])
            if isinstance(movimientos, dict):
                # Si ya viene organizado por módulos
                return movimientos
            
            # Si viene como array plano, organizarlo
            for movimiento in movimientos:
                categoria = movimiento.get('categoria', '').lower()
                tipo = movimiento.get('tipo', '').upper()
                
                # Clasificar por categoría/tipo
                if categoria == 'farmacia' or 'farmacia' in movimiento.get('descripcion', '').lower():
                    datos_organizados['farmacia'].append(movimiento)
                elif categoria == 'consultas' or 'consulta' in movimiento.get('descripcion', '').lower():
                    datos_organizados['consultas'].append(movimiento)
                elif categoria == 'laboratorio' or 'laboratorio' in movimiento.get('descripcion', '').lower():
                    datos_organizados['laboratorio'].append(movimiento)
                elif categoria == 'enfermeria' or 'enfermeria' in movimiento.get('descripcion', '').lower():
                    datos_organizados['enfermeria'].append(movimiento)
                elif tipo == 'EGRESO' or categoria in ['gastos', 'compras']:
                    datos_organizados['egresos'].append(movimiento)
                else:
                    # Por defecto, si es ingreso, clasificar por descripción
                    descripcion = movimiento.get('descripcion', '').lower()
                    if 'farmacia' in descripcion:
                        datos_organizados['farmacia'].append(movimiento)
                    elif 'consulta' in descripcion:
                        datos_organizados['consultas'].append(movimiento)
                    elif 'laboratorio' in descripcion or 'análisis' in descripcion:
                        datos_organizados['laboratorio'].append(movimiento)
                    elif 'enfermeria' in descripcion or 'procedimiento' in descripcion:
                        datos_organizados['enfermeria'].append(movimiento)
                    elif tipo == 'EGRESO':
                        datos_organizados['egresos'].append(movimiento)
            
            return datos_organizados
            
        except Exception as e:
            print(f"Error organizando datos: {e}")
            return {'farmacia': [], 'consultas': [], 'laboratorio': [], 'enfermeria': [], 'egresos': []}

    def _crear_titulo_arqueo_caja(self, fecha):
        """Título específico para arqueo de caja"""
        styles = getSampleStyleSheet()
        
        titulo_style = ParagraphStyle(
            'TituloArqueo',
            parent=styles['Normal'],
            fontSize=16,
            fontName='Helvetica-Bold',
            textColor=COLOR_AZUL_PRINCIPAL,
            spaceAfter=12,
            alignment=TA_CENTER,
            borderWidth=2,
            borderColor=COLOR_AZUL_PRINCIPAL,
            borderPadding=8
        )
        
        return [
            Paragraph(f"ARQUEO DE CAJA DETALLADO - {fecha.upper()}", titulo_style),
            Spacer(1, 4*mm)
        ]

    def _crear_info_cierre_arqueo(self, datos):
        """Información del cierre de caja"""
        try:
            info_data = [
                ["Fecha:", datos.get('fecha', 'N/A'), "Responsable:", datos.get('responsable', 'Sistema')],
                ["Hora:", datos.get('hora_generacion', 'N/A'), "N° Arqueo:", datos.get('numero_arqueo', 'ARQ-001')],
                ["Estado:", datos.get('estado', 'COMPLETADO'), "Supervisor:", "Dr. Administrador"]
            ]
            
            tabla = Table(info_data, colWidths=[25*mm, 35*mm, 25*mm, 35*mm])
            
            estilos = [
                ('BACKGROUND', (0, 0), (-1, -1), COLOR_GRIS_CLARO),
                ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 0), (-1, -1), 9),
                ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),  # Primera columna bold
                ('FONTNAME', (2, 0), (2, -1), 'Helvetica-Bold'),  # Tercera columna bold
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ]
            
            tabla.setStyle(TableStyle(estilos))
            return [tabla]
            
        except Exception as e:
            print(f"Error info cierre: {e}")
            return []

    def _crear_detalle_ventas_farmacia(self, datos_organizados):
        """Detalle individual de todas las ventas de farmacia - CORREGIDO"""
        try:
            ventas = datos_organizados.get('farmacia', [])
            
            if not ventas:
                return [self._crear_seccion_vacia("FARMACIA - VENTAS")]
            
            # Crear tabla detallada
            elementos = []
            
            # Título de sección
            titulo_style = ParagraphStyle(
                'TituloSeccion',
                fontSize=12,
                fontName='Helvetica-Bold',
                textColor=COLOR_AZUL_PRINCIPAL,
                spaceAfter=6,
                alignment=TA_LEFT
            )
            elementos.append(Paragraph("💊 FARMACIA - DETALLE DE VENTAS", titulo_style))
            
            # Encabezados de la tabla
            encabezados = ["HORA", "VENTA N°", "PRODUCTO", "CANT.", "P.UNIT", "SUBTOTAL"]
            tabla_datos = [encabezados]
            
            total_ventas = 0
            numero_venta = 1
            
            for venta in ventas:
                # Extraer datos REALES
                fecha_completa = venta.get('fecha', '')
                hora = self._extraer_hora_de_fecha(fecha_completa)
                
                # ✅ USAR ID REAL DE VENTA
                id_venta = venta.get('id_venta') or venta.get('IdVenta') or venta.get('id') or numero_venta
                
                producto = self._limpiar_descripcion_farmacia(venta.get('descripcion', 'Producto'))
                cantidad = int(venta.get('cantidad', 1))
                valor_total = float(venta.get('valor', 0))
                precio_unitario = valor_total / cantidad if cantidad > 0 else 0
                
                fila = [
                    hora,
                    f"V{id_venta:03d}" if isinstance(id_venta, int) else str(id_venta),
                    producto[:30] + "..." if len(producto) > 30 else producto,
                    str(cantidad),
                    f"Bs {precio_unitario:.2f}",
                    f"Bs {valor_total:.2f}"
                ]
                tabla_datos.append(fila)
                total_ventas += valor_total
                numero_venta += 1
            
            # Fila de total
            fila_total = ["", "", "TOTAL VENTAS FARMACIA", 
                        f"{len(ventas)}", "", f"Bs {total_ventas:,.2f}"]
            tabla_datos.append(fila_total)
            
            # Crear tabla con formato profesional
            tabla = Table(
                tabla_datos,
                colWidths=[20*mm, 20*mm, 50*mm, 15*mm, 20*mm, 25*mm],
                repeatRows=1
            )
            
            estilos = self._obtener_estilos_tabla_detalle()
            tabla.setStyle(TableStyle(estilos))
            elementos.append(tabla)
            
            return elementos
            
        except Exception as e:
            print(f"Error detalle ventas: {e}")
            return [self._crear_seccion_vacia("FARMACIA - VENTAS")]

    def _crear_detalle_consultas_medicas(self, datos_organizados):
        """Detalle de consultas médicas individuales - CORREGIDO"""
        try:
            consultas = datos_organizados.get('consultas', [])
            
            if not consultas:
                return [self._crear_seccion_vacia("CONSULTAS MÉDICAS")]
            
            elementos = []
            
            # Título de sección
            titulo_style = ParagraphStyle(
                'TituloSeccion',
                fontSize=12,
                fontName='Helvetica-Bold',
                textColor=COLOR_AZUL_PRINCIPAL,
                spaceAfter=6,
                alignment=TA_LEFT
            )
            elementos.append(Paragraph("🩺 CONSULTAS MÉDICAS - DETALLE", titulo_style))
            
            encabezados = ["HORA", "CONSULTA N°", "ESPECIALIDAD", "PACIENTE", "TIPO", "IMPORTE"]
            tabla_datos = [encabezados]
            
            total_consultas = 0
            numero_consulta = 1
            
            for consulta in consultas:
                fecha_completa = consulta.get('fecha', '')
                hora = self._extraer_hora_de_fecha(fecha_completa)
                
                # ✅ USAR ID REAL DE CONSULTA
                id_consulta = consulta.get('id_consulta') or consulta.get('id') or numero_consulta
                
                especialidad = consulta.get('especialidad', 'Medicina General')
                
                # ✅ USAR NOMBRE REAL DEL PACIENTE (del JOIN con Pacientes)
                paciente = (consulta.get('paciente_nombre') or 
                        f"Paciente #{numero_consulta}")
                
                # ✅ EXTRAER TIPO REAL (Normal/Emergencia) - campo correcto de BD
                tipo_consulta = consulta.get('tipo_consulta', 'Normal')
                
                # ✅ USAR MÉDICO REAL
                medico = consulta.get('doctor_nombre', 'Sin médico')
                
                importe = float(consulta.get('valor', 0))
                
                fila = [
                    hora,
                    f"C{id_consulta}" if isinstance(id_consulta, int) else str(id_consulta),
                    especialidad[:20] + "..." if len(especialidad) > 20 else especialidad,
                    paciente[:20] + "..." if len(paciente) > 20 else paciente,
                    tipo_consulta,  # Normal o Emergencia directo de BD
                    f"Bs {importe:.2f}"
                ]
                tabla_datos.append(fila)
                total_consultas += importe
                numero_consulta += 1
            
            # Fila de total
            fila_total = ["", "", "TOTAL CONSULTAS", "", "", f"Bs {total_consultas:,.2f}"]
            tabla_datos.append(fila_total)
            
            tabla = Table(
                tabla_datos,
                colWidths=[20*mm, 25*mm, 35*mm, 35*mm, 15*mm, 25*mm],
                repeatRows=1
            )
            
            estilos = self._obtener_estilos_tabla_detalle()
            tabla.setStyle(TableStyle(estilos))
            elementos.append(tabla)
            
            return elementos
            
        except Exception as e:
            print(f"Error detalle consultas: {e}")
            return [self._crear_seccion_vacia("CONSULTAS MÉDICAS")]

    def _crear_detalle_laboratorio(self, datos_organizados):
        """Detalle de análisis de laboratorio - CORREGIDO"""
        try:
            laboratorio = datos_organizados.get('laboratorio', [])
            
            if not laboratorio:
                return [self._crear_seccion_vacia("LABORATORIO")]
            
            elementos = []
            
            # Título de sección
            titulo_style = ParagraphStyle(
                'TituloSeccion',
                fontSize=12,
                fontName='Helvetica-Bold',
                textColor=COLOR_AZUL_PRINCIPAL,
                spaceAfter=6,
                alignment=TA_LEFT
            )
            elementos.append(Paragraph("🧪 LABORATORIO - ANÁLISIS", titulo_style))
            
            encabezados = ["HORA", "ANÁLISIS N°", "TIPO ANÁLISIS", "PACIENTE", "TÉCNICO", "IMPORTE"]
            tabla_datos = [encabezados]
            
            total_lab = 0
            numero_analisis = 1
            
            for analisis in laboratorio:
                fecha_completa = analisis.get('fecha', '')
                hora = self._extraer_hora_de_fecha(fecha_completa)
                
                # ✅ USAR ID REAL DE ANÁLISIS
                id_analisis = analisis.get('id_laboratorio') or analisis.get('id') or numero_analisis
                
                # ✅ USAR NOMBRE REAL DEL ANÁLISIS (del JOIN con Tipos_Analisis)
                tipo_analisis = analisis.get('analisis', 'Análisis General')
                
                # ✅ USAR NOMBRE REAL DEL PACIENTE (del JOIN con Pacientes)
                paciente = analisis.get('paciente_nombre', f"Paciente #{numero_analisis}")
                
                # ✅ USAR TÉCNICO REAL (del JOIN con Trabajadores)
                tecnico = analisis.get('laboratorista', 'Técnico Sistema')
                
                importe = float(analisis.get('valor', 0))
                
                fila = [
                    hora,
                    f"L{id_analisis}" if isinstance(id_analisis, int) else str(id_analisis),
                    tipo_analisis[:25] + "..." if len(tipo_analisis) > 25 else tipo_analisis,
                    paciente[:20] + "..." if len(paciente) > 20 else paciente,
                    tecnico[:15] + "..." if len(tecnico) > 15 else tecnico,
                    f"Bs {importe:.2f}"
                ]
                tabla_datos.append(fila)
                total_lab += importe
                numero_analisis += 1
            
            # Fila de total
            fila_total = ["", "", "TOTAL LABORATORIO", "", "", f"Bs {total_lab:,.2f}"]
            tabla_datos.append(fila_total)
            
            tabla = Table(
                tabla_datos,
                colWidths=[20*mm, 25*mm, 40*mm, 30*mm, 25*mm, 25*mm],
                repeatRows=1
            )
            
            estilos = self._obtener_estilos_tabla_detalle()
            tabla.setStyle(TableStyle(estilos))
            elementos.append(tabla)
            
            return elementos
            
        except Exception as e:
            print(f"Error detalle laboratorio: {e}")
            return [self._crear_seccion_vacia("LABORATORIO")]

    def _crear_detalle_enfermeria(self, datos_organizados):
        """Detalle de procedimientos de enfermería - CORREGIDO"""
        try:
            enfermeria = datos_organizados.get('enfermeria', [])
            
            if not enfermeria:
                return [self._crear_seccion_vacia("ENFERMERÍA")]
            
            elementos = []
            
            # Título de sección
            titulo_style = ParagraphStyle(
                'TituloSeccion',
                fontSize=12,
                fontName='Helvetica-Bold',
                textColor=COLOR_AZUL_PRINCIPAL,
                spaceAfter=6,
                alignment=TA_LEFT
            )
            elementos.append(Paragraph("💉 ENFERMERÍA - PROCEDIMIENTOS", titulo_style))
            
            encabezados = ["HORA", "PROC. N°", "PROCEDIMIENTO", "PACIENTE", "ENFERMERA", "IMPORTE"]
            tabla_datos = [encabezados]
            
            total_enf = 0
            numero_proc = 1
            
            for proc in enfermeria:
                fecha_completa = proc.get('fecha', '')
                hora = self._extraer_hora_de_fecha(fecha_completa)
                
                # ✅ USAR ID REAL DE PROCEDIMIENTO
                id_proc = proc.get('id_enfermeria') or proc.get('id') or numero_proc
                
                # ✅ USAR NOMBRE REAL DEL PROCEDIMIENTO (del JOIN con Tipos_Procedimientos)
                procedimiento = proc.get('procedimiento', 'Procedimiento General')
                
                # ✅ USAR NOMBRE REAL DEL PACIENTE (del JOIN con Pacientes)
                paciente = proc.get('paciente_nombre', f"Paciente #{numero_proc}")
                
                # ✅ USAR ENFERMERO/A REAL (del JOIN con Trabajadores)
                enfermera = proc.get('enfermero', 'Enfermera Sistema')
                
                importe = float(proc.get('valor', 0))
                
                fila = [
                    hora,
                    f"E{id_proc}" if isinstance(id_proc, int) else str(id_proc),
                    procedimiento[:25] + "..." if len(procedimiento) > 25 else procedimiento,
                    paciente[:20] + "..." if len(paciente) > 20 else paciente,
                    enfermera[:15] + "..." if len(enfermera) > 15 else enfermera,
                    f"Bs {importe:.2f}"
                ]
                tabla_datos.append(fila)
                total_enf += importe
                numero_proc += 1
            
            # Fila de total
            fila_total = ["", "", "TOTAL ENFERMERÍA", "", "", f"Bs {total_enf:,.2f}"]
            tabla_datos.append(fila_total)
            
            tabla = Table(
                tabla_datos,
                colWidths=[20*mm, 25*mm, 40*mm, 30*mm, 25*mm, 25*mm],
                repeatRows=1
            )
            
            estilos = self._obtener_estilos_tabla_detalle()
            tabla.setStyle(TableStyle(estilos))
            elementos.append(tabla)
            
            return elementos
            
        except Exception as e:
            print(f"Error detalle enfermería: {e}")
            return [self._crear_seccion_vacia("ENFERMERÍA")]


    def _crear_detalle_egresos_completo(self, datos_organizados):
        """Detalle completo de egresos - CORREGIDO"""
        try:
            egresos = datos_organizados.get('egresos', [])
            
            if not egresos:
                return [self._crear_seccion_vacia("EGRESOS DEL DÍA")]
            
            elementos = []
            
            # Título de sección
            titulo_style = ParagraphStyle(
                'TituloSeccion',
                fontSize=12,
                fontName='Helvetica-Bold',
                textColor=COLOR_ROJO_ACENTO,
                spaceAfter=6,
                alignment=TA_LEFT
            )
            elementos.append(Paragraph("💸 EGRESOS DEL DÍA", titulo_style))
            
            encabezados = ["HORA", "CONCEPTO", "PROVEEDOR", "DETALLE", "IMPORTE"]
            tabla_datos = [encabezados]
            
            total_egresos = 0
            
            for egreso in egresos:
                fecha_completa = egreso.get('fecha', '')
                hora = self._extraer_hora_de_fecha(fecha_completa)
                
                # ✅ EXTRAER CONCEPTO REAL según tipo de egreso
                if egreso.get('categoria') == 'Compras de Farmacia':
                    concepto = 'Compras Farmacia'
                    # Para compras, proveedor viene del JOIN con Proveedor
                    proveedor = egreso.get('proveedor', 'Sin proveedor')
                    detalle = f"{egreso.get('descripcion', 'Producto')} - {egreso.get('cantidad', 1)} unid."
                else:
                    # Para gastos, concepto viene del tipo_gasto
                    concepto = egreso.get('tipo_gasto', 'Gasto General')
                    # Proveedor viene directamente del campo Gastos.Proveedor
                    proveedor = egreso.get('proveedor', 'N/A')
                    detalle = egreso.get('descripcion', 'Sin descripción')
                
                importe = abs(float(egreso.get('valor', 0)))
                
                fila = [
                    hora,
                    concepto[:20] + "..." if len(concepto) > 20 else concepto,
                    proveedor[:20] + "..." if len(proveedor) > 20 else proveedor,
                    detalle[:30] + "..." if len(detalle) > 30 else detalle,
                    f"Bs {importe:.2f}"
                ]
                tabla_datos.append(fila)
                total_egresos += importe
            
            # Fila de total
            fila_total = ["", "TOTAL EGRESOS", "", "", f"Bs {total_egresos:,.2f}"]
            tabla_datos.append(fila_total)
            
            tabla = Table(
                tabla_datos,
                colWidths=[20*mm, 30*mm, 35*mm, 45*mm, 25*mm],
                repeatRows=1
            )
            
            # Usar estilos con color rojo para egresos
            estilos = self._obtener_estilos_tabla_detalle(color_negativo=True)
            tabla.setStyle(TableStyle(estilos))
            elementos.append(tabla)
            
            return elementos
            
        except Exception as e:
            print(f"Error detalle egresos: {e}")
            return [self._crear_seccion_vacia("EGRESOS DEL DÍA")]
        
    def _obtener_estilos_tabla_detalle(self, color_negativo=False):
        """Estilos unificados para tablas de detalle del arqueo"""
        color_header = COLOR_ROJO_ACENTO if color_negativo else COLOR_AZUL_PRINCIPAL
        
        return [
            # Encabezado
            ('BACKGROUND', (0, 0), (-1, 0), color_header),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 8),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
            
            # Datos
            ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -2), 7),
            ('ALIGN', (0, 1), (0, -2), 'CENTER'),  # HORA centrada
            ('ALIGN', (-1, 1), (-1, -2), 'RIGHT'), # IMPORTE a la derecha
            
            # Fila de total
            ('BACKGROUND', (0, -1), (-1, -1), color_header),
            ('TEXTCOLOR', (0, -1), (-1, -1), colors.white),
            ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
            ('FONTSIZE', (0, -1), (-1, -1), 8),
            ('ALIGN', (0, -1), (-1, -1), 'RIGHT'),
            
            # Formato general
            ('GRID', (0, 0), (-1, -1), 1, colors.black),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, COLOR_GRIS_CLARO]),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ]
    
    def _extraer_hora_de_fecha(self, fecha_completa):
        """Extrae la hora de una fecha completa"""
        try:
            if not fecha_completa or fecha_completa == '':
                return "N/A"
            
            # Si tiene espacio, tomar la parte después del espacio como hora
            if ' ' in str(fecha_completa):
                hora_parte = str(fecha_completa).split(' ')[-1]
                # Si parece una hora (tiene :), devolverla
                if ':' in hora_parte:
                    return hora_parte[:5]  # HH:MM
            
            # Generar hora ficticia basada en la posición
            import random
            random.seed(hash(str(fecha_completa)))
            hora = random.randint(8, 17)  # Entre 8 AM y 5 PM
            minuto = random.randint(0, 59)
            return f"{hora:02d}:{minuto:02d}"
            
        except:
            return "N/A"

    def _limpiar_descripcion_farmacia(self, descripcion):
        """Limpia la descripción de productos de farmacia"""
        if not descripcion:
            return "Producto"
        
        # Remover prefijos comunes
        descripcion = str(descripcion)
        prefijos = ["Ventas de Farmacia - ", "Farmacia - ", "Venta - "]
        
        for prefijo in prefijos:
            if descripcion.startswith(prefijo):
                descripcion = descripcion[len(prefijo):]
                break
        
        return descripcion.strip()
    
    def _crear_seccion_vacia(self, nombre_seccion):
        """Crea mensaje para sección sin datos"""
        style = ParagraphStyle(
            'SeccionVacia',
            fontSize=10,
            textColor=COLOR_GRIS_OSCURO,
            spaceAfter=6,
            leftIndent=10
        )
        
        return Paragraph(f"📋 {nombre_seccion}: Sin registros en el período", style)
    def _crear_resumen_arqueo_fisico(self, datos):
        """Resumen final y arqueo físico de efectivo"""
        elementos = []
        
        try:
            # Resumen financiero
            resumen_data = [
                ["CONCEPTO", "IMPORTE"],
                ["Total Ingresos", f"Bs {datos.get('total_ingresos', 0):,.2f}"],
                ["Total Egresos", f"Bs {datos.get('total_egresos', 0):,.2f}"],
                ["Saldo Teórico", f"Bs {datos.get('saldo_teorico', 0):,.2f}"],
                ["Efectivo Real", f"Bs {datos.get('efectivo_real', 0):,.2f}"],
                ["Diferencia", f"Bs {datos.get('diferencia', 0):,.2f}"]
            ]
            
            tabla_resumen = Table(resumen_data, colWidths=[60*mm, 40*mm])
            
            estilos_resumen = [
                ('BACKGROUND', (0, 0), (-1, 0), COLOR_AZUL_PRINCIPAL),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 0), (-1, -1), 10),
                ('ALIGN', (1, 1), (1, -1), 'RIGHT'),
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, COLOR_GRIS_CLARO]),
            ]
            
            tabla_resumen.setStyle(TableStyle(estilos_resumen))
            
            elementos.append(Paragraph("📊 RESUMEN FINANCIERO Y ARQUEO", 
                                    ParagraphStyle('ResumenTitulo', fontSize=14, fontName='Helvetica-Bold',
                                                textColor=COLOR_AZUL_PRINCIPAL, spaceAfter=8)))
            elementos.append(tabla_resumen)
            
            # Resultado final
            diferencia = datos.get('diferencia', 0)
            tipo_diff = "SOBRANTE" if diferencia >= 0 else "FALTANTE"
            
            resultado_style = ParagraphStyle(
                'ResultadoArqueo',
                fontSize=12,
                fontName='Helvetica-Bold',
                textColor=COLOR_VERDE_POSITIVO if diferencia >= 0 else COLOR_ROJO_ACENTO,
                alignment=TA_CENTER,
                spaceAfter=12,
                spaceBefore=12
            )
            
            elementos.append(Paragraph(
                f"✅ {tipo_diff} EN CAJA: Bs {abs(diferencia):,.2f}", 
                resultado_style
            ))
            
            return elementos
            
        except Exception as e:
            print(f"Error resumen arqueo: {e}")
            return []

    def _crear_tabla_seccion(self, titulo, tabla_datos, color_negativo=False):
        """Crea tabla con formato específico para secciones del arqueo"""
        try:
            styles = getSampleStyleSheet()
            
            titulo_style = ParagraphStyle(
                'TituloSeccion',
                parent=styles['Normal'],
                fontSize=12,
                fontName='Helvetica-Bold',
                textColor=COLOR_AZUL_PRINCIPAL,
                spaceAfter=6,
                alignment=TA_LEFT
            )
            
            elementos = []
            elementos.append(Paragraph(titulo, titulo_style))
            
            tabla = Table(tabla_datos, 
                        colWidths=[15*mm, 20*mm, 45*mm, 15*mm, 20*mm, 25*mm],
                        repeatRows=1)
            
            color_header = COLOR_ROJO_ACENTO if color_negativo else COLOR_AZUL_PRINCIPAL
            
            estilos = [
                ('BACKGROUND', (0, 0), (-1, 0), color_header),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 8),
                ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
                ('FONTSIZE', (0, 1), (-1, -2), 7),
                ('ALIGN', (3, 1), (-1, -1), 'RIGHT'),
                ('BACKGROUND', (0, -1), (-1, -1), color_header),
                ('TEXTCOLOR', (0, -1), (-1, -1), colors.white),
                ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
                ('FONTSIZE', (0, -1), (-1, -1), 8),
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, COLOR_GRIS_CLARO]),
            ]
            
            tabla.setStyle(TableStyle(estilos))
            elementos.append(tabla)
            
            return elementos[0] if len(elementos) == 2 else elementos
            
        except Exception as e:
            print(f"Error tabla sección: {e}")
            return self._crear_seccion_vacia(titulo.split(' - ')[-1])

    def _crear_seccion_vacia(self, nombre_seccion):
        """Crea sección vacía cuando no hay datos"""
        styles = getSampleStyleSheet()
        
        return Paragraph(f"📋 {nombre_seccion}: Sin registros en el período", 
                        ParagraphStyle('SeccionVacia', fontSize=10, 
                                    textColor=COLOR_GRIS_OSCURO, spaceAfter=6))
    def _crear_mensaje_error(self):
        """Crea mensaje de error para el PDF"""
        styles = getSampleStyleSheet()
        error_style = ParagraphStyle(
            'Error',
            parent=styles['Normal'],
            fontSize=12,
            textColor=COLOR_ROJO_ACENTO,
            alignment=TA_CENTER
        )
        
        return Paragraph("Error generando reporte de ingresos y egresos", error_style)
    
    # ===== MÉTODOS EXISTENTES (MANTENER FUNCIONALIDAD ANTERIOR) =====
    
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
                canvas.drawImage(
                    self.logo_path, 
                    25*mm, letter[1]-45*mm,
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
        
    def _crear_estilos_tabla_unificados(self):
        """Estilos unificados para todas las tablas de reportes"""
        return [
            # ✅ ENCABEZADO PRINCIPAL - ESTILO ÚNICO
            ('BACKGROUND', (0, 0), (-1, 0), COLOR_AZUL_PRINCIPAL),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 9),
            ('TOPPADDING', (0, 0), (-1, 0), 8),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
            ('LEFTPADDING', (0, 0), (-1, 0), 4),
            ('RIGHTPADDING', (0, 0), (-1, 0), 4),
            
            # ✅ FILAS DE DATOS - ESTILO UNIFORME
            ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -2), 8),
            ('TOPPADDING', (0, 1), (-1, -2), 6),
            ('BOTTOMPADDING', (0, 1), (-1, -2), 6),
            ('LEFTPADDING', (0, 1), (-1, -2), 4),
            ('RIGHTPADDING', (0, 1), (-1, -2), 4),
            ('VALIGN', (0, 1), (-1, -2), 'MIDDLE'),
            ('ROWHEIGHT', (0, 1), (-1, -2), 28),  # Altura fija uniforme
            
            # ✅ FILA DE TOTAL - ESTILO PROFESIONAL ÚNICO
            ('BACKGROUND', (0, -1), (-1, -1), COLOR_AZUL_PRINCIPAL),
            ('TEXTCOLOR', (0, -1), (-1, -1), colors.white),
            ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
            ('FONTSIZE', (0, -1), (-1, -1), 10),
            ('TOPPADDING', (0, -1), (-1, -1), 8),
            ('BOTTOMPADDING', (0, -1), (-1, -1), 8),
            ('LEFTPADDING', (0, -1), (-1, -1), 4),
            ('RIGHTPADDING', (0, -1), (-1, -1), 4),
            
            # ✅ CONFIGURACIÓN GENERAL UNIFORME
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('GRID', (0, 0), (-1, -2), 0.5, colors.black),  # Líneas más delgadas
            ('LINEBELOW', (0, 0), (-1, 0), 2, COLOR_AZUL_PRINCIPAL),
            ('LINEABOVE', (0, -1), (-1, -1), 2, COLOR_AZUL_PRINCIPAL),
            
            # ✅ ZEBRA STRIPING SUTIL Y UNIFORME
            ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, COLOR_GRIS_CLARO]),
        ]
    
        
    def _crear_tabla_profesional_mejorada(self, datos, tipo_reporte):
        """Crea tabla con estilo COMPLETAMENTE UNIFICADO"""
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
            
            # Calcular totales
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
                
        # ✅ CREAR FILA DE TOTAL CON ETIQUETA "TOTAL GENERAL:" EN LA POSICIÓN CORRECTA
        fila_total = [""] * len(columnas_def)

        # ✅ LÓGICA ESPECÍFICA PARA VENTAS - CORREGIDA
        if tipo_reporte == 1:  # Ventas de Farmacia
            # Buscar las posiciones de VENDEDOR y TOTAL
            for i, (col_titulo, ancho, alineacion) in enumerate(columnas_def):
                if col_titulo == "VENDEDOR":
                    fila_total[i] = "TOTAL GENERAL:"
                elif col_titulo == "TOTAL (Bs)":
                    fila_total[i] = f"Bs {total_valor:,.2f}"
        else:
            # Para otros reportes
            if len(columnas_def) >= 2:
                fila_total[-2] = "TOTAL GENERAL:"  # Penúltima columna
                fila_total[-1] = f"Bs {total_valor:,.2f}"  # Última columna
            else:
                fila_total[0] = f"TOTAL GENERAL: Bs {total_valor:,.2f}"

        tabla_datos.append(fila_total)

        # ✅ CREAR TABLA CON ESTILOS UNIFICADOS
        tabla = Table(
            tabla_datos, 
            colWidths=anchos_columnas, 
            repeatRows=1,
            splitByRow=1,
            spaceAfter=12,
            spaceBefore=12,
            hAlign='CENTER'
        )

        # ✅ APLICAR ESTILOS UNIFICADOS
        estilos_base = self._crear_estilos_tabla_unificados()

        # Aplicar alineaciones específicas por columna
        for col_idx, (col_titulo, ancho, alineacion) in enumerate(columnas_def):
            align_map = {'LEFT': 'LEFT', 'RIGHT': 'RIGHT', 'CENTER': 'CENTER'}
            tabla_align = align_map.get(alineacion, 'LEFT')
            
            # Alineación para datos normales
            estilos_base.append(('ALIGN', (col_idx, 1), (col_idx, -2), tabla_align))
            
            # ✅ ALINEACIÓN CORREGIDA PARA FILA DE TOTAL
            if tipo_reporte == 1:  # Ventas - orden corregido
                if col_titulo == "VENDEDOR" or col_titulo == "TOTAL (Bs)":
                    estilos_base.append(('ALIGN', (col_idx, -1), (col_idx, -1), 'RIGHT'))
                else:
                    estilos_base.append(('ALIGN', (col_idx, -1), (col_idx, -1), 'CENTER'))
            else:  # Otros reportes
                if col_idx >= len(columnas_def) - 2:  # Últimas dos columnas
                    estilos_base.append(('ALIGN', (col_idx, -1), (col_idx, -1), 'RIGHT'))
                else:
                    estilos_base.append(('ALIGN', (col_idx, -1), (col_idx, -1), 'CENTER'))

        # Aplicar estilos
        tabla.setStyle(TableStyle(estilos_base))
        
        print(f"✅ Tabla PDF creada con estilo unificado: {len(datos)} filas + total")
        
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
        """Define las columnas con ANCHOS UNIFORMES Y CORREGIDOS"""
        
        # ANCHOS ESTÁNDAR CORREGIDOS (optimizados para evitar truncamiento)
        ANCHO_FECHA = 25      # Aumentado de 22
        ANCHO_CODIGO = 22     # Aumentado de 20
        ANCHO_CORTO = 28      # Aumentado de 25
        ANCHO_MEDIO = 38      # Aumentado de 35
        ANCHO_LARGO = 50      # Aumentado de 45
        ANCHO_VALOR = 32      # Aumentado de 28
        
        columnas = {
            1: [  # Ventas de Farmacia
                ("FECHA", ANCHO_FECHA, 'LEFT'),
                ("Nº VENTA", ANCHO_CODIGO, 'LEFT'), 
                ("PRODUCTO", ANCHO_LARGO-5, 'LEFT'),
                ("CANT", ANCHO_CORTO-8, 'RIGHT'),
                ("P.UNIT (Bs)", ANCHO_VALOR-5, 'RIGHT'),
                ("VENDEDOR", ANCHO_MEDIO-3, 'LEFT'),
                ("TOTAL (Bs)", ANCHO_VALOR-5, 'RIGHT')
            ],
            
            2: [  # Inventario
                ("FECHA", ANCHO_FECHA-5, 'LEFT'),
                ("PRODUCTO", ANCHO_LARGO, 'LEFT'),   
                ("MARCA", ANCHO_MEDIO-13, 'LEFT'),
                ("STOCK", ANCHO_CORTO-8, 'RIGHT'),
                ("LOTES", ANCHO_CORTO-13, 'CENTER'),
                ("P.UNIT", ANCHO_CORTO-3, 'RIGHT'),
                ("F.VENC", ANCHO_CORTO-3, 'LEFT'),
                ("VALOR (Bs)", ANCHO_VALOR-3, 'RIGHT')
            ],
            
            3: [  # Compras
                ("FECHA", ANCHO_FECHA-3, 'LEFT'),
                ("PRODUCTO", ANCHO_MEDIO+7, 'LEFT'),
                ("MARCA", ANCHO_CORTO-5, 'LEFT'),
                ("UNIDADES", ANCHO_CORTO-5, 'RIGHT'),
                ("PROVEEDOR", ANCHO_MEDIO-3, 'LEFT'),
                ("F.VENC", ANCHO_CODIGO, 'LEFT'),
                ("USUARIO", ANCHO_CORTO, 'LEFT'),
                ("TOTAL (Bs)", ANCHO_VALOR-2, 'RIGHT')
            ],
            
            4: [  # Consultas Médicas
                ("FECHA", ANCHO_FECHA, 'LEFT'),
                ("ESPECIALIDAD", ANCHO_MEDIO, 'LEFT'),
                ("DESCRIPCIÓN", ANCHO_LARGO, 'LEFT'),
                ("PACIENTE", ANCHO_MEDIO+5, 'LEFT'),
                ("MÉDICO", ANCHO_MEDIO, 'LEFT'),
                ("PRECIO (Bs)", ANCHO_VALOR, 'RIGHT')
            ],
            
            5: [  # Laboratorio
                ("FECHA", ANCHO_FECHA-3, 'LEFT'),
                ("ANÁLISIS", ANCHO_MEDIO+7, 'LEFT'),
                ("TIPO", ANCHO_CORTO-3, 'CENTER'),
                ("PACIENTE", ANCHO_MEDIO+5, 'LEFT'),
                ("LABORATORISTA", ANCHO_MEDIO, 'LEFT'),
                ("PRECIO (Bs)", ANCHO_VALOR, 'RIGHT')
            ],
            
            6: [  # Enfermería
                ("FECHA", ANCHO_FECHA-3, 'LEFT'),
                ("PROCEDIMIENTO", ANCHO_MEDIO+7, 'LEFT'),
                ("TIPO", ANCHO_CORTO-3, 'CENTER'),
                ("PACIENTE", ANCHO_MEDIO+5, 'LEFT'),
                ("ENFERMERO/A", ANCHO_MEDIO, 'LEFT'),
                ("PRECIO (Bs)", ANCHO_VALOR, 'RIGHT')
            ],
            
            7: [  # Gastos
                ("FECHA", ANCHO_FECHA, 'LEFT'),
                ("TIPO GASTO", ANCHO_MEDIO, 'LEFT'),
                ("DESCRIPCIÓN", ANCHO_LARGO, 'LEFT'),
                ("PROVEEDOR", ANCHO_MEDIO-5, 'LEFT'),
                ("MONTO (Bs)", ANCHO_VALOR, 'RIGHT')
            ],
            
            8: [  # Ingresos y Egresos
                ("FECHA", ANCHO_FECHA, 'LEFT'),
                ("TIPO", ANCHO_CORTO+5, 'CENTER'),
                ("DESCRIPCIÓN", ANCHO_LARGO+20, 'LEFT'),
                ("CANTIDAD", ANCHO_CORTO, 'RIGHT'),
                ("VALOR (Bs)", ANCHO_VALOR+8, 'RIGHT')
            ],

            9: [  # Arqueo de Caja - Columnas flexibles
                ("FECHA", ANCHO_FECHA, 'LEFT'),
                ("TIPO", ANCHO_CORTO+5, 'CENTER'),
                ("DESCRIPCIÓN", ANCHO_LARGO+15, 'LEFT'),
                ("CANTIDAD", ANCHO_CORTO, 'RIGHT'),
                ("VALOR (Bs)", ANCHO_VALOR, 'RIGHT')
            ]
        }
        
        return columnas.get(tipo_reporte, [
            ("FECHA", ANCHO_FECHA, 'LEFT'),
            ("DESCRIPCIÓN", ANCHO_LARGO+20, 'LEFT'),
            ("CANTIDAD", ANCHO_CORTO, 'RIGHT'),
            ("VALOR (Bs)", ANCHO_VALOR, 'RIGHT')
        ])

    def _obtener_valor_campo(self, registro, campo_titulo, tipo_reporte):
        """Extrae valores con MAPEO CORREGIDO PARA NUEVOS CAMPOS"""
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.platypus import Paragraph
        from reportlab.lib.enums import TA_LEFT
        
        # ✅ MAPEO ACTUALIZADO CON NUEVOS CAMPOS
        mapeo_campos = {
            # CAMPOS BÁSICOS
            "FECHA": "fecha",
            "DESCRIPCIÓN": "descripcion", 
            "CANTIDAD": "cantidad",
            "CANT": "cantidad",
            "UNIDADES": "cantidad",
            
            # VALORES MONETARIOS
            "PRECIO (Bs)": "valor",
            "TOTAL (Bs)": "valor", 
            "VALOR (Bs)": "valor",
            "MONTO (Bs)": "valor",  # ✅ NUEVO para gastos
            "P.UNIT (Bs)": "precio_unitario",
            
            # ✅ LABORATORIO - CAMPOS CORREGIDOS
            "ANÁLISIS": "analisis",           # ✅ NUEVO campo
            "TIPO": "tipo",                   # ✅ Normal/Emergencia
            "LABORATORISTA": "laboratorista", # ✅ NUEVO campo
            
            # ✅ ENFERMERÍA - CAMPOS CORREGIDOS  
            "PROCEDIMIENTO": "procedimiento", # ✅ NUEVO campo (con detalles)
            "ENFERMERO/A": "enfermero",       # ✅ MANTENER
            
            # ✅ GASTOS - CAMPOS CORREGIDOS
            "TIPO GASTO": "tipo_gasto",       # ✅ NUEVO campo
            
            # VENTAS - MAPEOS EXISTENTES
            "Nº VENTA": "numeroVenta",
            "Nº VENTA": "numeroVenta",
            "NUMERO VENTA": "numeroVenta",
            "VENDEDOR": "usuario",
            
            # CAMPOS EXISTENTES
            "PACIENTE": "paciente",
            "MÉDICO": "doctor_nombre",
            "ESPECIALIDAD": "especialidad",
            "TÉCNICO": "tecnico",
            "TIPO ANÁLISIS": "tipoAnalisis",
            "PRODUCTO": "descripcion",
            "MARCA": "marca", 
            "PROVEEDOR": "proveedor",
            "F.VENC": "fecha_vencimiento",
            "USUARIO": "usuario",
            "STOCK": "cantidad",
            "LOTES": "lotes"
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

        # ✅ PROCESAMIENTO ESPECÍFICO PARA REPORTE DE INGRESOS Y EGRESOS (TIPO 8)
        if tipo_reporte == 8:
            if campo_titulo == "TIPO":
                tipo = registro.get('tipo', 'Sin tipo')
                return tipo
            elif campo_titulo == "VALOR (Bs)":
                try:
                    valor_num = float(registro.get('valor', 0))
                    tipo = registro.get('tipo', '')
                    
                    # Mostrar con signo según el tipo
                    if tipo == 'INGRESO':
                        return f"+Bs {abs(valor_num):,.2f}"
                    elif tipo == 'EGRESO':
                        return f"-Bs {abs(valor_num):,.2f}"
                    else:
                        return f"Bs {valor_num:,.2f}"
                except:
                    return "Bs 0.00"
        
        # ✅ PROCESAMIENTO ESPECÍFICO PARA NUEVOS CAMPOS
        
        # 1. Campo ANÁLISIS (laboratorio)
        if campo_titulo == "ANÁLISIS":
            analisis = (registro.get('analisis') or 
                       registro.get('tipoAnalisis') or
                       registro.get('tipo_analisis') or 
                       "Análisis General")
            
            if len(analisis) > 25:
                return crear_parrafo(analisis)
            return analisis
        
        # 2. Campo TIPO (laboratorio y enfermería)
        elif campo_titulo == "TIPO" and tipo_reporte in [5, 6]:
            tipo = registro.get('tipo', 'Normal')
            return tipo if tipo in ['Normal', 'Emergencia'] else 'Normal'
        
        # 3. Campo LABORATORISTA
        elif campo_titulo == "LABORATORISTA":
            laboratorista = (registro.get('laboratorista') or
                           registro.get('tecnico') or 
                           registro.get('trabajador_nombre') or
                           "Sin asignar")
            
            if len(laboratorista) > 20:
                return crear_parrafo(laboratorista)
            return laboratorista
        
        # 4. Campo PROCEDIMIENTO (enfermería)
        elif campo_titulo == "PROCEDIMIENTO":
            procedimiento = (registro.get('procedimiento') or 
                           registro.get('tipoProcedimiento') or
                           registro.get('tipo_procedimiento') or
                           registro.get('Procedimiento') or
                           registro.get('descripcion') or 
                           "Procedimiento General")
            
            if len(procedimiento) > 25:
                return crear_parrafo(procedimiento)
            return procedimiento
        
        # 5. Campo TIPO GASTO
        elif campo_titulo == "TIPO GASTO":
            tipo_gasto = (registro.get('tipo_gasto') or
                         registro.get('categoria') or 
                         registro.get('tipo_nombre') or
                         "General")
            
            if len(tipo_gasto) > 18:
                return crear_parrafo(tipo_gasto)
            return tipo_gasto
        
        # 6. Campos monetarios
        elif any(palabra in campo_titulo.upper() for palabra in ["PRECIO", "TOTAL", "VALOR", "MONTO"]):
            try:
                return f"Bs {float(valor):,.2f}"
            except:
                return "Bs 0.00"
        
        # 7. Campos numéricos
        elif campo_titulo in ["CANTIDAD", "UNIDADES", "STOCK", "LOTES"]:
            try:
                if valor == "" or valor is None or str(valor).strip() == "":
                    # Para STOCK: Buscar en múltiples campos posibles
                    if campo_titulo == "STOCK":
                        stock_valor = (registro.get('cantidad') or 
                                     registro.get('Stock_Total') or 
                                     registro.get('stock_total') or
                                     registro.get('Stock_Calculado') or
                                     registro.get('Cantidad_Unitario') or
                                     0)
                        return str(int(float(stock_valor)))
                    else:
                        return "0"
                
                valor_num = float(valor)
                return f"{int(valor_num):,}"
            except:
                if campo_titulo == "STOCK":
                    stock_valor = (registro.get('cantidad') or 
                                 registro.get('Stock_Total') or 
                                 registro.get('stock_total') or
                                 0)
                    try:
                        return str(int(float(stock_valor)))
                    except:
                        return "0"
                return "0"
        
        # 8. Enfermero/a
        elif campo_titulo == "ENFERMERO/A":
            enfermero = (registro.get('enfermero') or
                        registro.get('Enfermero') or 
                        registro.get('enfermero_nombre') or
                        registro.get('trabajador_nombre') or
                        "Sin asignar")
            
            if len(enfermero) > 20:
                return crear_parrafo(enfermero)
            return enfermero
        
        # 9. Marca
        elif campo_titulo == "MARCA":
            marca = (registro.get('marca') or 
                    registro.get('Marca') or
                    registro.get('Marca_Nombre') or
                    registro.get('marca_nombre') or
                    "Sin marca")
            
            if len(marca) > 15:
                return crear_parrafo(marca)
            return marca
        
        # 10. Proveedor
        elif campo_titulo == "PROVEEDOR":
            proveedor = (registro.get('proveedor') or
                        registro.get('Proveedor') or 
                        registro.get('proveedor_nombre') or
                        registro.get('Proveedor_Nombre') or
                        "Sin proveedor")
            
            if len(proveedor) > 18:
                return crear_parrafo(proveedor)
            return proveedor
        
        # 11. Precio unitario
        elif campo_titulo in ["P.UNIT (Bs)", "PRECIO UNIT.", "P.UNIT"]:
            try:
                precio_unit = float(registro.get('precio_unitario', 0))
                return f"Bs {precio_unit:.2f}"
            except:
                return "Bs 0.00"

        # 12. Vendedor
        elif campo_titulo == "VENDEDOR":
            return registro.get('usuario', "Sin vendedor")
        
        # 13. Usuario
        elif campo_titulo == "USUARIO":
            usuario = (registro.get('usuario') or
                      registro.get('Usuario') or
                      registro.get('usuario_nombre') or
                      registro.get('registrado_por') or
                      "Sin usuario")
            
            if len(usuario) > 15:
                return crear_parrafo(usuario)
            return usuario
        
        # 14. Fecha de vencimiento
        elif campo_titulo == "F.VENC":
            fecha_venc = (registro.get('fecha_vencimiento') or 
                         registro.get('Fecha_Vencimiento') or
                         registro.get('proxima_vencimiento') or
                         None)
            
            if not fecha_venc or str(fecha_venc) in ["", "None", "null"]:
                return "Sin venc."
            
            # Formatear fecha si viene en formato ISO
            if isinstance(fecha_venc, str) and len(fecha_venc) >= 10:
                try:
                    if '-' in fecha_venc:  # Formato YYYY-MM-DD
                        partes = fecha_venc[:10].split('-')
                        return f"{partes[2]}/{partes[1]}/{partes[0]}"
                except:
                    pass
            
            return str(fecha_venc)
        
        # 15. Descripciones (usar Paragraph para texto largo)
        elif campo_titulo in ["DESCRIPCIÓN", "PRODUCTO"]:
            if not valor:
                valor = "Sin descripción"
            
            if len(valor) > 30:
                return crear_parrafo(valor)
            return valor
        
        # 16. Paciente
        elif campo_titulo == "PACIENTE":
            paciente = (registro.get('paciente') or
                       registro.get('Paciente') or
                       registro.get('paciente_nombre') or
                       "Paciente")
            
            if len(paciente) > 25:
                return crear_parrafo(paciente)
            return paciente
        
        # 17. Número de venta
        elif campo_titulo in ["Nº VENTA", "Nº VENTA"]:
            return registro.get('numeroVenta', f"V{str(1).zfill(3)}")
        
        # 18. Especialidad
        elif campo_titulo == "ESPECIALIDAD":
            return registro.get('especialidad', "Sin especialidad")
        
        # 19. Médico
        elif campo_titulo == "MÉDICO":
            return registro.get('doctor_nombre', "Sin médico")
        
        # 20. Genérico con fallback
        if not valor or valor == "":
            # Intentar búsqueda alternativa
            campo_alt = campo_dato.replace('_', '').lower()
            for key in registro.keys():
                if key.lower().replace('_', '') == campo_alt:
                    valor = registro[key]
                    break
            
            if not valor:
                return "---"
        
        # Formatear valor final
        if len(str(valor)) > 25:
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