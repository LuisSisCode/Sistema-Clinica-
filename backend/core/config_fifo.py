"""
Configuración para Sistema FIFO 2.0
Permite activar/desactivar el nuevo sistema basado en procedimientos almacenados
"""

class ConfigFIFO:
    """Configuración centralizada del sistema FIFO"""
    
    # ===============================
    # FLAGS DE ACTIVACIÓN
    # ===============================
    
    # Sistema de ventas
    USE_VENTA_FIFO_V2 = True  # True = Usa sp_Vender_Producto_FIFO, False = Usa lógica Python
    
    # Sistema de compras
    USE_COMPRA_SP = True  # True = Usa sp_Registrar_Compra_Con_Lotes, False = Usa lógica Python
    
    # Vistas para consultas
    USE_VISTAS_SQL = True  # True = Usa vistas (vw_Stock_Actual, etc), False = Usa queries directas
    
    # Márgenes automáticos
    USE_MARGENES_AUTO = True  # True = Triggers calculan márgenes, False = Python los calcula
    
    # ===============================
    # CONFIGURACIÓN DE FALLBACK
    # ===============================
    
    # Si falla el sistema nuevo, ¿usar el antiguo automáticamente?
    AUTO_FALLBACK_TO_LEGACY = True
    
    # Logging detallado
    DEBUG_FIFO = True
    LOG_SQL_QUERIES = False  # Solo para debugging profundo
    
    # ===============================
    # CONFIGURACIÓN DE ALERTAS
    # ===============================
    
    # Días de anticipación para alertas de vencimiento
    DIAS_ALERTA_VENCIMIENTO = 90
    
    # Stock mínimo para alertas
    STOCK_MINIMO_ALERTA = 10
    
    # ===============================
    # MÉTODOS DE UTILIDAD
    # ===============================
    
    @classmethod
    def usar_sistema_nuevo(cls) -> bool:
        """Verifica si debe usar el sistema FIFO 2.0"""
        return cls.USE_VENTA_FIFO_V2 or cls.USE_COMPRA_SP
    
    @classmethod
    def print_config(cls):
        """Imprime configuración actual"""
        print("\n" + "="*60)
        print("⚙️  CONFIGURACIÓN SISTEMA FIFO 2.0")
        print("="*60)
        print(f"🔄 Ventas FIFO V2:        {'✅ ACTIVO' if cls.USE_VENTA_FIFO_V2 else '❌ DESACTIVADO'}")
        print(f"🛒 Compras SP:            {'✅ ACTIVO' if cls.USE_COMPRA_SP else '❌ DESACTIVADO'}")
        print(f"📊 Vistas SQL:            {'✅ ACTIVO' if cls.USE_VISTAS_SQL else '❌ DESACTIVADO'}")
        print(f"💰 Márgenes Automáticos:  {'✅ ACTIVO' if cls.USE_MARGENES_AUTO else '✅ DESACTIVADO'}")
        print(f"🔙 Auto Fallback:         {'✅ ACTIVO' if cls.AUTO_FALLBACK_TO_LEGACY else '❌ DESACTIVADO'}")
        print(f"🐛 Debug:                 {'✅ ACTIVO' if cls.DEBUG_FIFO else '❌ DESACTIVADO'}")
        print(f"⏰ Alerta vencimiento:    {cls.DIAS_ALERTA_VENCIMIENTO} días")
        print(f"📦 Stock mínimo:          {cls.STOCK_MINIMO_ALERTA} unidades")
        print("="*60 + "\n")
    
    @classmethod
    def modo_testing(cls):
        """Configuración para testing - ambos sistemas activados"""
        cls.USE_VENTA_FIFO_V2 = False  # Permite comparar
        cls.USE_COMPRA_SP = False
        cls.DEBUG_FIFO = True
        cls.LOG_SQL_QUERIES = True
        print("🧪 Modo TESTING activado - Sistemas legacy para comparación")
    
    @classmethod
    def modo_produccion(cls):
        """Configuración para producción - solo sistema nuevo"""
        cls.USE_VENTA_FIFO_V2 = True
        cls.USE_COMPRA_SP = True
        cls.USE_VISTAS_SQL = True
        cls.USE_MARGENES_AUTO = True
        cls.AUTO_FALLBACK_TO_LEGACY = True
        cls.DEBUG_FIFO = False
        cls.LOG_SQL_QUERIES = False
        print("🚀 Modo PRODUCCIÓN activado - Sistema FIFO 2.0")

# Instancia global
config_fifo = ConfigFIFO()

if __name__ == "__main__":
    config_fifo.print_config()
