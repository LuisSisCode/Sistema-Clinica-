"""
Utilidades generales unificadas del sistema clínica
"""

import re
import json
import os
import hashlib
import secrets
from datetime import datetime, timedelta, date
from typing import Any, Dict, List, Optional, Union, Tuple
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

# ===============================
# UTILIDADES DE FECHA Y TIEMPO
# ===============================

def get_current_datetime() -> datetime:
    """Obtiene fecha y hora actual"""
    return datetime.now()

def format_date_for_db(date: datetime) -> str:
    """Formatea fecha para SQL Server"""
    return date.strftime('%Y-%m-%d %H:%M:%S')

def parse_date_from_str(date_str: str) -> Optional[datetime]:
    """Parsea string de fecha en varios formatos comunes"""
    formats = [
        '%Y-%m-%d %H:%M:%S',
        '%Y-%m-%d',
        '%d/%m/%Y',
        '%d-%m-%Y',
        '%m/%d/%Y'
    ]
    
    for fmt in formats:
        try:
            return datetime.strptime(date_str, fmt)
        except ValueError:
            continue
    
    return None

def days_until_expiry(expiry_date: datetime) -> int:
    """Calcula días hasta vencimiento"""
    if isinstance(expiry_date, str):
        expiry_date = parse_date_from_str(expiry_date)
    
    if not expiry_date:
        return 0
    
    delta = expiry_date - datetime.now()
    return delta.days

def is_expired(expiry_date: datetime) -> bool:
    """Verifica si una fecha ya expiró"""
    return days_until_expiry(expiry_date) < 0

def get_date_range_query(start_date: datetime, end_date: datetime) -> tuple:
    """Genera query y parámetros para rango de fechas"""
    query_part = "fecha BETWEEN ? AND ?"
    params = (format_date_for_db(start_date), format_date_for_db(end_date))
    return query_part, params

def fecha_actual_str(formato: str = '%Y-%m-%d') -> str:
    """Retorna fecha actual como string en formato especificado"""
    return datetime.now().strftime(formato)

def fecha_actual_hora_str(formato: str = '%Y-%m-%d %H:%M:%S') -> str:
    """Retorna fecha y hora actual como string"""
    return datetime.now().strftime(formato)

def parsear_fecha(fecha_str: str, formato_entrada: str = '%d/%m/%Y') -> Optional[datetime]:
    """
    Convierte string de fecha a datetime object
    Formatos soportados: DD/MM/YYYY, YYYY-MM-DD, etc.
    """
    if not fecha_str:
        return None
    
    formatos = [
        formato_entrada,
        '%d/%m/%Y',
        '%Y-%m-%d',
        '%d-%m-%Y',
        '%Y/%m/%d',
        '%m/%d/%Y'
    ]
    
    for formato in formatos:
        try:
            return datetime.strptime(fecha_str.strip(), formato)
        except ValueError:
            continue
    
    return None

def formatear_fecha(fecha: Union[datetime, date, str], formato_salida: str = '%d/%m/%Y') -> str:
    """Formatea fecha para mostrar en interfaz"""
    if isinstance(fecha, str):
        fecha = parsear_fecha(fecha)
    
    if fecha:
        return fecha.strftime(formato_salida)
    
    return "Sin fecha"

def es_fecha_valida(fecha_str: str) -> bool:
    """Valida si una fecha string es válida"""
    return parsear_fecha(fecha_str) is not None

def dias_diferencia(fecha1: Union[datetime, str], fecha2: Union[datetime, str] = None) -> int:
    """Calcula diferencia en días entre dos fechas"""
    if fecha2 is None:
        fecha2 = datetime.now()
    
    if isinstance(fecha1, str):
        fecha1 = parsear_fecha(fecha1)
    if isinstance(fecha2, str):
        fecha2 = parsear_fecha(fecha2)
    
    if fecha1 and fecha2:
        return abs((fecha2 - fecha1).days)
    
    return 0

