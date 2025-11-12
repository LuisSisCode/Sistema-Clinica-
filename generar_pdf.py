"""
Módulo para generar reportes PDF profesionales - VERSIÓN OPTIMIZADA
Sistema de Gestión Médica - Clínica María Inmaculada
Versión 5.0 - Tablas Optimizadas y Unificadas
✅ INCLUYE: Campo "Responsable" con usuario actual
"""

import os
from pathlib import Path
import sys
from typing import List, Dict, Any
import json
from datetime import datetime
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, mm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Image
from reportlab.platypus import PageTemplate, Frame, BaseDocTemplate
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader

# ============================================
# CONSTANTES GLOBALES DE ANCHOS (en mm)
# ============================================

# Anchos base optimizados
ANCHO_FECHA_COMPLETA = 26    # DD/MM/YYYY
ANCHO_FECHA_CORTA = 22       # DD/MM HH:MM
ANCHO_HORA = 15              # HH:MM

ANCHO_CODIGO_CORTO = 20      # V001, C123
ANCHO_CODIGO_MEDIO = 25      # IDs más largos

ANCHO_CANTIDAD = 15          # 1-3 dígitos
ANCHO_VALOR_CORTO = 22       # Bs 12.50
ANCHO_VALOR_MEDIO = 26       # Bs 1,234.56
ANCHO_VALOR_LARGO = 35       # +Bs 12,345.67

ANCHO_TEXTO_CORTO = 25       # Tipos, estados
ANCHO_TEXTO_MEDIO = 35       # Nombres, apellidos
ANCHO_TEXTO_LARGO = 50       # Descripciones cortas
ANCHO_TEXTO_EXTRA_LARGO = 85 # Descripciones largas

ANCHO_PORCENTAJE = 18        # 99.9%

# ============================================
# CLASE DE UTILIDADES DE FORMATO
# ============================================

class FormatUtils:
    """Utilidades de formato centralizadas"""
    
    @staticmethod
    def formato_moneda(valor, mostrar_signo=False):
        """Formato: Bs 1,234.56 o +Bs 1,234.56"""
        try:
            valor_float = float(valor)
            signo = ""
            if mostrar_signo:
                signo = "+" if valor_float >= 0 else ""
            return f"{signo}Bs {abs(valor_float):,.2f}"
        except:
            return "Bs 0.00"
    
    @staticmethod
    def formato_fecha_hora(fecha_completa):
        """Formato: 15/10 21:05"""
        try:
            if isinstance(fecha_completa, str):
                # "15/10/2025 21:05:30" → "15/10 21:05"
                partes = fecha_completa.split()
                if len(partes) >= 2:
                    fecha = partes[0].split('/')
                    hora = partes[1].split(':')
                    if len(fecha) >= 2 and len(hora) >= 2:
                        return f"{fecha[0]}/{fecha[1]} {hora[0]}:{hora[1]}"
            return str(fecha_completa)[:10]
        except:
            return "---"
    
    @staticmethod
    def formato_numero(numero, decimales=0):
        """Formato: 1,234 o 1,234.56"""
        try:
            if decimales > 0:
                return f"{float(numero):,.{decimales}f}"
            else:
                return f"{int(float(numero)):,}"
        except:
            return "0"

# Colores profesionales mejorados
COLOR_AZUL_PRINCIPAL = colors.Color(0.12, 0.31, 0.52)  # Azul institucional
COLOR_AZUL_CLARO = colors.Color(0.85, 0.92, 0.97)      # Azul claro para fondos
COLOR_ROJO_ACENTO = colors.Color(0.8, 0.2, 0.2)        # Rojo para acentos
COLOR_GRIS_OSCURO = colors.Color(0.2, 0.2, 0.2)        # Gris oscuro
COLOR_GRIS_CLARO = colors.Color(0.95, 0.95, 0.95)      # Gris claro
COLOR_VERDE_POSITIVO = colors.Color(0.13, 0.54, 0.13)  # Verde para valores positivos
COLOR_NARANJA_EGRESO = colors.Color(0.8, 0.4, 0.1)     # Naranja para egresos

