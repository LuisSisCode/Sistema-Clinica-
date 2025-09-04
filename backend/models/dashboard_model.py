from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from PySide6.QtQml import qmlRegisterType

from ..repositories.estadistica_repository import EstadisticaRepository
from ..repositories.venta_repository import VentaRepository
from ..repositories.gasto_repository import GastoRepository
from ..repositories.consulta_repository import ConsultaRepository
from ..repositories.laboratorio_repository import LaboratorioRepository
from ..repositories.enfermeria_repository import EnfermeriaRepository
from ..repositories.producto_repository import ProductoRepository
from ..core.cache_system import cached_query

class DashboardModel(QObject):
    """Model QObject para Dashboard con datos reales de BD"""
    
    # ===============================
    # SIGNALS
    # ===============================
    
    # Signals para KPI Cards
    farmaciaDataChanged = Signal()
    consultasDataChanged = Signal()
    laboratorioDataChanged = Signal()
    enfermeriaDataChanged = Signal()
    serviciosBasicosDataChanged = Signal()
    
    # Signals para gráficos y alertas
    graficoDataChanged = Signal()
    alertasChanged = Signal()
    periodoChanged = Signal()
    
    # Signal general de actualización
    dashboardUpdated = Signal()
    errorOccurred = Signal(str)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Repositories
        self.estadistica_repo = EstadisticaRepository()
        self.venta_repo = VentaRepository()
        self.gasto_repo = GastoRepository()
        self.consulta_repo = ConsultaRepository()
        self.laboratorio_repo = LaboratorioRepository()
        self.enfermeria_repo = EnfermeriaRepository()
        self.producto_repo = ProductoRepository()
        
        # Estado interno
        self._periodo_actual = "mes"  # hoy, semana, mes, año
        self._mes_seleccionado = datetime.now().month
        self._año_seleccionado = datetime.now().year
        
        # Datos cache internos
        self._farmacia_total = 0.0
        self._consultas_total = 0.0
        self._laboratorio_total = 0.0
        self._enfermeria_total = 0.0
        self._servicios_basicos_total = 0.0
        
        self._grafico_ingresos = []
        self._grafico_egresos = []
        self._alertas_vencimientos = []
        
        # Timer para auto-refresh
        self._refresh_timer = QTimer(self)
        self._refresh_timer.timeout.connect(self._auto_refresh)
        self._refresh_timer.start(300000)  # 5 minutos
        
        print("📊 DashboardModel inicializado con datos reales")
        
        # Cargar datos iniciales
        QTimer.singleShot(1000, self._cargar_datos_iniciales)
    
    # ===============================
    # PROPERTIES - KPI CARDS
    # ===============================
    
    @Property(float, notify=farmaciaDataChanged)
    def farmaciaTotal(self):
        """Total de ingresos por farmacia según período"""
        return self._farmacia_total
    
    @Property(float, notify=consultasDataChanged) 
    def consultasTotal(self):
        """Total de ingresos por consultas según período"""
        return self._consultas_total
    
    @Property(float, notify=laboratorioDataChanged)
    def laboratorioTotal(self):
        """Total de ingresos por laboratorio según período"""
        return self._laboratorio_total
    
    @Property(float, notify=enfermeriaDataChanged)
    def enfermeriaTotal(self):
        """Total de ingresos por enfermería según período"""
        return self._enfermeria_total
    
    @Property(float, notify=serviciosBasicosDataChanged)
    def serviciosBasicosTotal(self):
        """Total de egresos por servicios básicos según período"""
        return self._servicios_basicos_total
    
    # ===============================
    # PROPERTIES - TOTALES CONSOLIDADOS
    # ===============================
    
    @Property(float, notify=dashboardUpdated)
    def totalIngresos(self):
        """Total consolidado de ingresos"""
        return (self._farmacia_total + self._consultas_total + 
                self._laboratorio_total + self._enfermeria_total)
    
    @Property(float, notify=dashboardUpdated)
    def totalEgresos(self):
        """Total consolidado de egresos"""
        return self._servicios_basicos_total
    
    @Property(float, notify=dashboardUpdated)
    def balanceNeto(self):
        """Balance neto (ingresos - egresos)"""
        return self.totalIngresos - self.totalEgresos
    
    # ===============================
    # PROPERTIES - FILTROS
    # ===============================
    
    @Property(str, notify=periodoChanged)
    def periodoActual(self):
        """Período actual seleccionado"""
        return self._periodo_actual
    
    @Property(int, notify=periodoChanged)
    def mesSeleccionado(self):
        """Mes seleccionado para filtros"""
        return self._mes_seleccionado
    
    @Property(int, notify=periodoChanged)
    def añoSeleccionado(self):
        """Año seleccionado para filtros"""
        return self._año_seleccionado
    
    # ===============================
    # PROPERTIES - GRÁFICOS Y ALERTAS
    # ===============================
    
    @Property('QVariantList', notify=graficoDataChanged)
    def datosGraficoIngresos(self):
        """Datos para gráfico de ingresos"""
        return self._grafico_ingresos
    
    @Property('QVariantList', notify=graficoDataChanged)
    def datosGraficoEgresos(self):
        """Datos para gráfico de egresos"""
        return self._grafico_egresos
    
    @Property('QVariantList', notify=alertasChanged)
    def alertasVencimientos(self):
        """Lista de alertas de vencimientos"""
        return self._alertas_vencimientos
    
    # ===============================
    # SLOTS PÚBLICOS - FILTRADO
    # ===============================
    
    @Slot(str)
    def cambiarPeriodo(self, nuevo_periodo: str):
        """Cambia el período de visualización (hoy, semana, mes, año)"""
        try:
            if nuevo_periodo != self._periodo_actual:
                print(f"📅 Cambiando período de '{self._periodo_actual}' a '{nuevo_periodo}'")
                self._periodo_actual = nuevo_periodo
                self.periodoChanged.emit()
                self._actualizar_todos_los_datos()
        except Exception as e:
            print(f"❌ Error cambiando período: {e}")
            self.errorOccurred.emit(f"Error cambiando período: {str(e)}")
    
    @Slot(int, int)
    def cambiarFechaEspecifica(self, mes: int, año: int):
        """Cambia mes y año específicos"""
        try:
            cambio_realizado = False
            
            if mes != self._mes_seleccionado:
                self._mes_seleccionado = mes
                cambio_realizado = True
                print(f"📅 Mes cambiado a: {mes}")
            
            if año != self._año_seleccionado:
                self._año_seleccionado = año
                cambio_realizado = True
                print(f"📅 Año cambiado a: {año}")
            
            if cambio_realizado:
                self.periodoChanged.emit()
                self._actualizar_todos_los_datos()
                
        except Exception as e:
            print(f"❌ Error cambiando fecha específica: {e}")
            self.errorOccurred.emit(f"Error cambiando fecha: {str(e)}")
    
    @Slot()
    def refrescarDatos(self):
        """Refresca todos los datos del dashboard"""
        print("🔄 Refrescando datos del dashboard...")
        try:
            # Invalidar caches
            self.estadistica_repo.invalidate_statistics_caches()
            self._actualizar_todos_los_datos()
            print("✅ Datos del dashboard refrescados")
        except Exception as e:
            print(f"❌ Error refrescando datos: {e}")
            self.errorOccurred.emit(f"Error refrescando datos: {str(e)}")
    
    # ===============================
    # MÉTODOS PRIVADOS - CARGA DE DATOS
    # ===============================
    
    def _cargar_datos_iniciales(self):
        """Carga datos iniciales del dashboard"""
        try:
            print("🚀 Cargando datos iniciales del dashboard...")
            self._actualizar_todos_los_datos()
            print("✅ Datos iniciales cargados exitosamente")
        except Exception as e:
            print(f"❌ Error cargando datos iniciales: {e}")
            self.errorOccurred.emit(f"Error inicial: {str(e)}")
    
    def _actualizar_todos_los_datos(self):
        """Actualiza todos los datos según el período actual"""
        try:
            # Calcular rango de fechas según período
            fecha_inicio, fecha_fin = self._obtener_rango_fechas()
            
            # Actualizar cada módulo
            self._actualizar_farmacia_data(fecha_inicio, fecha_fin)
            self._actualizar_consultas_data(fecha_inicio, fecha_fin)
            self._actualizar_laboratorio_data(fecha_inicio, fecha_fin)
            self._actualizar_enfermeria_data(fecha_inicio, fecha_fin)
            self._actualizar_servicios_basicos_data(fecha_inicio, fecha_fin)
            
            # Actualizar gráficos y alertas
            self._actualizar_datos_grafico(fecha_inicio, fecha_fin)
            self._actualizar_alertas()
            
            # Emitir signal general
            self.dashboardUpdated.emit()
            
        except Exception as e:
            print(f"❌ Error actualizando datos: {e}")
            self.errorOccurred.emit(f"Error actualizando: {str(e)}")
    
    def _obtener_rango_fechas(self):
        """Obtiene rango de fechas según período seleccionado"""
        ahora = datetime.now()
        
        if self._periodo_actual == "hoy":
            inicio = ahora.replace(hour=0, minute=0, second=0, microsecond=0)
            fin = inicio + timedelta(days=1)
        elif self._periodo_actual == "semana":
            # Semana actual (lunes a domingo)
            dias_desde_lunes = ahora.weekday()
            inicio = ahora - timedelta(days=dias_desde_lunes)
            inicio = inicio.replace(hour=0, minute=0, second=0, microsecond=0)
            fin = inicio + timedelta(days=7)
        elif self._periodo_actual == "mes":
            # Mes específico seleccionado
            inicio = datetime(self._año_seleccionado, self._mes_seleccionado, 1)
            if self._mes_seleccionado == 12:
                fin = datetime(self._año_seleccionado + 1, 1, 1)
            else:
                fin = datetime(self._año_seleccionado, self._mes_seleccionado + 1, 1)
        elif self._periodo_actual == "año":
            # Año completo seleccionado
            inicio = datetime(self._año_seleccionado, 1, 1)
            fin = datetime(self._año_seleccionado + 1, 1, 1)
        else:
            # Fallback: mes actual
            inicio = ahora.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            if ahora.month == 12:
                fin = datetime(ahora.year + 1, 1, 1)
            else:
                fin = datetime(ahora.year, ahora.month + 1, 1)
        
        print(f"📅 Rango calculado: {inicio.strftime('%Y-%m-%d')} a {fin.strftime('%Y-%m-%d')}")
        return inicio, fin
    
    # ===============================
    # ACTUALIZACIÓN POR MÓDULO
    # ===============================
    
    def _actualizar_farmacia_data(self, fecha_inicio: datetime, fecha_fin: datetime):
        """Actualiza datos de farmacia/ventas"""
        try:
            ventas = self.venta_repo.get_ventas_con_detalles(
                fecha_inicio.strftime('%Y-%m-%d'),
                fecha_fin.strftime('%Y-%m-%d')
            )
            
            total = sum(venta.get('Venta_Total', 0) for venta in ventas)
            
            if total != self._farmacia_total:
                self._farmacia_total = float(total)
                self.farmaciaDataChanged.emit()
                print(f"💊 Farmacia actualizada: Bs {total:.2f}")
                
        except Exception as e:
            print(f"❌ Error actualizando farmacia: {e}")
            self._farmacia_total = 0.0
            self.farmaciaDataChanged.emit()
    
    def _actualizar_consultas_data(self, fecha_inicio: datetime, fecha_fin: datetime):
        """Actualiza datos de consultas"""
        try:
            consultas = self.consulta_repo.get_consultations_by_date_range(fecha_inicio, fecha_fin)
            
            total = 0.0
            for consulta in consultas:
                # Calcular precio según tipo de consulta
                if consulta.get('tipo_consulta') == 'Emergencia':
                    precio = consulta.get('Precio_Emergencia', 0)
                else:
                    precio = consulta.get('Precio_Normal', 0)
                total += float(precio or 0)
            
            if total != self._consultas_total:
                self._consultas_total = total
                self.consultasDataChanged.emit()
                print(f"🩺 Consultas actualizadas: Bs {total:.2f}")
                
        except Exception as e:
            print(f"❌ Error actualizando consultas: {e}")
            self._consultas_total = 0.0
            self.consultasDataChanged.emit()
    
    def _actualizar_laboratorio_data(self, fecha_inicio: datetime, fecha_fin: datetime):
        """Actualiza datos de laboratorio"""
        try:
            # Usar el método de paginación con filtros de fecha
            fecha_inicio_str = fecha_inicio.strftime('%Y-%m-%d')
            fecha_fin_str = fecha_fin.strftime('%Y-%m-%d')
            
            # Obtener todos los exámenes del período (paginación grande)
            resultado = self.laboratorio_repo.get_paginated_exams_with_details(
                page=0, 
                page_size=1000,  # Suficientemente grande para el período
                fecha_desde=fecha_inicio_str,
                fecha_hasta=fecha_fin_str
            )
            
            examenes = resultado.get('examenes', [])
            total = sum(float(examen.get('precioNumerico', 0)) for examen in examenes)
            
            if total != self._laboratorio_total:
                self._laboratorio_total = total
                self.laboratorioDataChanged.emit()
                print(f"🔬 Laboratorio actualizado: Bs {total:.2f}")
                
        except Exception as e:
            print(f"❌ Error actualizando laboratorio: {e}")
            self._laboratorio_total = 0.0
            self.laboratorioDataChanged.emit()
    
    def _actualizar_enfermeria_data(self, fecha_inicio: datetime, fecha_fin: datetime):
        """Actualiza datos de enfermería"""
        try:
            # Usar filtros para obtener procedimientos del período
            filtros = {
                'fechaDesde': fecha_inicio.strftime('%Y-%m-%d'),
                'fechaHasta': fecha_fin.strftime('%Y-%m-%d')
            }
            
            # Usar el método directo del repository de enfermería
            from ..repositories.enfermeria_repository import EnfermeriaRepository
            from ..core.database_conexion import DatabaseConnection
            
            enfermeria_repo_direct = EnfermeriaRepository(DatabaseConnection())
            procedimientos = enfermeria_repo_direct.obtener_procedimientos_enfermeria(filtros)
            
            total = sum(float(proc.get('precioTotal', '0').replace(',', '')) for proc in procedimientos)
            
            if total != self._enfermeria_total:
                self._enfermeria_total = total
                self.enfermeriaDataChanged.emit()
                print(f"🩹 Enfermería actualizada: Bs {total:.2f}")
                
        except Exception as e:
            print(f"❌ Error actualizando enfermería: {e}")
            self._enfermeria_total = 0.0
            self.enfermeriaDataChanged.emit()
    
    def _actualizar_servicios_basicos_data(self, fecha_inicio: datetime, fecha_fin: datetime):
        """Actualiza datos de servicios básicos/gastos"""
        try:
            gastos = self.gasto_repo.get_expenses_by_date_range(fecha_inicio, fecha_fin)
            
            total = sum(float(gasto.get('Monto', 0)) for gasto in gastos)
            
            if total != self._servicios_basicos_total:
                self._servicios_basicos_total = total
                self.serviciosBasicosDataChanged.emit()
                print(f"⚡ Servicios Básicos actualizados: Bs {total:.2f}")
                
        except Exception as e:
            print(f"❌ Error actualizando servicios básicos: {e}")
            self._servicios_basicos_total = 0.0
            self.serviciosBasicosDataChanged.emit()
    
    def _actualizar_datos_grafico(self, fecha_inicio: datetime, fecha_fin: datetime):
        """Actualiza datos para gráficos de tendencias"""
        try:
            # Generar datos de tendencias según el período
            if self._periodo_actual == "hoy":
                self._generar_datos_por_horas(fecha_inicio, fecha_fin)
            elif self._periodo_actual == "semana":
                self._generar_datos_por_dias_semana(fecha_inicio, fecha_fin)
            elif self._periodo_actual == "mes":
                self._generar_datos_por_semanas_mes(fecha_inicio, fecha_fin)
            elif self._periodo_actual == "año":
                self._generar_datos_por_meses_año(fecha_inicio, fecha_fin)
            
            self.graficoDataChanged.emit()
            
        except Exception as e:
            print(f"❌ Error actualizando gráfico: {e}")
            self._grafico_ingresos = []
            self._grafico_egresos = []
            self.graficoDataChanged.emit()
    
    def _generar_datos_por_meses_año(self, fecha_inicio: datetime, fecha_fin: datetime):
        """Genera datos del gráfico por meses del año"""
        ingresos_mes = []
        egresos_mes = []
        
        # Dividir el año en 12 meses
        for mes in range(1, 13):
            try:
                inicio_mes = datetime(self._año_seleccionado, mes, 1)
                if mes == 12:
                    fin_mes = datetime(self._año_seleccionado + 1, 1, 1)
                else:
                    fin_mes = datetime(self._año_seleccionado, mes + 1, 1)
                
                # Ventas del mes
                ventas_mes = self.venta_repo.get_ventas_con_detalles(
                    inicio_mes.strftime('%Y-%m-%d'),
                    fin_mes.strftime('%Y-%m-%d')
                )
                ingreso_mes = sum(v.get('Venta_Total', 0) for v in ventas_mes)
                
                # Gastos del mes
                gastos_mes = self.gasto_repo.get_expenses_by_date_range(inicio_mes, fin_mes)
                egreso_mes = sum(g.get('Monto', 0) for g in gastos_mes)
                
                ingresos_mes.append(float(ingreso_mes))
                egresos_mes.append(float(egreso_mes))
                
            except Exception as e:
                print(f"❌ Error procesando mes {mes}: {e}")
                ingresos_mes.append(0.0)
                egresos_mes.append(0.0)
        
        self._grafico_ingresos = ingresos_mes
        self._grafico_egresos = egresos_mes
        print(f"📊 Gráfico anual generado: {len(ingresos_mes)} puntos")
    
    def _generar_datos_por_semanas_mes(self, fecha_inicio: datetime, fecha_fin: datetime):
        """Genera datos del gráfico por semanas del mes"""
        # Simplificado: 4 semanas aproximadas
        ingresos_sem = []
        egresos_sem = []
        
        dias_mes = (fecha_fin - fecha_inicio).days
        dias_por_semana = max(7, dias_mes // 4)
        
        for semana in range(4):
            try:
                inicio_sem = fecha_inicio + timedelta(days=semana * dias_por_semana)
                fin_sem = min(inicio_sem + timedelta(days=dias_por_semana), fecha_fin)
                
                # Calcular proporción de ingresos/egresos para esta semana
                proporcion = (fin_sem - inicio_sem).days / dias_mes if dias_mes > 0 else 0.25
                
                ingreso_sem = self.totalIngresos * proporcion
                egreso_sem = self.totalEgresos * proporcion
                
                ingresos_sem.append(float(ingreso_sem))
                egresos_sem.append(float(egreso_sem))
                
            except Exception as e:
                print(f"❌ Error procesando semana {semana}: {e}")
                ingresos_sem.append(0.0)
                egresos_sem.append(0.0)
        
        self._grafico_ingresos = ingresos_sem
        self._grafico_egresos = egresos_sem
    
    def _generar_datos_por_dias_semana(self, fecha_inicio: datetime, fecha_fin: datetime):
        """Genera datos del gráfico por días de la semana"""
        # 7 días de la semana
        ingresos_dia = []
        egresos_dia = []
        
        for dia in range(7):
            # Distribución proporcional simplificada
            proporcion = 1.0 / 7.0
            ingreso_dia = self.totalIngresos * proporcion
            egreso_dia = self.totalEgresos * proporcion
            
            ingresos_dia.append(float(ingreso_dia))
            egresos_dia.append(float(egreso_dia))
        
        self._grafico_ingresos = ingresos_dia
        self._grafico_egresos = egresos_dia
    
    def _generar_datos_por_horas(self, fecha_inicio: datetime, fecha_fin: datetime):
        """Genera datos del gráfico por horas del día"""
        # 24 horas, distribución simulada basada en horarios típicos de clínica
        horas_activas = [8, 9, 10, 11, 14, 15, 16, 17]  # Horarios típicos
        
        ingresos_hora = []
        egresos_hora = []
        
        for hora in range(24):
            if hora in horas_activas:
                proporcion = 1.0 / len(horas_activas)
                ingreso_hora_val = self.totalIngresos * proporcion
                egreso_hora_val = self.totalEgresos * proporcion
            else:
                ingreso_hora_val = 0.0
                egreso_hora_val = 0.0
            
            ingresos_hora.append(float(ingreso_hora_val))
            egresos_hora.append(float(egreso_hora_val))
        
        self._grafico_ingresos = ingresos_hora
        self._grafico_egresos = egresos_hora
    
    def _actualizar_alertas(self):
        """Actualiza alertas de vencimientos"""
        try:
            # Obtener productos próximos a vencer (90 días)
            productos_vencer = self.producto_repo.get_lotes_por_vencer(90)
            
            alertas = []
            for producto in productos_vencer[:10]:  # Solo las primeras 10 alertas
                dias_vencer = producto.get('Dias_Para_Vencer', 0)
                urgencia = "urgent" if dias_vencer <= 30 else "warning"
                
                alerta = {
                    'producto': producto.get('Producto_Nombre', 'Producto Desconocido'),
                    'cantidad': f"{producto.get('Stock_Lote', 0)} unid.",
                    'fecha': producto.get('Fecha_Vencimiento', '').strftime('%d/%m/%Y') if producto.get('Fecha_Vencimiento') else 'N/A',
                    'urgencia': urgencia
                }
                alertas.append(alerta)
            
            self._alertas_vencimientos = alertas
            self.alertasChanged.emit()
            print(f"⚠️ Alertas actualizadas: {len(alertas)} productos")
            
        except Exception as e:
            print(f"❌ Error actualizando alertas: {e}")
            self._alertas_vencimientos = []
            self.alertasChanged.emit()
    
    def _auto_refresh(self):
        """Auto-refresh periódico (cada 5 minutos)"""
        try:
            print("🔄 Auto-refresh del dashboard...")
            self._actualizar_todos_los_datos()
        except Exception as e:
            print(f"❌ Error en auto-refresh: {e}")

# ===============================
# REGISTRO QML
# ===============================

def register_dashboard_model():
    """Registra el DashboardModel para uso en QML"""
    try:
        qmlRegisterType(DashboardModel, "ClinicaApp", 1, 0, "DashboardModel")
        print("📊 DashboardModel registrado para QML")
    except Exception as e:
        print(f"❌ Error registrando DashboardModel: {e}")
        raise