def es_fecha_vencida(fecha_vencimiento: Union[datetime, str]) -> bool:
    """Verifica si una fecha de vencimiento ya pasó"""
    if isinstance(fecha_vencimiento, str):
        fecha_vencimiento = parsear_fecha(fecha_vencimiento)
    
    if fecha_vencimiento:
        return fecha_vencimiento.date() < date.today()
    
    return False

def dias_hasta_vencimiento(fecha_vencimiento: Union[datetime, str]) -> int:
    """Calcula días hasta el vencimiento (negativo si ya venció)"""
    if isinstance(fecha_vencimiento, str):
        fecha_vencimiento = parsear_fecha(fecha_vencimiento)
    
    if fecha_vencimiento:
        return (fecha_vencimiento.date() - date.today()).days
    
    return 0

# ===============================
# UTILIDADES DE TEXTO Y FORMATO
# ===============================

def clean_string(text: str) -> str:
    """Limpia y normaliza string"""
    if not text:
        return ""
    
    return text.strip().replace("  ", " ")

def normalize_name(name: str) -> str:
    """Normaliza nombres propios (capitaliza cada palabra)"""
    if not name:
        return ""
    
    return ' '.join(word.capitalize() for word in clean_string(name).split())

def normalize_email(email: str) -> str:
    """Normaliza email (lowercase, sin espacios)"""
    if not email:
        return ""
    
    return email.lower().strip()