class CanvasNumerosPaginaProfesional(canvas.Canvas):
    """
    Canvas personalizado con diseño profesional estilo gubernamental
    ✅ MODIFICADO: Incluye usuario responsable en pie de página
    """
    
    def __init__(self, *args, **kwargs):
        canvas.Canvas.__init__(self, *args, **kwargs)
        self._saved_page_states = []
        self.logo_path = None
        self.titulo_reporte = ""
        self.fecha_desde = ""
        self.fecha_hasta = ""
        self.fecha_generacion = ""
        
        # ✅ NUEVO: Información del responsable
        self.usuario_responsable = ""
        self.usuario_rol = ""
    
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
        """
        Dibuja pie de página profesional
        ✅ MODIFICADO: Incluye usuario responsable
        """
        # Línea superior del pie de página
        self.setStrokeColor(COLOR_AZUL_PRINCIPAL)
        self.setLineWidth(2)
        self.line(25*mm, 35*mm, letter[0]-25*mm, 35*mm)
        
        # Información del pie de página
        self.setFont("Helvetica", 9)
        self.setFillColor(COLOR_GRIS_OSCURO)
        
        # Página (izquierda)
        self.drawString(25*mm, 28*mm, f"Página {page_num} de {total_pages}")
        
        # ✅ CAMBIO: Usuario responsable (derecha superior)
        if self.usuario_responsable:
            fecha_texto = f"Generado: {self.fecha_generacion} - {self.usuario_responsable}"
        else:
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
    Generador de reportes PDF con diseño profesional optimizado
    ✅ INCLUYE: Campo "Responsable" con usuario actual
    """
    
    def __init__(self):
        """
        Inicializa el generador con configuración por defecto
        ✅ CORREGIDO: Solo usar directorios en APPDATA, no en la ruta de instalación
        """

        # ✅ DETERMINAR DIRECTORIO DE REPORTES (solo en APPDATA)
        if getattr(sys, 'frozen', False):
            # Ejecutable: reportes en APPDATA del usuario
            base_dir = Path(os.environ.get('APPDATA', Path.home())) / 'ClinicaMariaInmaculada'
        else:
            # Desarrollo: reportes en carpeta del proyecto
            base_dir = Path(__file__).parent

        # Directorio de PDFs (Path para mayor flexibilidad)
        self.pdf_dir = base_dir / 'reportes'
        try:
            self.pdf_dir.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            # Fallback seguro al directorio de usuario
            self.pdf_dir = Path.home() / 'ClinicaMariaInmaculada' / 'reportes'
            self.pdf_dir.mkdir(parents=True, exist_ok=True)

        # Configuración de página
        self.page_width, self.page_height = A4
        self.margin = 50

        # ✅ ELIMINADO: No intentar crear assets_dir en la ruta de instalación
        # En su lugar, usamos el directorio de reportes para los PDFs y el logo se busca en recursos embebidos.

        # Inicializar logo y campos relacionados
        self.logo_path = None
        try:
            self.setup_logo()
        except Exception:
            # No detener inicialización si setup_logo falla
            self.logo_path = None

        # Forzar ruta específica si existe
        ruta_especifica = "Resources/iconos/Logo_de_Emergencia_Médica_RGL-removebg-preview.png"
        if os.path.exists(ruta_especifica):
            self.logo_path = ruta_especifica
            print(f"✅ Usando logo en ruta específica: {self.logo_path}")

        # ✅ NUEVO: Información del responsable (se establecerá antes de generar)
        self._usuario_responsable_nombre = ""
        self._usuario_responsable_rol = ""
    
    def setup_logo(self):
        """Configurar logo para PDF - MEJORADO con búsqueda más exhaustiva"""
        logo_paths = []
        
        # Si es ejecutable, buscar en el directorio del ejecutable
        if getattr(sys, 'frozen', False):
            base_dir = Path(sys.executable).parent
            logo_paths.extend([
                base_dir / "Resources" / "iconos" / "Logo_de_Emergencia_Médica_RGL-removebg-preview.png",
                base_dir / "Resources" / "iconos" / "logo.png",
                base_dir / "Resources" / "iconos" / "logo_CMI.png",
                base_dir / "iconos" / "Logo_de_Emergencia_Médica_RGL-removebg-preview.png",
                base_dir / "iconos" / "logo.png",
                base_dir / "iconos" / "logo_CMI.png",
            ])
        
        # También buscar en el directorio del script (desarrollo)
        script_dir = Path(__file__).parent
        logo_paths.extend([
            script_dir / "Resources" / "iconos" / "Logo_de_Emergencia_Médica_RGL-removebg-preview.png",
            script_dir / "Resources" / "iconos" / "logo.png",
            script_dir / "Resources" / "iconos" / "logo_CMI.png",
            script_dir / ".." / "Resources" / "iconos" / "Logo_de_Emergencia_Médica_RGL-removebg-preview.png",
            script_dir / ".." / "Resources" / "iconos" / "logo.png",
            script_dir / ".." / "Resources" / "iconos" / "logo_CMI.png",
            # Ruta específica que mencionaste
            Path("Resources/iconos/Logo_de_Emergencia_Médica_RGL-removebg-preview.png"),
        ])
        
        self.logo_path = None
        for logo_path in logo_paths:
            try:
                if logo_path.exists():
                    self.logo_path = str(logo_path)
                    print(f"✅ Logo encontrado: {self.logo_path}")
                    break
            except Exception as e:
                continue
        
        if not self.logo_path:
            print("⚠️ Logo no encontrado en ninguna ruta, usando logo profesional de texto")
    
    # ✅ NUEVO MÉTODO: Establecer responsable antes de generar PDF
    def set_responsable(self, nombre: str, rol: str):
        """
        Establece el usuario responsable de generar el reporte
        
        Args:
            nombre: Nombre completo del usuario (ej: "Carlos Mendez")
            rol: Rol del usuario (ej: "Administrador", "Médico")
        """
        self._usuario_responsable_nombre = nombre
        self._usuario_responsable_rol = rol
        print(f"📋 Responsable establecido: {nombre} ({rol})")
    
    def generar_reporte_pdf(self, datos_json, tipo_reporte, fecha_desde, fecha_hasta):
        """Método principal para generar un PDF del reporte - ✅ CON RESPONSABLE"""
        try:
            print(f"📄 Iniciando generación de PDF optimizado - Tipo: {tipo_reporte}")
            
            # ✅ VALIDAR QUE SE HAYA ESTABLECIDO EL RESPONSABLE
            if not self._usuario_responsable_nombre:
                print("⚠️ ADVERTENCIA: Responsable no establecido, usando 'Sistema'")
                self._usuario_responsable_nombre = "Sistema de Gestión Médica"
                self._usuario_responsable_rol = "Sistema"
            
            # ✅ VALIDAR ENTRADA JSON
            if not datos_json or datos_json.strip() == "":
                print("❌ datos_json vacío")
                return ""
            
            # ✅ PARSEAR JSON CON VALIDACIÓN
            try:
                datos = json.loads(datos_json)
            except json.JSONDecodeError as json_error:
                print(f"❌ Error parseando JSON: {json_error}")
                return ""
            
            # ✅ VALIDAR QUE datos NO SEA None
            if datos is None:
                print("❌ Datos parseados son None")
                return ""
            
            # ✅ VALIDAR tipo_reporte
            try:
                tipo_reporte_int = int(tipo_reporte)
            except (ValueError, TypeError):
                print(f"❌ tipo_reporte inválido: {tipo_reporte}")
                return ""
            
            # ✅ VALIDAR FECHAS
            if not fecha_desde or not fecha_hasta:
                print("❌ Fechas vacías")
                return ""
            
            filename = self._generar_nombre_archivo(tipo_reporte_int, fecha_desde, fecha_hasta)
            filepath = os.path.join(self.pdf_dir, filename)
            
            # ✅ CREAR PDF CON MANEJO DE ERRORES
            try:
                success = self._crear_pdf_profesional_optimizado(
                    filepath, datos, tipo_reporte_int, fecha_desde, fecha_hasta
                )
            except Exception as pdf_error:
                print(f"❌ Error creando PDF: {pdf_error}")
                import traceback
                traceback.print_exc()
                return ""
            
            if success:
                print(f"✅ PDF optimizado generado: {filepath}")
                return filepath
            else:
                print("⚠️ Error al generar PDF")
                return ""
                
        except Exception as e:
            print(f"⚠️ Error en generar_reporte_pdf: {e}")
            import traceback
            traceback.print_exc()
            return ""  # ✅ SIEMPRE RETORNAR STRING (vacío en error)
    
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
            8: "Análisis Financiero",
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
    
    def _crear_pdf_profesional_optimizado(self, filepath, datos, tipo_reporte, fecha_desde, fecha_hasta):
        """
        Crea el archivo PDF con diseño profesional optimizado
        ✅ MODIFICADO: Pasa información del responsable al canvas
        """
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
            
            # ✅ MODIFICAR: Pasar info del responsable al template
            def add_page_elements(canvas, doc):
                # Establecer información del responsable en el canvas
                canvas.usuario_responsable = self._usuario_responsable_nombre
                canvas.usuario_rol = self._usuario_responsable_rol
                canvas.fecha_generacion = self._fecha_generacion
                
                # Llamar al método de encabezado
                self._crear_encabezado_profesional_mejorado(canvas, doc)
            
            # Template de página profesional
            template = PageTemplate(
                id='todas_paginas',
                frames=[frame],
                onPage=add_page_elements,  # ✅ Usar función modificada
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
                print("💰 Generando Reporte de Ingresos y Egresos optimizado...")
                story.extend(self._crear_reporte_ingresos_egresos_completo(datos, fecha_desde, fecha_hasta))
            elif tipo_reporte == 9:
                print("💰 Generando Arqueo de Caja optimizado...")
                story.extend(self._crear_arqueo_caja_completo(datos, fecha_desde, fecha_hasta))
            else:
                # Información del reporte estándar
                print("📋 Agregando información del reporte...")
                info_elementos = self._crear_informacion_reporte_mejorada()
                story.extend(info_elementos)
                story.append(Spacer(1, 8*mm))
                
                # Contenido principal optimizado
                if datos and len(datos) > 0:
                    print("📊 Agregando tabla optimizada...")
                    tablas = self._crear_tabla_profesional_optimizada(datos, tipo_reporte)
                    if isinstance(tablas, list):
                        story.extend(tablas)
                    else:
                        story.append(tablas)
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
            print(f"⚠️ Error creando PDF profesional optimizado: {e}")
            print(f"🔍 Error en tipo de reporte: {tipo_reporte}")
            print(f"🔍 Número de registros: {len(datos) if datos else 0}")
            import traceback
            traceback.print_exc()
            return False

    # ============================================
    # MÉTODOS OPTIMIZADOS PARA TABLAS
    # ============================================

    def _crear_tabla_profesional_optimizada(self, datos, tipo_reporte):
        """Crea tabla con estilo COMPLETAMENTE OPTIMIZADO Y PAGINADO"""
        from reportlab.platypus import Table, TableStyle, PageBreak
        
        # Obtener definición de columnas optimizadas
        columnas_def = self._obtener_columnas_reporte_optimizadas(tipo_reporte)
        
        # ✅ NUEVO: Control de filas por página
        FILAS_POR_PAGINA = 25  # Máximo de filas antes de page break
        
        if len(datos) > FILAS_POR_PAGINA:
            # Dividir en múltiples tablas
            tablas = []
            for i in range(0, len(datos), FILAS_POR_PAGINA):
                chunk = datos[i:i+FILAS_POR_PAGINA]
                tabla_chunk = self._crear_tabla_chunk(chunk, tipo_reporte, columnas_def, i==0)
                tablas.append(tabla_chunk)
                
                # PageBreak entre tablas excepto la última
                if i + FILAS_POR_PAGINA < len(datos):
                    tablas.append(PageBreak())
            
            return tablas
        else:
            # Tabla única como antes
            return self._crear_tabla_unica(datos, tipo_reporte, columnas_def)

    def _crear_tabla_chunk(self, chunk_datos, tipo_reporte, columnas_def, es_primera=False):
        """Crea una parte de la tabla con encabezados"""
        # Preparar datos
        encabezados = [col[0] for col in columnas_def]
        anchos_columnas = [col[1]*mm for col in columnas_def]
        
        tabla_datos = [encabezados]
        total_valor = 0
        
        # Agregar filas de datos del chunk
        for registro in chunk_datos:
            fila = []
            for col_titulo, ancho, alineacion in columnas_def:
                valor = self._obtener_valor_campo_optimizado(registro, col_titulo, tipo_reporte)
                fila.append(valor)
            
            tabla_datos.append(fila)
            
            # Calcular totales parciales
            try:
                valor_monetario = float(registro.get('valor', 0))
                total_valor += valor_monetario
            except (ValueError, TypeError):
                continue
        
        # Solo agregar fila de total si es el último chunk
        if es_primera:
            fila_total = self._crear_fila_total(columnas_def, total_valor, tipo_reporte)
            tabla_datos.append(fila_total)

        # Crear tabla
        tabla = Table(
            tabla_datos, 
            colWidths=anchos_columnas, 
            repeatRows=1,
            splitByRow=1,
            spaceAfter=12,
            spaceBefore=12,
            hAlign='CENTER'
        )

        # Aplicar estilos unificados
        estilos_base = self._crear_estilos_tabla_unificados()
        
        # Aplicar alineaciones específicas por columna
        for col_idx, (col_titulo, ancho, alineacion) in enumerate(columnas_def):
            align_map = {'LEFT': 'LEFT', 'RIGHT': 'RIGHT', 'CENTER': 'CENTER'}
            tabla_align = align_map.get(alineacion, 'LEFT')
            
            # Alineación para datos normales
            estilos_base.append(('ALIGN', (col_idx, 1), (col_idx, -2), tabla_align))
            
            # Alineación para fila de total (si existe)
            if es_primera:
                estilos_base.append(('ALIGN', (col_idx, -1), (col_idx, -1), 'RIGHT'))

        tabla.setStyle(TableStyle(estilos_base))
        
        return tabla

    def _crear_tabla_unica(self, datos, tipo_reporte, columnas_def):
        """Crea tabla única para conjuntos de datos pequeños"""
        # Preparar datos
        encabezados = [col[0] for col in columnas_def]
        anchos_columnas = [col[1]*mm for col in columnas_def]
        
        tabla_datos = [encabezados]
        total_valor = 0
        
        # Agregar filas de datos
        for registro in datos:
            fila = []
            for col_titulo, ancho, alineacion in columnas_def:
                valor = self._obtener_valor_campo_optimizado(registro, col_titulo, tipo_reporte)
                fila.append(valor)
            
            tabla_datos.append(fila)
            
            # Calcular totales
            try:
                valor_monetario = float(registro.get('valor', 0))
                total_valor += valor_monetario
            except (ValueError, TypeError):
                continue

        # Fila de total
        fila_total = self._crear_fila_total(columnas_def, total_valor, tipo_reporte)
        tabla_datos.append(fila_total)

        # Crear tabla
        tabla = Table(
            tabla_datos, 
            colWidths=anchos_columnas, 
            repeatRows=1,
            splitByRow=1,
            spaceAfter=12,
            spaceBefore=12,
            hAlign='CENTER'
        )

        # Aplicar estilos unificados
        estilos_base = self._crear_estilos_tabla_unificados()
        
        # Aplicar alineaciones específicas por columna
        for col_idx, (col_titulo, ancho, alineacion) in enumerate(columnas_def):
            align_map = {'LEFT': 'LEFT', 'RIGHT': 'RIGHT', 'CENTER': 'CENTER'}
            tabla_align = align_map.get(alineacion, 'LEFT')
            
            estilos_base.append(('ALIGN', (col_idx, 1), (col_idx, -2), tabla_align))
            estilos_base.append(('ALIGN', (col_idx, -1), (col_idx, -1), 'RIGHT'))

        tabla.setStyle(TableStyle(estilos_base))
        
        return tabla

    def _crear_fila_total(self, columnas_def, total_valor, tipo_reporte):
        """Crea fila de total optimizada"""
        fila_total = [""] * len(columnas_def)
        
        # ✅ MAPEO ESPECÍFICO OPTIMIZADO PARA CADA TIPO DE REPORTE
        if tipo_reporte == 1:  # Ventas de Farmacia
            for i, (col_titulo, ancho, alineacion) in enumerate(columnas_def):
                if col_titulo in ["VENDEDOR", "USUARIO"]:
                    fila_total[i] = "TOTAL GENERAL:"
                elif col_titulo in ["TOTAL", "TOTAL (Bs)", "VALOR (Bs)"]:
                    fila_total[i] = FormatUtils.formato_moneda(total_valor)
        
        elif tipo_reporte == 7:  # Gastos Operativos
            for i, (col_titulo, ancho, alineacion) in enumerate(columnas_def):
                if col_titulo == "CONCEPTO":
                    fila_total[i] = "TOTAL GENERAL:"
                elif col_titulo in ["MONTO", "VALOR"]:
                    fila_total[i] = FormatUtils.formato_moneda(total_valor)
        
        elif tipo_reporte == 8:  # Ingresos y Egresos
            for i, (col_titulo, ancho, alineacion) in enumerate(columnas_def):
                if col_titulo == "CONCEPTO":
                    fila_total[i] = "SALDO NETO:"
                elif col_titulo == "VALOR":
                    fila_total[i] = FormatUtils.formato_moneda(total_valor, mostrar_signo=True)
        
        else:  # Otros reportes (2, 3, 4, 5, 6)
            if len(columnas_def) >= 2:
                fila_total[-2] = "TOTAL GENERAL:"
                fila_total[-1] = FormatUtils.formato_moneda(total_valor)
            else:
                fila_total[0] = f"TOTAL GENERAL: {FormatUtils.formato_moneda(total_valor)}"

        return fila_total

    def _obtener_columnas_reporte_optimizadas(self, tipo_reporte):
        """Define las columnas con ANCHOS OPTIMIZADOS Y ESTANDARIZADOS"""
        
        columnas = {
            1: [  # Ventas de Farmacia - ✅ OPTIMIZADO
                ("FECHA/HORA", ANCHO_FECHA_CORTA, 'LEFT'),
                ("PRODUCTO", ANCHO_TEXTO_EXTRA_LARGO, 'LEFT'),
                ("CANT", ANCHO_CANTIDAD, 'RIGHT'),
                ("P.UNIT", ANCHO_VALOR_CORTO, 'RIGHT'),
                ("VENDEDOR", ANCHO_TEXTO_MEDIO, 'LEFT'),
                ("TOTAL", ANCHO_VALOR_MEDIO, 'RIGHT')
            ],
            
            2: [  # Inventario - ✅ OPTIMIZADO
                ("PRODUCTO / MARCA", ANCHO_TEXTO_EXTRA_LARGO + 5, 'LEFT'),
                ("LOTE", ANCHO_TEXTO_CORTO, 'CENTER'),
                ("STOCK", ANCHO_CANTIDAD, 'RIGHT'),
                ("P.UNIT", ANCHO_VALOR_CORTO, 'RIGHT'),
                ("F.VENC", ANCHO_FECHA_CORTA, 'LEFT'),
                ("VALOR", ANCHO_VALOR_MEDIO, 'RIGHT')
            ],
            
            3: [  # Compras - ✅ OPTIMIZADO
                ("FECHA", ANCHO_FECHA_CORTA, 'LEFT'),
                ("PRODUCTO", ANCHO_TEXTO_EXTRA_LARGO, 'LEFT'),
                ("UNID", ANCHO_CANTIDAD, 'RIGHT'),
                ("PROVEEDOR", ANCHO_TEXTO_MEDIO, 'LEFT'),
                ("F.VENC", ANCHO_FECHA_CORTA, 'LEFT'),
                ("TOTAL", ANCHO_VALOR_MEDIO, 'RIGHT')
            ],
            
            4: [  # Consultas Médicas - ✅ OPTIMIZADO
                ("FECHA/HORA", ANCHO_FECHA_CORTA, 'LEFT'),
                ("ESPECIALIDAD", ANCHO_TEXTO_LARGO, 'LEFT'),
                ("PACIENTE", ANCHO_TEXTO_MEDIO, 'LEFT'),
                ("MÉDICO", ANCHO_TEXTO_MEDIO, 'LEFT'),
                ("PRECIO", ANCHO_VALOR_MEDIO, 'RIGHT')
            ],
            
            5: [  # Laboratorio - ✅ OPTIMIZADO
                ("FECHA/HORA", ANCHO_FECHA_CORTA, 'LEFT'),
                ("ANÁLISIS", ANCHO_TEXTO_EXTRA_LARGO, 'LEFT'),
                ("PACIENTE", ANCHO_TEXTO_MEDIO, 'LEFT'),
                ("TÉCNICO", ANCHO_TEXTO_MEDIO, 'LEFT'),
                ("PRECIO", ANCHO_VALOR_MEDIO, 'RIGHT')
            ],
            
            6: [  # Enfermería - ✅ OPTIMIZADO
                ("FECHA/HORA", ANCHO_FECHA_CORTA, 'LEFT'),
                ("PROCEDIMIENTO", ANCHO_TEXTO_EXTRA_LARGO, 'LEFT'),
                ("PACIENTE", ANCHO_TEXTO_MEDIO, 'LEFT'),
                ("ENFERMERO/A", ANCHO_TEXTO_MEDIO, 'LEFT'),
                ("PRECIO", ANCHO_VALOR_MEDIO, 'RIGHT')
            ],
            
            7: [  # Gastos - ✅ OPTIMIZADO
                ("FECHA", ANCHO_FECHA_CORTA, 'LEFT'),
                ("CONCEPTO", ANCHO_TEXTO_EXTRA_LARGO, 'LEFT'),
                ("PROVEEDOR", ANCHO_TEXTO_MEDIO, 'LEFT'),
                ("MONTO", ANCHO_VALOR_MEDIO, 'RIGHT')
            ],
            
            8: [  # Consolidado - ✅ OPTIMIZADO
                ("FECHA/HORA", ANCHO_FECHA_CORTA, 'LEFT'),
                ("CONCEPTO", ANCHO_TEXTO_EXTRA_LARGO, 'LEFT'),
                ("TIPO", ANCHO_TEXTO_CORTO, 'CENTER'),
                ("VALOR", ANCHO_VALOR_LARGO, 'RIGHT')
            ]
        }
        
        return columnas.get(tipo_reporte, [
            ("FECHA", ANCHO_FECHA_CORTA, 'LEFT'),
            ("DESCRIPCIÓN", ANCHO_TEXTO_EXTRA_LARGO, 'LEFT'),
            ("VALOR", ANCHO_VALOR_MEDIO, 'RIGHT')
        ])

    def _obtener_valor_campo_optimizado(self, registro, campo_titulo, tipo_reporte):
        """Extrae valores con FORMATO UNIFICADO Y OPTIMIZADO"""
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.platypus import Paragraph
        from reportlab.lib.enums import TA_LEFT
        
        # ✅ MAPEO OPTIMIZADO CON FORMATO UNIFICADO
        mapeo_campos = {
            # CAMPOS BÁSICOS
            "FECHA/HORA": "fecha",
            "FECHA": "fecha",
            "DESCRIPCIÓN": "descripcion", 
            "CONCEPTO": "descripcion",
            "CANTIDAD": "cantidad",
            "CANT": "cantidad",
            "UNID": "cantidad",
            "UNIDADES": "cantidad",
            
            # VALORES MONETARIOS
            "PRECIO": "valor",
            "TOTAL": "valor", 
            "VALOR": "valor",
            "MONTO": "valor",
            "P.UNIT": "precio_unitario", 
            
            # CAMPOS ESPECÍFICOS
            "PRODUCTO": "descripcion",
            "PRODUCTO / MARCA": "descripcion",
            "ANÁLISIS": "analisis",
            "PROCEDIMIENTO": "procedimiento",
            "ESPECIALIDAD": "especialidad",
            "PACIENTE": "paciente",
            "MÉDICO": "doctor_nombre",
            "TÉCNICO": "laboratorista",
            "ENFERMERO/A": "enfermero",
            "VENDEDOR": "usuario",
            "PROVEEDOR": "proveedor",
            "LOTE": "lote",
            "F.VENC": "fecha_vencimiento",
            "TIPO": "tipo",
            "STOCK": "cantidad"
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

        # ✅ PROCESAMIENTO UNIFICADO CON FormatUtils

        # 1. Campos de fecha/hora
        if campo_titulo in ["FECHA/HORA", "FECHA"]:
            return FormatUtils.formato_fecha_hora(valor)
        
        # 2. Campos monetarios
        elif any(palabra in campo_titulo.upper() for palabra in ["PRECIO", "TOTAL", "VALOR", "MONTO", "P.UNIT"]):
            try:
                if campo_titulo == "P.UNIT":
                    precio = float(registro.get('precio_unitario', 0))
                    return FormatUtils.formato_moneda(float(precio))
                elif tipo_reporte == 8 and campo_titulo == "VALOR":
                    # Para ingresos/egresos mostrar con signo
                    tipo_movimiento = registro.get('tipo', '')
                    mostrar_signo = tipo_movimiento in ['INGRESO', 'EGRESO']
                    return FormatUtils.formato_moneda(float(valor), mostrar_signo)
                else:
                    return FormatUtils.formato_moneda(float(valor))
            except:
                return FormatUtils.formato_moneda(0)
        
        # 3. Campos numéricos
        elif campo_titulo in ["CANT", "UNID", "STOCK", "CANTIDAD"]:
            return FormatUtils.formato_numero(valor)
        
        # 4. Campos de texto largo (usar Paragraph)
        elif campo_titulo in ["PRODUCTO", "PRODUCTO / MARCA", "CONCEPTO", "DESCRIPCIÓN", 
                             "ANÁLISIS", "PROCEDIMIENTO", "ESPECIALIDAD"]:
            if not valor:
                valor = "Sin descripción"
            
            if len(valor) > 40:
                return crear_parrafo(valor)
            return valor
        
        # 5. Campos de texto medio
        elif campo_titulo in ["PACIENTE", "MÉDICO", "TÉCNICO", "ENFERMERO/A", "VENDEDOR", "PROVEEDOR"]:
            if not valor:
                valor = "Sin asignar"
            
            if len(valor) > 25:
                return crear_parrafo(valor)
            return valor
        
        # 6. Campo LOTE
        elif campo_titulo == "LOTE":
            if not valor or valor == "":
                return "---"
            return str(valor)[:15]
        
        # 7. Campo F.VENC
        elif campo_titulo == "F.VENC":
            if not valor or str(valor) in ["", "None", "null"]:
                return "Sin venc."
            return FormatUtils.formato_fecha_hora(valor)
        
        # 8. Campo TIPO
        elif campo_titulo == "TIPO":
            tipo = str(valor).upper()
            return tipo if tipo in ['INGRESO', 'EGRESO', 'NORMAL', 'EMERGENCIA'] else 'NORMAL'
        
        # 9. Genérico con fallback
        if not valor or valor == "":
            return "---"
        
        # Formatear valor final
        if len(str(valor)) > 30:
            return crear_parrafo(str(valor))
        
        return str(valor)

    # ============================================
    # MÉTODOS DE INFORMACIÓN Y ANÁLISIS
    # ============================================

    def _crear_informacion_reporte_mejorada(self):
        """
        Crea sección de información del reporte 
        ✅ ALINEACIÓN A LA IZQUIERDA (no centrada)
        ✅ Diseño profesional y compacto
        """
        try:
            styles = getSampleStyleSheet()
            
            # ✅ Estilo para el título específico del reporte (IZQUIERDA)
            titulo_especifico_style = ParagraphStyle(
                'TituloEspecifico',
                parent=styles['Normal'],
                fontSize=18,
                fontName='Helvetica-Bold',
                textColor=COLOR_AZUL_PRINCIPAL,
                spaceAfter=12,
                spaceBefore=6,
                alignment=TA_CENTER  # Mantener centrado como en la imagen
            )
            
            # ✅ Estilo para la información (IZQUIERDA)
            info_style = ParagraphStyle(
                'InfoReporte',
                parent=styles['Normal'],
                fontSize=11,
                fontName='Helvetica',
                textColor=COLOR_GRIS_OSCURO,
                spaceAfter=3,
                leftIndent=0,
                alignment=TA_LEFT  # ✅ CAMBIO PRINCIPAL: Alineado a la izquierda
            )
            
            # Crear contenido
            contenido = []
            
            # Título específico del tipo de reporte (centrado)
            titulo_reporte = self._obtener_titulo_reporte(self._tipo_reporte)
            contenido.append(Paragraph(titulo_reporte, titulo_especifico_style))
            
            # ✅ INFORMACIÓN ESENCIAL CON RESPONSABLE - ALINEADA A LA IZQUIERDA
            contenido.append(Paragraph(
                f"<b>Período de Análisis:</b> {self._fecha_desde} al {self._fecha_hasta}", 
                info_style
            ))
            contenido.append(Paragraph(
                f"<b>Fecha de Generación:</b> {self._fecha_generacion}", 
                info_style
            ))
            
            # Usuario responsable con su rol
            if self._usuario_responsable_rol != "Sistema":
                responsable_texto = f"<b>Responsable:</b> {self._usuario_responsable_nombre} ({self._usuario_responsable_rol})"
            else:
                responsable_texto = f"<b>Responsable:</b> {self._usuario_responsable_nombre}"
            
            contenido.append(Paragraph(responsable_texto, info_style))
            
            # Línea separadora
            contenido.append(Spacer(1, 8*mm))
            
            print(f"📋 Información del reporte creada (alineada a la izquierda)")
            print(f"👤 Responsable en PDF: {self._usuario_responsable_nombre} ({self._usuario_responsable_rol})")
            
            return contenido
            
        except Exception as e:
            print(f"⚠️ Error creando información del reporte: {e}")
            styles = getSampleStyleSheet()
            return [Paragraph("INFORMACIÓN DEL REPORTE", styles['Heading2'])]

    def _crear_analisis_conclusiones(self, datos):
        """Crea sección de análisis simple como antes"""
        try:
            # Cálculo básico de totales
            total_valor = sum(float(item.get('valor', 0)) for item in datos)
            total_registros = len(datos)
            
            conclusion_text = f"""
            <b>ANÁLISIS Y CONCLUSIONES:</b><br/>
            
            El presente informe presenta el análisis de {total_registros} registros correspondientes al período establecido. 
            El valor total procesado asciende a {FormatUtils.formato_moneda(total_valor)}.<br/>
            
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

    # ============================================
    # MÉTODOS PARA INGRESOS Y EGRESOS
    # ============================================

    def _crear_reporte_ingresos_egresos_completo(self, datos, fecha_desde, fecha_hasta):
        """Crea reporte de ingresos y egresos optimizado"""
        elementos = []
        
        try:
            # 1. TÍTULO PRINCIPAL
            elementos.extend(self._crear_titulo_ingresos_egresos())
            
            # 2. DETALLE DE INGRESOS Y EGRESOS
            elementos.extend(self._crear_detalle_ingresos_egresos(datos))
            elementos.append(Spacer(1, 8*mm))
            
            # 3. TABLA PRINCIPAL OPTIMIZADA
            elementos.append(self._crear_tabla_movimientos_financieros_optimizada(datos))
            elementos.append(Spacer(1, 8*mm))
            
            # 4. ANÁLISIS Y CONCLUSIONES FINANCIERAS
            elementos.extend(self._crear_analisis_financiero_profesional(datos))
            elementos.append(Spacer(1, 8*mm))
            
            print("✅ Reporte de Ingresos y Egresos optimizado creado")
            return elementos
            
        except Exception as e:
            print(f"⚠️ Error creando reporte de ingresos y egresos: {e}")
            import traceback
            traceback.print_exc()
            return [self._crear_mensaje_error()]

    def _crear_titulo_ingresos_egresos(self):
        """Crea título principal para reporte de ingresos y egresos"""
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
        """Crea detalle separado de ingresos y egresos por categorías"""
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
        """Crea tabla específica para una categoría financiera CORREGIDA"""
        try:
            # Preparar datos de la tabla
            encabezados = ["CATEGORÍA", "OPS.", "VALOR TOTAL", "%"]
            tabla_datos = [encabezados]
            
            # Agrupar por descripción/categoría
            categorias_agrupadas = {}
            total_categoria = 0
            
            for item in datos_categoria:
                descripcion = item.get('descripcion', 'Sin categoría')
                # Limitar longitud de descripción para evitar desbordamiento
                if len(descripcion) > 40:
                    descripcion = descripcion[:37] + "..."
                
                valor = abs(float(item.get('valor', 0)))
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
                    str(datos_cat['cantidad']),  # Convertir a string
                    FormatUtils.formato_moneda(datos_cat['valor']),
                    f"{porcentaje:.1f}%"
                ]
                tabla_datos.append(fila)
            
            # Fila de total
            fila_total = [
                f"TOTAL {tipo_categoria}",
                str(sum(cat['cantidad'] for cat in categorias_agrupadas.values())),
                FormatUtils.formato_moneda(total_categoria),
                "100.0%"
            ]
            tabla_datos.append(fila_total)
            
            # ✅ ANCHOS CORREGIDOS Y PROPORCIONALES
            ancho_total = letter[0] - 40*mm  # Ancho total disponible
            tabla = Table(
                tabla_datos,
                colWidths=[
                    ancho_total * 0.45,  # 45% para descripción
                    ancho_total * 0.15,  # 15% para operaciones
                    ancho_total * 0.25,  # 25% para valor
                    ancho_total * 0.15   # 15% para porcentaje
                ],
                repeatRows=1,
                hAlign='CENTER' 
            )
            
            # Estilos de la tabla
            estilos = [
                # Encabezado
                ('BACKGROUND', (0, 0), (-1, 0), color_header),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 9),
                ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
                
                # Datos
                ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
                ('FONTSIZE', (0, 1), (-1, -2), 8),
                ('ALIGN', (1, 1), (1, -1), 'CENTER'),  # Ops centrado
                ('ALIGN', (2, 1), (2, -1), 'RIGHT'),   # Valor a la derecha
                ('ALIGN', (3, 1), (3, -1), 'CENTER'),  # % centrado
                ('ALIGN', (0, 1), (0, -2), 'LEFT'),    # Categorías a la izquierda
                
                # Fila de total
                ('BACKGROUND', (0, -1), (-1, -1), COLOR_GRIS_CLARO),
                ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
                ('FONTSIZE', (0, -1), (-1, -1), 9),
                ('TEXTCOLOR', (0, -1), (-1, -1), COLOR_GRIS_OSCURO),
                
                # Bordes y formato general
                ('GRID', (0, 0), (-1, -1), 0.5, colors.black),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, COLOR_GRIS_CLARO]),
                
                # Padding adicional
                ('LEFTPADDING', (0, 0), (-1, -1), 3),
                ('RIGHTPADDING', (0, 0), (-1, -1), 3),
            ]
            
            tabla.setStyle(TableStyle(estilos))
            
            return tabla
            
        except Exception as e:
            print(f"Error creando tabla de categoría financiera: {e}")
            return Table([["Error", "creando", "tabla", "financiera"]], hAlign='LEFT')

    def _crear_tabla_movimientos_financieros_optimizada(self, datos):
        """Crea tabla principal de movimientos financieros optimizada"""
        try:
            # Preparar datos con encabezados optimizados
            encabezados = ["FECHA/HORA", "CONCEPTO", "TIPO", "VALOR"]
            tabla_datos = [encabezados]
            
            total_general = 0
            
            # Agregar filas de datos
            for item in datos:
                fecha = FormatUtils.formato_fecha_hora(item.get('fecha', ''))
                tipo = item.get('tipo', 'Sin tipo')
                descripcion = item.get('descripcion', 'Sin descripción')
                valor = float(item.get('valor', 0))
                
                # Formatear valor con signo usando FormatUtils
                valor_formateado = FormatUtils.formato_moneda(valor, mostrar_signo=True)
                
                fila = [fecha, descripcion, tipo, valor_formateado]
                tabla_datos.append(fila)
                total_general += valor
            
            # Fila de total optimizada
            fila_total = [
                "",
                "SALDO NETO DEL PERÍODO",
                "",
                FormatUtils.formato_moneda(total_general, mostrar_signo=True)
            ]
            tabla_datos.append(fila_total)
            
            # ✅ ANCHOS OPTIMIZADOS
            tabla = Table(
                tabla_datos,
                colWidths=[
                    ANCHO_FECHA_CORTA*mm,        # 22mm
                    ANCHO_TEXTO_EXTRA_LARGO*mm,  # 85mm
                    ANCHO_TEXTO_CORTO*mm,        # 25mm
                    ANCHO_VALOR_LARGO*mm         # 35mm
                ],
                repeatRows=1,
                hAlign='CENTER'
            )
            
            # Estilos optimizados
            estilos = [
                # Encabezado
                ('BACKGROUND', (0, 0), (-1, 0), COLOR_AZUL_PRINCIPAL),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 9),
                ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
                
                # Datos
                ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
                ('FONTSIZE', (0, 1), (-1, -2), 8),
                ('ALIGN', (3, 1), (-1, -1), 'RIGHT'),
                
                # Fila de total
                ('BACKGROUND', (0, -1), (-1, -1), COLOR_AZUL_PRINCIPAL),
                ('TEXTCOLOR', (0, -1), (-1, -1), colors.white),
                ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
                ('FONTSIZE', (0, -1), (-1, -1), 9),
                ('ALIGN', (0, -1), (-1, -1), 'RIGHT'),
                ('SPAN', (0, -1), (2, -1)),
                
                # Bordes
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, COLOR_GRIS_CLARO]),
            ]
            
            tabla.setStyle(TableStyle(estilos))
            
            return tabla
            
        except Exception as e:
            print(f"Error creando tabla de movimientos optimizada: {e}")
            return Table([["Error", "creando", "tabla", "de", "movimientos"]], hAlign='CENTER')

    def _crear_analisis_financiero_profesional(self, datos):
        """Crea análisis y conclusiones financieras profesionales"""
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
                "{mayor_egreso[0]}" con {FormatUtils.formato_moneda(mayor_egreso[1])}, representando el 
                {(mayor_egreso[1] / totales['total_egresos'] * 100):.1f}% del total de egresos.
                """
                elementos.append(Paragraph(egresos_texto, analisis_style))
            
            # Análisis por rubros de ingresos
            if ingresos:
                categorias_ingresos = self._analizar_categorias_ingresos(ingresos)
                mayor_ingreso = max(categorias_ingresos.items(), key=lambda x: x[1])
                
                ingresos_texto = f"""
                <b>Análisis de Ingresos:</b> El área que genera mayores ingresos es 
                "{mayor_ingreso[0]}" con {FormatUtils.formato_moneda(mayor_ingreso[1])}, representando el 
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

    # ============================================
    # MÉTODOS PARA ARQUEO DE CAJA - MEJORADOS
    # ============================================

    def _crear_arqueo_caja_completo(self, datos, fecha_desde, fecha_hasta):
        """
        ✅ MEJORADO: Crea arqueo de caja con estructura detallada completa
        """
        elementos = []
        
        try:
            print("📄 Iniciando creación de arqueo completo...")
            
            # ✅ VALIDAR DATOS
            if not datos:
                print("❌ Datos de arqueo vacíos o None")
                return [self._crear_mensaje_error()]
            
            # 1. TÍTULO
            elementos.extend(self._crear_titulo_arqueo_caja(fecha_desde))
            
            # 2. EXTRAER DATOS
            if isinstance(datos, dict):
                movimientos = datos.get('movimientos_completos', [])
                
                if not isinstance(movimientos, list):
                    print(f"⚠️ movimientos_completos no es lista: {type(movimientos)}")
                    movimientos = []
                
                resumen = {
                    'total_ingresos': float(datos.get('total_ingresos', 0)),
                    'total_egresos': float(datos.get('total_egresos', 0)),
                    'saldo_teorico': float(datos.get('saldo_teorico', 0)),
                    'efectivo_real': float(datos.get('efectivo_real', 0)),
                    'diferencia': float(datos.get('diferencia', 0))
                }
                
                hora_inicio = str(datos.get('hora_inicio', '08:00'))
                hora_fin = str(datos.get('hora_fin', '18:00'))
                responsable = datos.get('responsable', 'Sistema CMI')
                
            elif isinstance(datos, list):
                movimientos = datos
                resumen = self._calcular_resumen_desde_movimientos(movimientos)
                hora_inicio = '08:00'
                hora_fin = '18:00'
                responsable = 'Sistema CMI'
            else:
                print(f"❌ Tipo de datos inesperado: {type(datos)}")
                return [self._crear_mensaje_error()]
            
            print(f"📊 Movimientos a procesar: {len(movimientos)}")
            
            if len(movimientos) == 0:
                print("⚠️ No hay movimientos para procesar")
                elementos.append(self._crear_mensaje_sin_movimientos())
                return elementos
            
            # 3. INFO DEL CIERRE
            elementos.extend(self._crear_info_cierre_arqueo_mejorada(
                fecha_desde, hora_inicio, hora_fin, resumen
            ))
            elementos.append(Spacer(1, 6*mm))
            
            # 4. ✅ NUEVO: DESGLOSE DETALLADO DE INGRESOS
            ingresos = [m for m in movimientos if m.get('tipo') == 'INGRESO']
            if ingresos:
                elementos.extend(self._crear_desglose_ingresos_detallado(ingresos))
                elementos.append(Spacer(1, 6*mm))
            
            # 5. ✅ NUEVO: DESGLOSE DETALLADO DE EGRESOS
            egresos = [m for m in movimientos if m.get('tipo') == 'EGRESO']
            if egresos:
                elementos.extend(self._crear_desglose_egresos_detallado(egresos))
                elementos.append(Spacer(1, 6*mm))
            
            # 6. RESUMEN FINAL
            elementos.extend(self._crear_resumen_arqueo_fisico_mejorado(resumen))
            elementos.append(Spacer(1, 6*mm))
            
            # 7. ✅ NUEVO: SECCIÓN DE FIRMAS
            elementos.extend(self._crear_seccion_firmas(responsable))
            
            print("✅ Arqueo completo creado exitosamente")
            return elementos
            
        except Exception as e:
            print(f"❌ Error creando arqueo: {e}")
            import traceback
            traceback.print_exc()
            return [self._crear_mensaje_error()]

    def _crear_desglose_ingresos_detallado(self, ingresos: List[Dict]) -> List:
        """
        ✅ NUEVO: Crea desglose detallado de ingresos por categoría
        """
        elementos = []
        
        try:
            styles = getSampleStyleSheet()
            titulo_style = ParagraphStyle(
                'TituloSeccion',
                parent=styles['Normal'],
                fontSize=14,
                fontName='Helvetica-Bold',
                textColor=COLOR_VERDE_POSITIVO,
                spaceAfter=8,
                spaceBefore=4
            )
            
            elementos.append(Paragraph("💰 DETALLE DE INGRESOS DEL DÍA", titulo_style))
            
            # Agrupar por categoría
            categorias = {
                'FARMACIA': [],
                'CONSULTA': [],
                'LABORATORIO': [],
                'ENFERMERIA': [],
                'INGRESOS EXTRAS': []
            }
            
            for ingreso in ingresos:
                categoria = ingreso.get('categoria', 'OTROS')
                if categoria in categorias:
                    categorias[categoria].append(ingreso)
            
            # Crear tabla para cada categoría con movimientos
            for categoria, items in categorias.items():
                if not items:
                    continue
                
                # Subtítulo de categoría
                subtitulo_style = ParagraphStyle(
                    'SubtituloCategoria',
                    parent=styles['Normal'],
                    fontSize=11,
                    fontName='Helvetica-Bold',
                    textColor=COLOR_AZUL_PRINCIPAL,
                    spaceAfter=4,
                    spaceBefore=6
                )
                
                icono = {
                    'FARMACIA': '💊',
                    'CONSULTA': '🩺',
                    'LABORATORIO': '🔬',
                    'ENFERMERIA': '🩹',
                    'INGRESOS EXTRAS': '💵'
                }.get(categoria, '📋')
                
                elementos.append(Paragraph(f"{icono} {categoria}", subtitulo_style))
                
                # ✅ TABLA ESPECIAL PARA FARMACIA
                if categoria == 'FARMACIA':
                    tabla_data = [["HORA", "PRODUCTOS VENDIDOS", "IMPORTE"]]
                    
                    total_categoria = 0
                    for item in items:
                        # Extraer hora
                        fecha_completa = item.get('fecha', '')
                        try:
                            if isinstance(fecha_completa, str) and len(fecha_completa) > 10:
                                partes = fecha_completa.split()
                                if len(partes) >= 2:
                                    hora = partes[1].split(':')[0] + ':' + partes[1].split(':')[1]
                                else:
                                    hora = fecha_completa[:5]
                            else:
                                hora = str(fecha_completa)[:5]
                        except:
                            hora = "-"
                        
                        # ✅ USAR PRODUCTOS EN LUGAR DE DESCRIPCIÓN GENÉRICA
                        productos = item.get('productos', item.get('descripcion', 'Productos varios'))
                        valor = float(item.get('valor', 0))
                        
                        # Formatear productos (cada producto en una línea)
                        productos_formateados = productos.replace('; ', '<br/>- ') if productos else '-'
                        if productos_formateados and not productos_formateados.startswith('-'):
                            productos_formateados = '- ' + productos_formateados
                        
                        tabla_data.append([
                            hora,
                            Paragraph(productos_formateados, ParagraphStyle(
                                'ProductosFarmacia',
                                parent=styles['Normal'],
                                fontSize=7,
                                leading=9
                            )),
                            FormatUtils.formato_moneda(valor)
                        ])
                        
                        total_categoria += valor
                    
                    # Fila de subtotal
                    tabla_data.append([
                        "", 
                        f"SUBTOTAL {categoria}",
                        FormatUtils.formato_moneda(total_categoria)
                    ])
                    
                    # Crear tabla con anchos ajustados para farmacia
                    tabla = Table(
                        tabla_data,
                        colWidths=[20*mm, 120*mm, 30*mm],  # Más espacio para productos
                        repeatRows=1
                    )
                
                else:
                    # ✅ TABLA NORMAL PARA OTRAS CATEGORÍAS
                    tabla_data = [["HORA", "DESCRIPCIÓN", "IMPORTE"]]
                    
                    total_categoria = 0
                    for item in items:
                        # Extraer hora
                        fecha_completa = item.get('fecha', '')
                        try:
                            if isinstance(fecha_completa, str) and len(fecha_completa) > 10:
                                partes = fecha_completa.split()
                                if len(partes) >= 2:
                                    hora = partes[1].split(':')[0] + ':' + partes[1].split(':')[1]
                                else:
                                    hora = fecha_completa[:5]
                            else:
                                hora = str(fecha_completa)[:5]
                        except:
                            hora = "-"
                        
                        descripcion = item.get('descripcion', 'Sin descripción')[:60]
                        valor = float(item.get('valor', 0))
                        
                        tabla_data.append([
                            hora,
                            descripcion,
                            FormatUtils.formato_moneda(valor)
                        ])
                        
                        total_categoria += valor
                    
                    # Fila de subtotal
                    tabla_data.append([
                        "", 
                        f"SUBTOTAL {categoria}",
                        FormatUtils.formato_moneda(total_categoria)
                    ])
                    
                    # Crear tabla con 3 columnas
                    tabla = Table(
                        tabla_data,
                        colWidths=[20*mm, 100*mm, 30*mm],  # Más espacio para descripción
                        repeatRows=1
                    )
                
                # Estilos comunes para ambas tablas
                estilos_tabla = [
                    ('BACKGROUND', (0, 0), (-1, 0), COLOR_VERDE_POSITIVO),
                    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                    ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                    ('FONTSIZE', (0, 0), (-1, 0), 8),
                    ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
                    
                    # Datos
                    ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
                    ('FONTSIZE', (0, 1), (-1, -2), 7),
                    ('ALIGN', (-1, 1), (-1, -1), 'RIGHT'),  # Última columna (importe) a la derecha
                    
                    # Subtotal
                    ('BACKGROUND', (0, -1), (-1, -1), COLOR_GRIS_CLARO),
                    ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
                    ('FONTSIZE', (0, -1), (-1, -1), 8),
                    ('SPAN', (0, -1), (-2, -1)) if categoria == 'FARMACIA' else ('SPAN', (0, -1), (2, -1)),
                    
                    ('GRID', (0, 0), (-1, -2), 0.5, colors.grey),
                    ('LINEBELOW', (0, -1), (-1, -1), 1, COLOR_VERDE_POSITIVO),
                    ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                    ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, COLOR_GRIS_CLARO]),
                    
                    ('LEFTPADDING', (0, 0), (-1, -1), 3),
                    ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                    ('TOPPADDING', (0, 0), (-1, -1), 4),
                    ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                ]
                
                tabla.setStyle(TableStyle(estilos_tabla))
                elementos.append(tabla)
                elementos.append(Spacer(1, 3*mm))

            return elementos
            
        except Exception as e:
            print(f"❌ Error creando desglose de ingresos: {e}")
            return []

    def _crear_desglose_egresos_detallado(self, egresos: List[Dict]) -> List:
        """
        ✅ MEJORADO: Crea desglose detallado de egresos separando compras y gastos
        """
        elementos = []
        
        try:
            styles = getSampleStyleSheet()
            titulo_style = ParagraphStyle(
                'TituloSeccion',
                parent=styles['Normal'],
                fontSize=14,
                fontName='Helvetica-Bold',
                textColor=COLOR_NARANJA_EGRESO,
                spaceAfter=8,
                spaceBefore=4
            )
            
            elementos.append(Paragraph("💸 DETALLE DE EGRESOS DEL DÍA", titulo_style))
            
            # ✅ SEPARAR COMPRAS Y GASTOS
            compras = [e for e in egresos if e.get('tipo_gasto') == 'COMPRAS DE FARMACIA']
            gastos = [e for e in egresos if e.get('tipo_gasto') != 'COMPRAS DE FARMACIA']
            
            # ✅ 1. COMPRAS DE FARMACIA (si hay)
            if compras:
                subtitulo_style = ParagraphStyle(
                    'SubtituloCompras',
                    parent=styles['Normal'],
                    fontSize=11,
                    fontName='Helvetica-Bold',
                    textColor=COLOR_AZUL_PRINCIPAL,
                    spaceAfter=4,
                    spaceBefore=6
                )
                
                elementos.append(Paragraph("📦 COMPRAS DE FARMACIA", subtitulo_style))
                
                tabla_data = [["HORA", "PROVEEDOR", "PRODUCTOS", "IMPORTE"]]
                
                total_compras = 0
                for item in compras:
                    # Extraer hora
                    fecha_completa = item.get('fecha', '')
                    try:
                        if isinstance(fecha_completa, str) and len(fecha_completa) > 10:
                            partes = fecha_completa.split()
                            if len(partes) >= 2:
                                hora = partes[1].split(':')[0] + ':' + partes[1].split(':')[1]
                            else:
                                hora = fecha_completa[:5]
                        else:
                            hora = str(fecha_completa)[:5]
                    except:
                        hora = "-"
                    
                    proveedor = item.get('proveedor', 'Sin proveedor')[:30]
                    productos = item.get('productos', item.get('descripcion', 'Productos varios'))
                    valor = abs(float(item.get('valor', 0)))
                    
                    # Formatear productos
                    productos_formateados = productos.replace('; ', '<br/>- ') if productos else '-'
                    if productos_formateados and not productos_formateados.startswith('-'):
                        productos_formateados = '- ' + productos_formateados
                    
                    tabla_data.append([
                        hora,
                        proveedor,
                        Paragraph(productos_formateados, ParagraphStyle(
                            'ProductosCompra',
                            parent=styles['Normal'],
                            fontSize=7,
                            leading=9
                        )),
                        FormatUtils.formato_moneda(valor)
                    ])
                    
                    total_compras += valor
                
                # Subtotal compras
                tabla_data.append([
                    "", 
                    "TOTAL COMPRAS FARMACIA",
                    "",
                    FormatUtils.formato_moneda(total_compras)
                ])
                
                tabla = Table(
                    tabla_data,
                    colWidths=[15*mm, 40*mm, 90*mm, 25*mm],
                    repeatRows=1
                )
                
                estilos_tabla = [
                    ('BACKGROUND', (0, 0), (-1, 0), COLOR_NARANJA_EGRESO),
                    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                    ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                    ('FONTSIZE', (0, 0), (-1, 0), 8),
                    ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
                    
                    ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
                    ('FONTSIZE', (0, 1), (-1, -2), 7),
                    ('ALIGN', (3, 1), (3, -1), 'RIGHT'),
                    
                    ('BACKGROUND', (0, -1), (-1, -1), COLOR_GRIS_CLARO),
                    ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
                    ('FONTSIZE', (0, -1), (-1, -1), 8),
                    ('SPAN', (0, -1), (2, -1)),
                    
                    ('GRID', (0, 0), (-1, -2), 0.5, colors.grey),
                    ('LINEBELOW', (0, -1), (-1, -1), 1, COLOR_NARANJA_EGRESO),
                    ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                    ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, COLOR_GRIS_CLARO]),
                    
                    ('LEFTPADDING', (0, 0), (-1, -1), 3),
                    ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                    ('TOPPADDING', (0, 0), (-1, -1), 4),
                    ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                ]
                
                tabla.setStyle(TableStyle(estilos_tabla))
                elementos.append(tabla)
                elementos.append(Spacer(1, 5*mm))
            
            # ✅ 2. OTROS GASTOS
            if gastos:
                # Agrupar gastos por tipo
                tipos_gasto = {}
                for gasto in gastos:
                    # Extraer el tipo de gasto de la descripción (antes del " - ")
                    descripcion = gasto.get('descripcion', 'GASTO')
                    tipo = descripcion.split(' - ')[0] if ' - ' in descripcion else 'GASTO'
                    
                    if tipo not in tipos_gasto:
                        tipos_gasto[tipo] = []
                    tipos_gasto[tipo].append(gasto)
                
                for tipo_gasto, items in tipos_gasto.items():
                    subtitulo_style = ParagraphStyle(
                        'SubtituloGasto',
                        parent=styles['Normal'],
                        fontSize=11,
                        fontName='Helvetica-Bold',
                        textColor=COLOR_AZUL_PRINCIPAL,
                        spaceAfter=4,
                        spaceBefore=6
                    )
                    
                    elementos.append(Paragraph(f"💸 {tipo_gasto}", subtitulo_style))
                    
                    tabla_data = [["HORA", "CONCEPTO", "PROVEEDOR", "DETALLE", "IMPORTE"]]
                    
                    total_tipo = 0
                    for item in items:
                        # Extraer hora
                        fecha_completa = item.get('fecha', '')
                        try:
                            if isinstance(fecha_completa, str) and len(fecha_completa) > 10:
                                partes = fecha_completa.split()
                                if len(partes) >= 2:
                                    hora = partes[1].split(':')[0] + ':' + partes[1].split(':')[1]
                                else:
                                    hora = fecha_completa[:5]
                            else:
                                hora = str(fecha_completa)[:5]
                        except:
                            hora = "-"
                        
                        descripcion = item.get('descripcion', 'Sin descripción')
                        partes_desc = descripcion.split(' - ')
                        concepto = partes_desc[0][:30] if partes_desc else descripcion[:30]
                        detalle = partes_desc[1][:40] if len(partes_desc) > 1 else '-'
                        
                        proveedor = item.get('proveedor', 'N/A')[:25]
                        valor = abs(float(item.get('valor', 0)))
                        
                        tabla_data.append([
                            hora,
                            concepto,
                            proveedor,
                            detalle,
                            FormatUtils.formato_moneda(valor)
                        ])
                        
                        total_tipo += valor
                    
                    # Subtotal
                    tabla_data.append([
                        "", 
                        f"SUBTOTAL {tipo_gasto}",
                        "",
                        "",
                        FormatUtils.formato_moneda(total_tipo)
                    ])
                    
                    tabla = Table(
                        tabla_data,
                        colWidths=[15*mm, 40*mm, 35*mm, 55*mm, 25*mm],
                        repeatRows=1
                    )
                    
                    estilos_tabla = [
                        ('BACKGROUND', (0, 0), (-1, 0), COLOR_NARANJA_EGRESO),
                        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                        ('FONTSIZE', (0, 0), (-1, 0), 8),
                        ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
                        
                        ('FONTNAME', (0, 1), (-1, -2), 'Helvetica'),
                        ('FONTSIZE', (0, 1), (-1, -2), 7),
                        ('ALIGN', (4, 1), (4, -1), 'RIGHT'),
                        
                        ('BACKGROUND', (0, -1), (-1, -1), COLOR_GRIS_CLARO),
                        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
                        ('FONTSIZE', (0, -1), (-1, -1), 8),
                        ('SPAN', (0, -1), (3, -1)),
                        
                        ('GRID', (0, 0), (-1, -2), 0.5, colors.grey),
                        ('LINEBELOW', (0, -1), (-1, -1), 1, COLOR_NARANJA_EGRESO),
                        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                        ('ROWBACKGROUNDS', (0, 1), (-1, -2), [colors.white, COLOR_GRIS_CLARO]),
                        
                        ('LEFTPADDING', (0, 0), (-1, -1), 3),
                        ('RIGHTPADDING', (0, 0), (-1, -1), 3),
                        ('TOPPADDING', (0, 0), (-1, -1), 4),
                        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
                    ]
                    
                    tabla.setStyle(TableStyle(estilos_tabla))
                    elementos.append(tabla)
                    elementos.append(Spacer(1, 3*mm))
            
            return elementos
            
        except Exception as e:
            print(f"❌ Error creando desglose de egresos: {e}")
            import traceback
            traceback.print_exc()
            return []

    def _crear_seccion_firmas(self, responsable: str = "Sistema") -> List:
        """
        ✅ CORREGIDO: Crea sección de firmas usando el usuario autenticado
        """
        elementos = []
        
        try:
            elementos.append(Spacer(1, 15*mm))
            
            # ✅ USAR EL USUARIO RESPONSABLE ESTABLECIDO (NO el parámetro por defecto)
            nombre_responsable = self._usuario_responsable_nombre if self._usuario_responsable_nombre else "Sistema"
            
            # ✅ ACORTAR NOMBRE SI ES MUY LARGO
            if len(nombre_responsable) > 25:
                nombre_responsable = nombre_responsable[:25] + "..."
            
            # Tabla de firmas
            firmas_data = [
                ["", ""],
                ["_" * 40, "_" * 40],
                ["RESPONSABLE DE CAJA", "ADMINISTRADOR"],
                [nombre_responsable, ""]  # ✅ AQUÍ SE USA EL NOMBRE REAL
            ]
            
            tabla_firmas = Table(
                firmas_data,
                colWidths=[85*mm, 85*mm],
                rowHeights=[10*mm, 3*mm, 8*mm, 6*mm]
            )
            
            estilos_firmas = [
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ('VALIGN', (0, 0), (-1, -1), 'BOTTOM'),
                ('FONTNAME', (0, 2), (-1, 2), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 2), (-1, 2), 9),
                ('FONTNAME', (0, 3), (-1, 3), 'Helvetica'),
                ('FONTSIZE', (0, 3), (-1, 3), 8),
                ('TEXTCOLOR', (0, 2), (-1, 2), COLOR_AZUL_PRINCIPAL),
                ('LINEABOVE', (0, 1), (-1, 1), 1, colors.black),
            ]
            
            tabla_firmas.setStyle(TableStyle(estilos_firmas))
            elementos.append(tabla_firmas)
            
            return elementos
            
        except Exception as e:
            print(f"❌ Error creando sección de firmas: {e}")
            return []

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

    def _crear_info_cierre_arqueo_mejorada(self, fecha: str, hora_inicio: str, 
                                   hora_fin: str, resumen: Dict) -> List:
        """Info del cierre con datos del resumen - ✅ CORREGIDO: Evita texto cortado"""
        try:
            # ✅ USAR EL USUARIO RESPONSABLE ESTABLECIDO (nombre más corto si es necesario)
            responsable = self._usuario_responsable_nombre if self._usuario_responsable_nombre else "Sistema"
            
            # ✅ ACORTAR NOMBRE SI ES MUY LARGO PARA EVITAR CORTES
            if len(responsable) > 20:
                responsable = responsable[:20] + "..."
            
            info_data = [
                ["Fecha:", fecha, "Hora Inicio:", hora_inicio],
                ["Responsable:", responsable, "Hora Fin:", hora_fin],  # ✅ NOMBRE ACORTADO
                ["Total Ingresos:", FormatUtils.formato_moneda(resumen.get('total_ingresos', 0)), 
                "Total Egresos:", FormatUtils.formato_moneda(resumen.get('total_egresos', 0))]
            ]
            
            # ✅ AUMENTAR ANCHOS DE COLUMNAS PARA EVITAR CORTES
            tabla = Table(info_data, colWidths=[25*mm, 40*mm, 25*mm, 40*mm])
            
            estilos = [
                ('BACKGROUND', (0, 0), (-1, -1), COLOR_GRIS_CLARO),
                ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 0), (-1, -1), 9),
                ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
                ('FONTNAME', (2, 0), (2, -1), 'Helvetica-Bold'),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ]
            
            tabla.setStyle(TableStyle(estilos))
            return [tabla]
            
        except Exception as e:
            print(f"Error info cierre: {e}")
            return []

    def _calcular_resumen_desde_movimientos(self, movimientos: List[Dict]) -> Dict:
        """Calcula resumen financiero - VERSIÓN MEJORADA"""
        try:
            if not isinstance(movimientos, list):
                return {
                    'total_ingresos': 0.0,
                    'total_egresos': 0.0,
                    'saldo_teorico': 0.0,
                    'efectivo_real': 0.0,  # ✅ Mantener como 0, se sobreescribirá después
                    'diferencia': 0.0
                }
            
            total_ingresos = 0.0
            total_egresos = 0.0
            
            for mov in movimientos:
                if not isinstance(mov, dict):
                    continue
                
                try:
                    tipo = str(mov.get('tipo', '')).upper()
                    valor = float(mov.get('valor', 0))
                    
                    if tipo == 'INGRESO':
                        total_ingresos += abs(valor)
                    elif tipo == 'EGRESO':
                        total_egresos += abs(valor)
                except:
                    continue
            
            saldo_teorico = total_ingresos - total_egresos
            
            # ✅ NO calcular efectivo_real aquí - se obtendrá de los datos del cierre
            return {
                'total_ingresos': round(total_ingresos, 2),
                'total_egresos': round(total_egresos, 2),
                'saldo_teorico': round(saldo_teorico, 2),
                'efectivo_real': 0.0,  # ✅ Se establecerá desde los datos externos
                'diferencia': 0.0      # ✅ Se calculará después
            }
            
        except Exception as e:
            print(f"❌ Error calculando resumen: {e}")
            return {
                'total_ingresos': 0.0,
                'total_egresos': 0.0,
                'saldo_teorico': 0.0,
                'efectivo_real': 0.0,
                'diferencia': 0.0
            }

    def _crear_resumen_arqueo_fisico_mejorado(self, resumen: Dict) -> List:
        """Resumen final con datos estructurados"""
        elementos = []
        
        try:
            total_ingresos = resumen.get('total_ingresos', 0)
            total_egresos = resumen.get('total_egresos', 0)
            saldo_teorico = resumen.get('saldo_teorico', 0)
            efectivo_real = resumen.get('efectivo_real', 0)
            diferencia = resumen.get('diferencia', 0)
            
            # Tabla de resumen
            resumen_data = [
                ["CONCEPTO", "IMPORTE"],
                ["Total Ingresos", FormatUtils.formato_moneda(total_ingresos)],
                ["Total Egresos", FormatUtils.formato_moneda(total_egresos)],
                ["Saldo Teórico", FormatUtils.formato_moneda(saldo_teorico)],
                ["Efectivo Real", FormatUtils.formato_moneda(efectivo_real)],
                ["Diferencia", FormatUtils.formato_moneda(diferencia, mostrar_signo=True)]
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
            
            titulo_style = ParagraphStyle(
                'ResumenTitulo',
                fontSize=14,
                fontName='Helvetica-Bold',
                textColor=COLOR_AZUL_PRINCIPAL,
                spaceAfter=8
            )
            
            elementos.append(Paragraph("📊 RESUMEN FINANCIERO Y ARQUEO", titulo_style))
            elementos.append(tabla_resumen)
            
            # Resultado final
            tipo_diff = "SOBRANTE" if diferencia >= 0 else "FALTANTE"
            color_diff = COLOR_VERDE_POSITIVO if diferencia >= 0 else COLOR_ROJO_ACENTO
            
            resultado_style = ParagraphStyle(
                'ResultadoArqueo',
                fontSize=12,
                fontName='Helvetica-Bold',
                textColor=color_diff,
                alignment=TA_CENTER,
                spaceAfter=12,
                spaceBefore=12
            )
            
            elementos.append(Paragraph(
                f"{'✅' if abs(diferencia) < 50 else '⚠️'} {tipo_diff} EN CAJA: {FormatUtils.formato_moneda(abs(diferencia))}", 
                resultado_style
            ))
            
            return elementos
            
        except Exception as e:
            print(f"Error resumen arqueo: {e}")
            return []

    # ============================================
    # MÉTODOS AUXILIARES GENERALES
    # ============================================

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

    def _crear_encabezado_profesional_mejorado(self, canvas, doc):
        """
        Crea encabezado profesional optimizado - VERSIÓN FINAL
        ✅ Logo a la izquierda (más grande)
        ✅ Información institucional a la derecha
        ✅ Diseño compacto y profesional
        """
        canvas.saveState()
        
        # Fondo blanco del encabezado
        canvas.setFillColor(colors.white)
        canvas.rect(0, letter[1]-40*mm, letter[0], 40*mm, fill=1, stroke=0)
        
        # Franja decorativa superior (roja)
        canvas.setFillColor(COLOR_ROJO_ACENTO)
        canvas.rect(0, letter[1]-8*mm, letter[0], 8*mm, fill=1, stroke=0)
        
        # LÍNEA AZUL en la parte inferior del encabezado
        canvas.setStrokeColor(COLOR_AZUL_PRINCIPAL)
        canvas.setLineWidth(2)
        canvas.line(0, letter[1]-40*mm, letter[0], letter[1]-40*mm)
        
        # ============================================
        # LOGO - Izquierda (tamaño medio, más visible)
        # ============================================
        logo_x = 20*mm
        logo_y = letter[1]-36*mm
        logo_width = 50*mm  # ✅ Más grande que antes (era 35mm)
        logo_height = 28*mm  # ✅ Proporcionalmente más alto
        
        if self.logo_path and os.path.exists(self.logo_path):
            try:
                canvas.drawImage(
                    self.logo_path, 
                    logo_x, logo_y,
                    width=logo_width, height=logo_height,
                    preserveAspectRatio=True,
                    mask='auto'
                )
            except Exception as e:
                print(f"⚠️ Error dibujando logo: {e}")
                self._dibujar_logo_profesional_mejorado(canvas, logo_x, logo_y, logo_width, logo_height)
        else:
            self._dibujar_logo_profesional_mejorado(canvas, logo_x, logo_y, logo_width, logo_height)
        
        # ============================================
        # INFORMACIÓN INSTITUCIONAL - Derecha del logo
        # ============================================
        info_x = logo_x + logo_width + 15*mm  # Después del logo con separación
        
        # Título principal - alineado a la derecha de la página
        canvas.setFont("Helvetica-Bold", 18)
        canvas.setFillColor(COLOR_AZUL_PRINCIPAL)
        titulo_texto = "CLÍNICA MARÍA INMACULADA"
        titulo_width = canvas.stringWidth(titulo_texto, "Helvetica-Bold", 18)
        titulo_x = letter[0] - 20*mm - titulo_width
        canvas.drawString(titulo_x, letter[1]-16*mm, titulo_texto)
        
        # Línea divisoria bajo el título (de extremo a extremo del título)
        canvas.setStrokeColor(COLOR_AZUL_PRINCIPAL)
        canvas.setLineWidth(1.5)
        canvas.line(titulo_x, letter[1]-17.5*mm, letter[0] - 20*mm, letter[1]-17.5*mm)
        
        # Información de contacto - alineada a la derecha
        canvas.setFont("Helvetica", 11)
        canvas.setFillColor(COLOR_GRIS_OSCURO)
        
        lineas_info = [
            "Atención Médica Integral",
            "Villa Yapacaní, Santa Cruz - Bolivia"
        ]
        
        y_pos = letter[1]-24*mm
        for linea in lineas_info:
            linea_width = canvas.stringWidth(linea, "Helvetica", 11)
            linea_x = letter[0] - 20*mm - linea_width
            canvas.drawString(linea_x, y_pos, linea)
            y_pos -= 5*mm
        
        canvas.restoreState()

    def _dibujar_logo_profesional_mejorado(self, canvas, x, y, ancho, alto):
        """Dibuja logo profesional MEJORADO cuando no hay imagen disponible"""
        # Fondo azul para el logo
        canvas.setFillColor(COLOR_AZUL_PRINCIPAL)
        canvas.rect(x, y, ancho, alto, fill=1, stroke=0)
        
        # Texto del logo en blanco - MEJORADO con mejor espaciado
        canvas.setFillColor(colors.white)
        canvas.setFont("Helvetica-Bold", 14)
        
        # Texto "CMI" centrado
        texto_cmi = "CMI"
        texto_cmi_width = canvas.stringWidth(texto_cmi, "Helvetica-Bold", 14)
        canvas.drawString(x + (ancho - texto_cmi_width) / 2, y + alto/2 + 5, texto_cmi)
        
        # Texto "CLÍNICA" 
        canvas.setFont("Helvetica-Bold", 8)
        texto_clinica = "CLÍNICA"
        texto_clinica_width = canvas.stringWidth(texto_clinica, "Helvetica-Bold", 8)
        canvas.drawString(x + (ancho - texto_clinica_width) / 2, y + alto/2 - 5, texto_clinica)
        
        # Texto "MARÍA INMACULADA"
        canvas.setFont("Helvetica-Bold", 6)
        texto_inmaculada = "MARÍA INMACULADA"
        texto_inmaculada_width = canvas.stringWidth(texto_inmaculada, "Helvetica-Bold", 6)
        canvas.drawString(x + (ancho - texto_inmaculada_width) / 2, y + alto/2 - 12, texto_inmaculada)
        
        # Borde blanco alrededor del logo
        canvas.setStrokeColor(colors.white)
        canvas.setLineWidth(1)
        canvas.rect(x, y, ancho, alto, fill=0, stroke=1)

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
        
        return Paragraph("Error generando reporte", error_style)

    def _crear_mensaje_sin_movimientos(self):
        """Crea mensaje cuando no hay movimientos"""
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.platypus import Paragraph
        from reportlab.lib.enums import TA_CENTER
        
        styles = getSampleStyleSheet()
        mensaje_style = ParagraphStyle(
            'SinMovimientos',
            parent=styles['Normal'],
            fontSize=14,
            textColor=COLOR_GRIS_OSCURO,
            alignment=TA_CENTER,
            spaceAfter=20*mm,
            spaceBefore=20*mm
        )
        
        mensaje = """
        <b>📋 NO HAY MOVIMIENTOS PARA ESTE PERÍODO</b><br/><br/>
        No se registraron transacciones en el rango de fecha y hora especificado.<br/>
        Verifique los parámetros de consulta.
        """
        
        return Paragraph(mensaje, mensaje_style)

# Funciones de utilidad
def crear_generador_pdf():
    """Función factoría para crear una instancia del generador de PDFs"""
    return GeneradorReportesPDF()

def generar_pdf_reporte(datos_json, tipo_reporte, fecha_desde, fecha_hasta):
    """Función de conveniencia para generar un PDF directamente"""
    generador = GeneradorReportesPDF()
    return generador.generar_reporte_pdf(datos_json, tipo_reporte, fecha_desde, fecha_hasta)