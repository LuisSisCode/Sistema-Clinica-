"""
Módulo para generar reportes PDF profesionales - VERSIÓN OPTIMIZADA
Sistema de Gestión Médica - Clínica María Inmaculada
Versión 2.1 - Solo usa logo existente, sin crear archivos adicionales
"""

import os
import json
from datetime import datetime
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, mm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Image, Image
from reportlab.platypus.tableofcontents import TableOfContents
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader

class GeneradorReportesPDF:
    """
    Clase encargada de generar reportes PDF profesionales
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
        # Anchos en mm para carta (190mm disponible)
        columnas = {
            1: [  # Ventas
                ("FECHA", 25, 'LEFT'),
                ("N° VENTA", 25, 'LEFT'), 
                ("DESCRIPCIÓN", 85, 'LEFT'),
                ("CANT.", 20, 'RIGHT'),
                ("TOTAL (Bs)", 35, 'RIGHT')
            ],
            2: [  # Inventario
                ("CÓDIGO", 25, 'LEFT'),
                ("PRODUCTO", 80, 'LEFT'),
                ("UM", 15, 'CENTER'),
                ("STOCK", 25, 'RIGHT'),
                ("P.U.", 25, 'RIGHT'),
                ("VALOR (Bs)", 30, 'RIGHT')
            ],
            3: [  # Compras
                ("FECHA", 25, 'LEFT'),
                ("N° COMPRA", 30, 'LEFT'),
                ("PROVEEDOR", 85, 'LEFT'),
                ("CANT.", 20, 'RIGHT'),
                ("TOTAL (Bs)", 30, 'RIGHT')
            ],
            4: [  # Consultas
                ("FECHA", 25, 'LEFT'),
                ("ESPECIALIDAD", 45, 'LEFT'),
                ("MÉDICO", 65, 'LEFT'),
                ("PACIENTE", 35, 'LEFT'),
                ("VALOR (Bs)", 25, 'RIGHT')
            ],
            5: [  # Laboratorio
                ("FECHA", 25, 'LEFT'),
                ("EXAMEN", 75, 'LEFT'),
                ("PACIENTE", 40, 'LEFT'),
                ("ESTADO", 25, 'CENTER'),
                ("VALOR (Bs)", 25, 'RIGHT')
            ],
            6: [  # Enfermería
                ("FECHA", 25, 'LEFT'),
                ("PROCEDIMIENTO", 80, 'LEFT'),
                ("PACIENTE", 40, 'LEFT'),
                ("CANT.", 20, 'RIGHT'),
                ("TOTAL (Bs)", 25, 'RIGHT')
            ],
            7: [  # Gastos
                ("FECHA", 25, 'LEFT'),
                ("CATEGORÍA", 40, 'LEFT'),
                ("DESCRIPCIÓN", 95, 'LEFT'),
                ("MONTO (Bs)", 30, 'RIGHT')
            ],
            8: [  # Consolidado
                ("FECHA", 25, 'LEFT'),
                ("TIPO", 30, 'CENTER'),
                ("DESCRIPCIÓN", 80, 'LEFT'),
                ("REGISTROS", 25, 'RIGHT'),
                ("VALOR (Bs)", 30, 'RIGHT')
            ]
        }
        return columnas.get(tipo_reporte, [
            ("FECHA", 25, 'LEFT'),
            ("DESCRIPCIÓN", 115, 'LEFT'), 
            ("CANT.", 20, 'RIGHT'),
            ("VALOR (Bs)", 30, 'RIGHT')
        ])
    
    def _crear_pdf_profesional(self, filepath, datos, tipo_reporte, fecha_desde, fecha_hasta):
        """
        Crea el archivo PDF profesional con encabezado y pie
        """
        try:
            from reportlab.platypus import PageTemplate, Frame
            from reportlab.platypus.doctemplate import PageTemplate, BaseDocTemplate
            
            # Crear documento base
            doc = SimpleDocTemplate(
                filepath,
                pagesize=letter,
                rightMargin=20*mm,
                leftMargin=20*mm,
                topMargin=50*mm,  # Más espacio para encabezado
                bottomMargin=35*mm  # Más espacio para pie
            )
            
            # Configurar información del documento
            titulo_reporte = self._obtener_titulo_reporte(tipo_reporte)
            
            # Story principal
            story = []
            
            # === ENCABEZADO MANUAL ===
            story.append(self._crear_encabezado_profesional(titulo_reporte, fecha_desde, fecha_hasta))
            story.append(Spacer(1, 10*mm))
            
            # === CONTENIDO PRINCIPAL ===
            if datos and len(datos) > 0:
                # Crear tabla con paginación automática
                tabla = self._crear_tabla_profesional(datos, tipo_reporte)
                story.append(tabla)
                
                # Espaciador
                story.append(Spacer(1, 5*mm))
                
                # Resumen
                resumen = self._crear_resumen_profesional(datos)
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
            
            # === PIE DE PÁGINA MANUAL ===
            story.append(Spacer(1, 10*mm))
            story.append(self._crear_pie_pagina_manual())
            
            # Construir el PDF
            doc.build(story)
            
            return True
            
        except Exception as e:
            print(f"❌ Error creando PDF profesional: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def _crear_encabezado_profesional(self, titulo_reporte, fecha_desde, fecha_hasta):
        """Crea el encabezado del reporte con logo real o texto profesional"""
        from reportlab.platypus import Table, TableStyle
        
        # Crear tabla para el encabezado
        encabezado_data = []
        
        # Fila 1: Logo + Información de la clínica
        if self.logo_path and os.path.exists(self.logo_path):
            # Usar imagen real del logo
            try:
                # Crear imagen con tamaño apropiado para el encabezado
                logo_img = Image(self.logo_path, width=45*mm, height=18*mm)
                fila_logo = [
                    logo_img,
                    "",
                    "CLÍNICA MARÍA INMACULADA\nVilla Yapacaní, Santa Cruz - Bolivia"
                ]
                print(f"✅ Logo cargado correctamente: {self.logo_path}")
            except Exception as e:
                print(f"⚠️ Error cargando imagen del logo: {e}")
                # Fallback a texto profesional
                fila_logo = [
                    self._crear_logo_texto_profesional(),
                    "",
                    "CLÍNICA MARÍA INMACULADA\nVilla Yapacaní, Santa Cruz - Bolivia"
                ]
        else:
            # Usar logo de texto profesional
            fila_logo = [
                self._crear_logo_texto_profesional(),
                "",
                "CLÍNICA MARÍA INMACULADA\nVilla Yapacaní, Santa Cruz - Bolivia"
            ]
        
        encabezado_data.append(fila_logo)
        
        # Fila 2: Título del reporte (spanning)
        fila_titulo = [titulo_reporte, "", ""]
        encabezado_data.append(fila_titulo)
        
        # Fila 3: Período
        fila_periodo = [f"PERÍODO: {fecha_desde} al {fecha_hasta}", "", ""]
        encabezado_data.append(fila_periodo)
        
        # Crear tabla
        encabezado_tabla = Table(encabezado_data, colWidths=[50*mm, 80*mm, 60*mm])
        
        # Aplicar estilos
        encabezado_tabla.setStyle(TableStyle([
            # Logo
            ('VALIGN', (0, 0), (0, 0), 'MIDDLE'),
            ('ALIGN', (0, 0), (0, 0), 'CENTER'),
            
            # Información clínica
            ('ALIGN', (2, 0), (2, 0), 'RIGHT'),
            ('FONTNAME', (2, 0), (2, 0), 'Helvetica'),
            ('FONTSIZE', (2, 0), (2, 0), 9),
            ('TEXTCOLOR', (2, 0), (2, 0), colors.grey),
            ('VALIGN', (2, 0), (2, 0), 'MIDDLE'),
            
            # Título (spanning)
            ('SPAN', (0, 1), (2, 1)),
            ('ALIGN', (0, 1), (2, 1), 'CENTER'),
            ('FONTNAME', (0, 1), (2, 1), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 1), (2, 1), 16),
            ('TEXTCOLOR', (0, 1), (2, 1), colors.black),
            ('TOPPADDING', (0, 1), (2, 1), 8),
            ('BOTTOMPADDING', (0, 1), (2, 1), 8),
            
            # Período (spanning)
            ('SPAN', (0, 2), (2, 2)),
            ('ALIGN', (0, 2), (2, 2), 'CENTER'),
            ('FONTNAME', (0, 2), (2, 2), 'Helvetica'),
            ('FONTSIZE', (0, 2), (2, 2), 10),
            ('TEXTCOLOR', (0, 2), (2, 2), colors.black),
            ('TOPPADDING', (0, 2), (2, 2), 4),
            ('BOTTOMPADDING', (0, 2), (2, 2), 8),
            
            # Línea separadora debajo
            ('LINEBELOW', (0, 2), (2, 2), 2, colors.black),
            
            # Sin bordes internos
            ('GRID', (0, 0), (2, 2), 0, colors.white),
        ]))
        
        return encabezado_tabla
    
    def _crear_logo_texto_profesional(self):
        """Crea un logo profesional usando solo texto"""
        logo_style = ParagraphStyle(
            'LogoStyleProfesional',
            fontSize=14,
            alignment=TA_CENTER,
            fontName='Helvetica-Bold',
            textColor=colors.Color(0.17, 0.24, 0.31),  # Color CMI #2C3E50
            leading=16,
            leftIndent=5,
            rightIndent=5,
            spaceBefore=5,
            spaceAfter=5
        )
        
        # Logo más profesional con mejor formato
        logo_html = """
        <para align="center">
        <font name="Helvetica-Bold" size="16" color="#2C3E50">CMI</font><br/>
        <font name="Helvetica" size="8" color="#2C3E50">CLÍNICA MARÍA</font><br/>
        <font name="Helvetica" size="8" color="#2C3E50">INMACULADA</font>
        </para>
        """
        
        return Paragraph(logo_html, logo_style)
    
    def _crear_pie_pagina_manual(self):
        """Crea el pie de página manualmente"""
        from datetime import datetime
        
        # Información del pie
        fecha_generacion = datetime.now().strftime("%d/%m/%Y %H:%M")
        
        pie_data = [
            ["Página 1", f"Generado el {fecha_generacion}"],
            ["", "Sistema de Gestión Médica - Documento generado automáticamente"]
        ]
        
        pie_tabla = Table(pie_data, colWidths=[95*mm, 95*mm])
        
        pie_tabla.setStyle(TableStyle([
            # Línea separadora arriba
            ('LINEABOVE', (0, 0), (1, 0), 1, colors.black),
            
            # Primera fila
            ('FONTNAME', (0, 0), (1, 0), 'Helvetica'),
            ('FONTSIZE', (0, 0), (1, 0), 9),
            ('ALIGN', (0, 0), (0, 0), 'LEFT'),
            ('ALIGN', (1, 0), (1, 0), 'RIGHT'),
            ('TOPPADDING', (0, 0), (1, 0), 6),
            
            # Segunda fila
            ('SPAN', (0, 1), (1, 1)),
            ('ALIGN', (0, 1), (1, 1), 'CENTER'),
            ('FONTNAME', (0, 1), (1, 1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (1, 1), 8),
            ('TEXTCOLOR', (0, 1), (1, 1), colors.grey),
            ('TOPPADDING', (0, 1), (1, 1), 2),
            
            # Sin bordes
            ('GRID', (0, 0), (1, 1), 0, colors.white),
        ]))
        
        return pie_tabla
    
    def _crear_tabla_profesional(self, datos, tipo_reporte):
        """Crea tabla con estilo profesional y zebra striping"""
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
        
        # Aplicar estilos profesionales
        estilos_tabla = [
            # Encabezado
            ('BACKGROUND', (0, 0), (-1, 0), colors.black),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 10),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
            ('TOPPADDING', (0, 0), (-1, 0), 8),
            
            # Datos (zebra striping)
            ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -2), 9),
            ('TOPPADDING', (0, 1), (-1, -2), 4),
            ('BOTTOMPADDING', (0, 1), (-1, -2), 4),
            ('LEFTPADDING', (0, 1), (-1, -2), 6),
            ('RIGHTPADDING', (0, 1), (-1, -2), 6),
            
            # Fila de total
            ('BACKGROUND', (0, -1), (-1, -1), colors.lightgrey),
            ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
            ('FONTSIZE', (0, -1), (-1, -1), 10),
            ('TOPPADDING', (0, -1), (-1, -1), 6),
            ('BOTTOMPADDING', (0, -1), (-1, -1), 6),
            ('ALIGN', (-2, -1), (-1, -1), 'RIGHT'),
            
            # Bordes horizontales únicamente
            ('LINEBELOW', (0, 0), (-1, 0), 2, colors.black),
            ('LINEABOVE', (0, -1), (-1, -1), 1, colors.black),
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
    
    def _crear_resumen_profesional(self, datos):
        """Crea sección de resumen profesional"""
        styles = getSampleStyleSheet()
        
        # Calcular totales
        total_registros = len(datos)
        total_valor = sum(float(item.get('valor', 0)) for item in datos)
        valor_promedio = total_valor / total_registros if total_registros > 0 else 0
        
        # Estilo para resumen
        resumen_style = ParagraphStyle(
            'ResumenProfesional',
            parent=styles['Normal'],
            fontSize=10,
            spaceBefore=5*mm,
            spaceAfter=5*mm,
            alignment=TA_LEFT,
            fontName='Helvetica'
        )
        
        # Crear tabla de resumen
        resumen_datos = [
            ['RESUMEN EJECUTIVO', ''],
            ['Total de Registros:', f'{total_registros:,}'],
            ['Valor Total:', f'Bs {total_valor:,.2f}'],
            ['Valor Promedio:', f'Bs {valor_promedio:,.2f}']
        ]
        
        resumen_tabla = Table(resumen_datos, colWidths=[60*mm, 40*mm])
        resumen_tabla.setStyle(TableStyle([
            # Primera fila (título)
            ('BACKGROUND', (0, 0), (-1, 0), colors.black),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 11),
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
        if isinstance(valor, str) and len(valor) > 50:
            return valor[:47] + "..."
        
        return str(valor)

# Funciones de utilidad
def crear_generador_pdf():
    """Función factoría para crear una instancia del generador de PDFs"""
    return GeneradorReportesPDF()

def generar_pdf_reporte(datos_json, tipo_reporte, fecha_desde, fecha_hasta):
    """Función de conveniencia para generar un PDF directamente"""
    generador = GeneradorReportesPDF()
    return generador.generar_reporte_pdf(datos_json, tipo_reporte, fecha_desde, fecha_hasta)