def is_valid_email(email: str) -> bool:
    """Validación robusta de email"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))

def generate_code(prefix: str = "", length: int = 8) -> str:
    """Genera código único con prefijo opcional"""
    random_part = secrets.token_hex(length // 2)
    timestamp = str(int(datetime.now().timestamp()))[-6:]  # Últimos 6 dígitos
    
    if prefix:
        return f"{prefix}-{timestamp}{random_part}"
    return f"{timestamp}{random_part}".upper()

def safe_str(value: Any) -> str:
    """Convierte valor a string seguro"""
    if value is None:
        return ""
    return str(value)

def limpiar_texto(texto: str) -> str:
    """Limpia y normaliza texto de entrada"""
    if not texto:
        return ""
    
    # Eliminar espacios extra y caracteres especiales problemáticos
    texto_limpio = re.sub(r'\s+', ' ', str(texto).strip())
    texto_limpio = re.sub(r'[^\w\s\-\.\,\(\)áéíóúÁÉÍÓÚñÑ]', '', texto_limpio)
    
    return texto_limpio

def truncar_texto(texto: str, longitud: int = 50, sufijo: str = "...") -> str:
    """Trunca texto si es muy largo"""
    if not texto or len(texto) <= longitud:
        return texto
    
    return texto[:longitud - len(sufijo)] + sufijo

def capitalizar_palabras(texto: str) -> str:
    """Capitaliza cada palabra del texto"""
    if not texto:
        return ""
    
    return ' '.join(palabra.capitalize() for palabra in texto.split())

def extraer_numeros(texto: str) -> List[float]:
    """Extrae todos los números de un texto"""
    if not texto:
        return []
    
    patron = r'-?\d+\.?\d*'
    matches = re.findall(patron, texto)
    
    return [float(match) for match in matches if match]

def contar_palabras(texto: str) -> int:
    """Cuenta palabras en un texto"""
    if not texto:
        return 0
    
    return len(texto.split())

# ===============================
# UTILIDADES NUMÉRICAS Y MONETARIAS
# ===============================

def safe_float(value: Any, default: float = 0.0) -> float:
    """Convierte valor a float seguro"""
    try:
        if isinstance(value, Decimal):
            return float(value)
        return float(value) if value is not None else default
    except (ValueError, TypeError):
        return default

def safe_int(value: Any, default: int = 0) -> int:
    """Convierte valor a int seguro"""
    try:
        return int(float(value)) if value is not None else default
    except (ValueError, TypeError):
        return default

def round_decimal(value: Union[float, Decimal], decimals: int = 2) -> Decimal:
    """Redondea valor a decimal con precisión específica"""
    if isinstance(value, str):
        value = Decimal(value)
    elif isinstance(value, float):
        value = Decimal(str(value))
    elif not isinstance(value, Decimal):
        value = Decimal(str(value))
    
    return value.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

def calculate_percentage(part: float, total: float) -> float:
    """Calcula porcentaje seguro"""
    if total == 0:
        return 0.0
    return round((part / total) * 100, 2)

def format_currency(amount: float, currency: str = "Bs") -> str:
    """Formatea cantidad como moneda"""
    return f"{currency} {amount:,.2f}"

def formatear_precio(precio: Union[float, Decimal, int], simbolo: str = "Bs") -> str:
    """Formatea precio para mostrar en interfaz"""
    if precio is None:
        return f"{simbolo}0.00"
    
    try:
        precio_decimal = Decimal(str(precio))
        precio_redondeado = precio_decimal.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        return f"{simbolo}{precio_redondeado:.2f}"
    except (ValueError, TypeError):
        return f"{simbolo}0.00"

def parsear_precio(precio_str: str) -> float:
    """Convierte string de precio a float, eliminando símbolos"""
    if not precio_str:
        return 0.0
    
    # Remover símbolos monetarios y espacios
    precio_limpio = re.sub(r'[^\d.,]', '', str(precio_str))
    precio_limpio = precio_limpio.replace(',', '.')
    
    try:
        return float(precio_limpio)
    except ValueError:
        return 0.0

def calcular_porcentaje(parte: float, total: float) -> float:
    """Calcula porcentaje de una parte del total"""
    if total == 0:
        return 0.0
    return (parte / total) * 100

def aplicar_descuento(precio: float, porcentaje_descuento: float) -> float:
    """Aplica descuento porcentual a un precio"""
    if porcentaje_descuento < 0 or porcentaje_descuento > 100:
        return precio
    
    descuento = precio * (porcentaje_descuento / 100)
    return precio - descuento

def calcular_margen_ganancia(precio_compra: float, precio_venta: float) -> float:
    """Calcula margen de ganancia porcentual"""
    if precio_compra == 0:
        return 0.0
    
    ganancia = precio_venta - precio_compra
    return (ganancia / precio_compra) * 100

# ===============================
# UTILIDADES DE VALIDACIÓN
# ===============================

def validate_positive_number(value: Any, field_name: str = "campo") -> float:
    """Valida que sea un número positivo"""
    num_value = safe_float(value)
    if num_value < 0:
        raise ValueError(f"{field_name} debe ser positivo, recibido: {value}")
    return num_value

def validate_non_negative_int(value: Any, field_name: str = "campo") -> int:
    """Valida que sea un entero no negativo"""
    int_value = safe_int(value)
    if int_value < 0:
        raise ValueError(f"{field_name} debe ser no negativo, recibido: {value}")
    return int_value

def validate_required_string(value: str, field_name: str = "campo", min_length: int = 1) -> str:
    """Valida string requerido con longitud mínima"""
    if not value or not isinstance(value, str):
        raise ValueError(f"{field_name} es requerido")
    
    cleaned = clean_string(value)
    if len(cleaned) < min_length:
        raise ValueError(f"{field_name} debe tener al menos {min_length} caracteres")
    
    return cleaned

def validate_age(age: int, min_age: int = 0, max_age: int = 150) -> int:
    """Valida edad en rango válido"""
    age = safe_int(age)
    if not (min_age <= age <= max_age):
        raise ValueError(f"Edad debe estar entre {min_age} y {max_age} años")
    return age

def validate_phone(phone: str) -> str:
    """Validación básica de teléfono"""
    if not phone:
        return ""
    
    # Remover caracteres no numéricos excepto + al inicio
    phone = re.sub(r'[^\d+]', '', phone)
    
    if len(phone) < 7:
        raise ValueError("Teléfono debe tener al menos 7 dígitos")
    
    return phone

def validar_email(email: str) -> bool:
    """Valida formato de email"""
    if not email:
        return False
    
    patron = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(patron, email) is not None

def validar_telefono(telefono: str) -> bool:
    """Valida formato de teléfono (flexible)"""
    if not telefono:
        return False
    
    # Remover espacios, guiones y paréntesis
    telefono_limpio = re.sub(r'[\s\-\(\)]', '', telefono)
    
    # Verificar que solo contenga números y símbolos + al inicio
    patron = r'^\+?[0-9]{7,15}$'
    return re.match(patron, telefono_limpio) is not None

def validar_codigo_producto(codigo: str) -> bool:
    """Valida formato de código de producto"""
    if not codigo:
        return False
    
    # Alfanumérico, guiones y underscores permitidos, 3-20 caracteres
    patron = r'^[A-Za-z0-9\-_]{3,20}$'
    return re.match(patron, codigo.strip()) is not None

def validar_rango_numerico(valor: Union[int, float], minimo: Union[int, float] = None, 
                          maximo: Union[int, float] = None) -> bool:
    """Valida que un número esté en el rango especificado"""
    try:
        valor_num = float(valor)
        
        if minimo is not None and valor_num < minimo:
            return False
        
        if maximo is not None and valor_num > maximo:
            return False
        
        return True
    except (ValueError, TypeError):
        return False

def validar_edad_paciente(edad: int) -> bool:
    """Valida edad de paciente"""
    return 0 <= edad <= 120

# ===============================
# UTILIDADES DE LISTAS Y DATOS
# ===============================

def group_by_field(data_list: List[Dict], field: str) -> Dict[Any, List[Dict]]:
    """Agrupa lista de diccionarios por campo específico"""
    grouped = {}
    for item in data_list:
        key = item.get(field)
        if key not in grouped:
            grouped[key] = []
        grouped[key].append(item)
    return grouped

def extract_field_values(data_list: List[Dict], field: str, unique: bool = False) -> List[Any]:
    """Extrae valores de un campo específico de lista de diccionarios"""
    values = [item.get(field) for item in data_list if field in item]
    
    if unique:
        return list(set(values))
    
    return values

def filter_by_field(data_list: List[Dict], field: str, value: Any) -> List[Dict]:
    """Filtra lista por valor de campo específico"""
    return [item for item in data_list if item.get(field) == value]

def sort_by_field(data_list: List[Dict], field: str, reverse: bool = False) -> List[Dict]:
    """Ordena lista por campo específico"""
    return sorted(data_list, key=lambda x: x.get(field, ''), reverse=reverse)

def paginate_list(data_list: List[Any], page: int, per_page: int) -> Dict[str, Any]:
    """Pagina lista en memoria"""
    total = len(data_list)
    start_idx = (page - 1) * per_page
    end_idx = start_idx + per_page
    
    return {
        'data': data_list[start_idx:end_idx],
        'total': total,
        'page': page,
        'per_page': per_page,
        'pages': (total + per_page - 1) // per_page,
        'has_prev': page > 1,
        'has_next': end_idx < total
    }

def agrupar_por(lista: List[Dict[str, Any]], clave: str) -> Dict[str, List[Dict[str, Any]]]:
    """Agrupa lista de diccionarios por una clave"""
    grupos = {}
    
    for item in lista:
        valor_clave = item.get(clave)
        if valor_clave not in grupos:
            grupos[valor_clave] = []
        grupos[valor_clave].append(item)
    
    return grupos

def filtrar_dict(diccionario: Dict[str, Any], claves_permitidas: List[str]) -> Dict[str, Any]:
    """Filtra diccionario manteniendo solo las claves especificadas"""
    return {k: v for k, v in diccionario.items() if k in claves_permitidas}

def combinar_dicts(*diccionarios: Dict[str, Any]) -> Dict[str, Any]:
    """Combina múltiples diccionarios (los últimos sobrescriben)"""
    resultado = {}
    for d in diccionarios:
        if isinstance(d, dict):
            resultado.update(d)
    return resultado

def obtener_valor_anidado(diccionario: Dict[str, Any], ruta: str, 
                         separador: str = '.', valor_default: Any = None) -> Any:
    """Obtiene valor de diccionario anidado usando notación de punto"""
    try:
        claves = ruta.split(separador)
        valor = diccionario
        
        for clave in claves:
            valor = valor[clave]
        
        return valor
    except (KeyError, TypeError):
        return valor_default

# ===============================
# UTILIDADES DE INVENTARIO
# ===============================

def calculate_stock_status(stock_actual: int, stock_minimo: int = 10) -> str:
    """Calcula estado de stock"""
    if stock_actual <= 0:
        return "AGOTADO"
    elif stock_actual <= stock_minimo:
        return "BAJO"
    elif stock_actual <= stock_minimo * 2:
        return "MEDIO"
    else:
        return "NORMAL"

def get_expiry_status(expiry_date: datetime, warning_days: int = 90) -> str:
    """Calcula estado de vencimiento"""
    days_left = days_until_expiry(expiry_date)
    
    if days_left < 0:
        return "VENCIDO"
    elif days_left <= 30:
        return "VENCE_PRONTO"
    elif days_left <= warning_days:
        return "ADVERTENCIA"
    else:
        return "VIGENTE"

def calculate_total_with_tax(subtotal: float, tax_rate: float = 0.0) -> Dict[str, float]:
    """Calcula total con impuestos"""
    tax_amount = subtotal * tax_rate
    total = subtotal + tax_amount
    
    return {
        'subtotal': round_decimal(subtotal),
        'tax_amount': round_decimal(tax_amount),
        'tax_rate': tax_rate,
        'total': round_decimal(total)
    }

def calcular_estado_vencimiento(fecha_vencimiento: Union[datetime, str], 
                              dias_alerta: int = 90) -> str:
    """Calcula estado de vencimiento: VENCIDO, POR_VENCER, VIGENTE"""
    if isinstance(fecha_vencimiento, str):
        fecha_vencimiento = parsear_fecha(fecha_vencimiento)
    
    if not fecha_vencimiento:
        return "SIN_FECHA"
    
    dias_restantes = dias_hasta_vencimiento(fecha_vencimiento)
    
    if dias_restantes < 0:
        return "VENCIDO"
    elif dias_restantes <= dias_alerta:
        return "POR_VENCER"
    else:
        return "VIGENTE"

# ===============================
# UTILIDADES DE CONVERSIÓN
# ===============================

def dict_a_json(data: Dict[str, Any], pretty: bool = False) -> str:
    """Convierte diccionario a JSON string"""
    try:
        if pretty:
            return json.dumps(data, indent=2, ensure_ascii=False, default=str)
        else:
            return json.dumps(data, ensure_ascii=False, default=str)
    except (TypeError, ValueError):
        return "{}"

def json_a_dict(json_str: str) -> Dict[str, Any]:
    """Convierte JSON string a diccionario"""
    try:
        return json.loads(json_str)
    except (json.JSONDecodeError, TypeError):
        return {}

def lista_a_string(lista: List[Any], separador: str = ", ") -> str:
    """Convierte lista a string separado"""
    if not lista:
        return ""
    
    return separador.join(str(item) for item in lista)

def bytes_a_mb(bytes_size: int) -> float:
    """Convierte bytes a megabytes"""
    return bytes_size / (1024 * 1024)

def normalizar_booleano(valor: Any) -> bool:
    """Normaliza diferentes tipos de valores a booleano"""
    if isinstance(valor, bool):
        return valor
    
    if isinstance(valor, str):
        return valor.lower() in ['true', '1', 'si', 'sí', 'yes', 'on']
    
    if isinstance(valor, (int, float)):
        return valor != 0
    
    return False

# ===============================
# UTILIDADES DE SEGURIDAD
# ===============================

def generate_secure_hash(data: str, salt: str = None) -> str:
    """Genera hash seguro con salt opcional"""
    if salt is None:
        salt = secrets.token_hex(16)
    
    combined = f"{salt}{data}"
    hash_obj = hashlib.sha256(combined.encode())
    return f"{salt}${hash_obj.hexdigest()}"

def verify_secure_hash(data: str, hashed_data: str) -> bool:
    """Verifica hash seguro"""
    try:
        salt, stored_hash = hashed_data.split('$', 1)
        combined = f"{salt}{data}"
        computed_hash = hashlib.sha256(combined.encode()).hexdigest()
        return computed_hash == stored_hash
    except Exception:
        return False

def generate_session_token() -> str:
    """Genera token de sesión único"""
    return secrets.token_urlsafe(32)

# ===============================
# UTILIDADES PARA QML
# ===============================

def preparar_para_qml(data: Any) -> Any:
    """Prepara datos para ser consumidos por QML"""
    if isinstance(data, list):
        return [preparar_para_qml(item) for item in data]
    
    elif isinstance(data, dict):
        resultado = {}
        for key, value in data.items():
            # Convertir claves a string si no lo son
            key_str = str(key)
            resultado[key_str] = preparar_para_qml(value)
        return resultado
    
    elif isinstance(data, Decimal):
        return float(data)
    
    elif isinstance(data, (datetime, date)):
        return data.strftime('%Y-%m-%d %H:%M:%S') if isinstance(data, datetime) else data.strftime('%Y-%m-%d')
    
    elif data is None:
        return ""
    
    return data

def crear_respuesta_qml(exito: bool, mensaje: str = "", datos: Any = None, 
                       codigo_error: str = "") -> Dict[str, Any]:
    """Crea respuesta estándar para QML"""
    respuesta = {
        'exito': exito,
        'mensaje': mensaje,
        'timestamp': fecha_actual_hora_str(),
        'datos': preparar_para_qml(datos) if datos else {}
    }
    
    if not exito and codigo_error:
        respuesta['codigo_error'] = codigo_error
    
    return respuesta

def formatear_lista_para_combobox(items: List[Dict[str, Any]], 
                                 key_id: str = 'id', key_text: str = 'nombre') -> List[Dict[str, Any]]:
    """Formatea lista para usar en ComboBox de QML"""
    resultado = []
    
    for item in items:
        if isinstance(item, dict):
            combo_item = {
                'id': item.get(key_id, 0),
                'text': str(item.get(key_text, 'Sin nombre')),
                'data': item  # Datos completos para referencia
            }
            resultado.append(combo_item)
    
    return resultado

# ===============================
# UTILIDADES DE ARCHIVOS
# ===============================

def crear_directorio_si_no_existe(ruta: Union[str, Path]) -> bool:
    """Crea directorio si no existe"""
    try:
        Path(ruta).mkdir(parents=True, exist_ok=True)
        return True
    except Exception:
        return False

def obtener_tamaño_archivo(ruta: Union[str, Path]) -> int:
    """Obtiene tamaño de archivo en bytes"""
    try:
        return Path(ruta).stat().st_size
    except Exception:
        return 0

def limpiar_nombre_archivo(nombre: str) -> str:
    """Limpia nombre de archivo eliminando caracteres problemáticos"""
    # Remover caracteres no válidos para nombres de archivo
    nombre_limpio = re.sub(r'[<>:"/\\|?*]', '_', nombre)
    nombre_limpio = re.sub(r'\s+', '_', nombre_limpio)
    
    # Limitar longitud
    if len(nombre_limpio) > 50:
        nombre_limpio = nombre_limpio[:47] + "..."
    
    return nombre_limpio

def obtener_extension(ruta: Union[str, Path]) -> str:
    """Obtiene extensión de archivo"""
    return Path(ruta).suffix.lower()

# ===============================
# UTILIDADES DE SISTEMA
# ===============================

def safe_dict_get(dictionary: Dict, key: str, default: Any = None, cast_type: type = None):
    """Obtiene valor de diccionario con casting opcional"""
    value = dictionary.get(key, default)
    
    if value is None:
        return default
    
    if cast_type is not None:
        try:
            if cast_type == bool:
                if isinstance(value, str):
                    return value.lower() in ('true', '1', 'yes', 'on')
                return bool(value)
            return cast_type(value)
        except (ValueError, TypeError):
            return default
    
    return value

def merge_dicts(*dicts: Dict) -> Dict:
    """Combina múltiples diccionarios"""
    result = {}
    for d in dicts:
        if isinstance(d, dict):
            result.update(d)
    return result

def print_separator(title: str = "", width: int = 50):
    """Imprime separador visual en terminal"""
    if title:
        title = f" {title} "
        separator = title.center(width, "=")
    else:
        separator = "=" * width
    
    print(separator)

def log_operation(operation: str, details: str = ""):
    """Log simple de operación"""
    timestamp = datetime.now().strftime('%H:%M:%S')
    if details:
        print(f"[{timestamp}] {operation} - {details}")
    else:
        print(f"[{timestamp}] {operation}")

def is_empty(valor: Any) -> bool:
    """Verifica si un valor está vacío (None, "", [], {}, etc.)"""
    if valor is None:
        return True
    
    if isinstance(valor, (str, list, dict, tuple)):
        return len(valor) == 0
    
    return False

# ===============================
# UTILIDADES ESPECÍFICAS CLÍNICA
# ===============================

def generar_codigo_producto(nombre: str, marca: str = "") -> str:
    """Genera código de producto basado en nombre y marca"""
    if not nombre:
        return "PROD000"
    
    # Tomar primeras 3 letras del nombre
    nombre_codigo = re.sub(r'[^A-Za-z0-9]', '', nombre.upper())[:3]
    
    # Tomar primera letra de marca si existe
    marca_codigo = re.sub(r'[^A-Za-z0-9]', '', marca.upper())[:1] if marca else ""
    
    # Timestamp para unicidad
    timestamp = datetime.now().strftime("%m%d")
    
    return f"{nombre_codigo}{marca_codigo}{timestamp}"

def formatear_nombre_completo(nombre: str, apellido_paterno: str, 
                            apellido_materno: str = "") -> str:
    """Formatea nombre completo"""
    partes = [nombre.strip(), apellido_paterno.strip()]
    
    if apellido_materno and apellido_materno.strip():
        partes.append(apellido_materno.strip())
    
    return " ".join(parte for parte in partes if parte)

def generar_id_compra(numero_secuencia: int) -> str:
    """Genera ID de compra con formato C001, C002, etc."""
    return f"C{numero_secuencia:03d}"

def generar_id_venta(numero_secuencia: int) -> str:
    """Genera ID de venta con formato V001, V002, etc."""
    return f"V{numero_secuencia:03d}"

# ===============================
# UTILIDADES DE PERFORMANCE
# ===============================

def medir_tiempo_ejecucion(func):
    """Decorador para medir tiempo de ejecución"""
    import time
    from functools import wraps
    
    @wraps(func)
    def wrapper(*args, **kwargs):
        inicio = time.time()
        resultado = func(*args, **kwargs)
        fin = time.time()
        
        tiempo_ms = (fin - inicio) * 1000
        print(f"⏱️ {func.__name__}: {tiempo_ms:.2f}ms")
        
        return resultado
    
    return wrapper

# ===============================
# CONSTANTES ÚTILES
# ===============================

MESES_ESPANOL = {
    1: "Enero", 2: "Febrero", 3: "Marzo", 4: "Abril",
    5: "Mayo", 6: "Junio", 7: "Julio", 8: "Agosto",
    9: "Septiembre", 10: "Octubre", 11: "Noviembre", 12: "Diciembre"
}

DIAS_SEMANA_ESPANOL = {
    0: "Lunes", 1: "Martes", 2: "Miércoles", 3: "Jueves",
    4: "Viernes", 5: "Sábado", 6: "Domingo"
}

STOCK_STATES = {
    "AGOTADO": {"color": "red", "priority": 1},
    "BAJO": {"color": "orange", "priority": 2},
    "MEDIO": {"color": "yellow", "priority": 3},
    "NORMAL": {"color": "green", "priority": 4}
}

EXPIRY_STATES = {
    "VENCIDO": {"color": "red", "priority": 1},
    "VENCE_PRONTO": {"color": "orange", "priority": 2},
    "ADVERTENCIA": {"color": "yellow", "priority": 3},
    "VIGENTE": {"color": "green", "priority": 4}
}

# Instancias globales útiles
FECHA_HOY = fecha_actual_str()
HORA_ACTUAL = fecha_actual_hora_str()