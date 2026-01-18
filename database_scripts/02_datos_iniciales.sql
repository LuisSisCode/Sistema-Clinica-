-- ============================================
-- DATOS INICIALES - Sistema Clínica María Inmaculada
-- Versión 2.0 - PRODUCCIÓN
-- Ejecutar DESPUÉS de 01_schema.sql
-- ============================================

USE ClinicaMariaInmaculada;
GO

PRINT '============================================';
PRINT 'INICIANDO CARGA DE DATOS INICIALES';
PRINT 'Sistema Clínica María Inmaculada v2.0';
PRINT '============================================';

-- ==========================================
-- 1. ROLES (Sistema de permisos)
-- ==========================================
PRINT 'Cargando Roles...';

IF NOT EXISTS (SELECT 1 FROM Roles WHERE Nombre = 'Administrador')
BEGIN
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES 
    ('Administrador', 'Acceso completo al sistema', 1),
    ('Medico', 'Acceso a consultas y pacientes', 1);
    
    PRINT '  2 roles creados exitosamente';
END
ELSE
BEGIN
    PRINT '  Roles ya existen';
END
GO

-- ==========================================
-- 2. TIPOS DE TRABAJADORES
-- ==========================================
PRINT 'Cargando Tipos de Trabajadores...';

IF NOT EXISTS (SELECT 1 FROM Tipo_Trabajadores WHERE Tipo = 'Medico General')
BEGIN
    INSERT INTO Tipo_Trabajadores (Tipo, descripcion, area_funcional) VALUES
    ('Medico General', 'Medico de consulta externa general', 'MEDICO'),
    ('Medico Especialista', 'Medico con especialidad certificada', 'MEDICO'),
    ('Medico de Emergencia', 'Medico de guardia en emergencias', 'MEDICO'),
    ('Director Medico', 'Director del area medica', 'MEDICO'),
    ('Enfermera Profesional', 'Licenciada en enfermeria', 'ENFERMERIA'),
    ('Auxiliar de Enfermeria', 'Tecnico auxiliar de enfermeria', 'ENFERMERIA'),
    ('Jefe de Enfermeria', 'Responsable del area de enfermeria', 'ENFERMERIA'),
    ('Biologo', 'Profesional en biologia y analisis clinicos', 'LABORATORIO'),
    ('Tecnico de Laboratorio', 'Tecnico en analisis de laboratorio', 'LABORATORIO'),
    ('Jefe de Laboratorio', 'Responsable del area de laboratorio', 'LABORATORIO'),
    ('Quimico Farmaceutico', 'Profesional farmaceutico licenciado', 'FARMACIA'),
    ('Auxiliar de Farmacia', 'Asistente de farmacia', 'FARMACIA'),
    ('Recepcionista', 'Atencion al publico y registro', 'ADMINISTRATIVO'),
    ('Cajero', 'Responsable de caja y cobros', 'ADMINISTRATIVO'),
    ('Secretaria', 'Asistente administrativa', 'ADMINISTRATIVO'),
    ('Contador', 'Contador general', 'ADMINISTRATIVO'),
    ('Asistente Contable', 'Auxiliar contable', 'ADMINISTRATIVO'),
    ('Gerente Administrativo', 'Gerente de administracion', 'ADMINISTRATIVO'),
    ('Personal de Limpieza', 'Limpieza y mantenimiento', 'SERVICIOS'),
    ('Seguridad', 'Personal de seguridad', 'SERVICIOS');
    
    PRINT '  20 tipos de trabajadores creados';
END
ELSE
BEGIN
    PRINT '  Tipos de trabajadores ya existen';
END
GO

-- ==========================================
-- 3. TIPOS DE GASTOS
-- ==========================================
PRINT 'Cargando Tipos de Gastos...';

IF NOT EXISTS (SELECT 1 FROM Tipo_Gastos WHERE Nombre = 'Servicios Basicos')
BEGIN
    INSERT INTO Tipo_Gastos (Nombre, descripcion) VALUES
    -- Servicios básicos
    ('Servicios Basicos', 'Servicios publicos esenciales'),
    ('Agua Potable', 'Servicio de agua SAGUAPAC'),
    ('Energia Electrica', 'Servicio de luz CRE'),
    ('Internet', 'Servicio de internet y conectividad'),
    ('Telefonia', 'Telefonia fija y movil'),
    ('Gas', 'Servicio de gas'),
    
    -- Insumos médicos
    ('Medicamentos', 'Compra de medicamentos para farmacia'),
    ('Material Medico', 'Material medico quirurgico'),
    ('Material de Curacion', 'Gasas, vendajes, suturas'),
    ('Reactivos de Laboratorio', 'Reactivos e insumos de laboratorio'),
    ('Material de Limpieza', 'Productos de limpieza y desinfeccion'),
    ('Papeleria', 'Papeleria y utiles de oficina'),
    
    -- Equipamiento
    ('Equipamiento Medico', 'Compra de equipo medico'),
    ('Equipamiento de Oficina', 'Mobiliario y equipo de oficina'),
    ('Mantenimiento de Equipos', 'Mantenimiento preventivo y correctivo'),
    ('Reparaciones', 'Reparaciones de equipos e instalaciones'),
    
    -- Personal
    ('Salarios', 'Pago de salarios y sueldos'),
    ('Aguinaldos', 'Pago de aguinaldos'),
    ('Bonos', 'Bonificaciones al personal'),
    ('Beneficios Sociales', 'Seguro social y beneficios'),
    ('Capacitacion', 'Cursos y capacitaciones del personal'),
    
    -- Operativos
    ('Alquiler', 'Alquiler de inmuebles o equipos'),
    ('Seguros', 'Seguros y polizas'),
    ('Impuestos', 'Impuestos municipales y nacionales'),
    ('Honorarios Profesionales', 'Honorarios a profesionales externos'),
    ('Publicidad', 'Marketing y publicidad'),
    ('Combustible', 'Combustible para vehiculos o generador'),
    ('Transporte', 'Gastos de transporte'),
    ('Alimentacion', 'Alimentacion para personal de guardia'),
    ('Licencias y Permisos', 'Licencias de software y permisos municipales'),
    ('Servicios Legales', 'Asesoria legal'),
    ('Servicios Contables', 'Servicios de auditoria y contabilidad'),
    ('Limpieza', 'Servicio de limpieza externa'),
    ('Seguridad', 'Servicio de seguridad'),
    ('Donaciones', 'Donaciones y responsabilidad social'),
    ('Gastos Bancarios', 'Comisiones y cargos bancarios'),
    ('Otros', 'Gastos varios no clasificados');
    
    PRINT '  36 tipos de gastos creados';
END
ELSE
BEGIN
    PRINT '  Tipos de gastos ya existen';
END
GO

-- ==========================================
-- 4. TIPOS DE ANÁLISIS DE LABORATORIO
-- ==========================================
PRINT 'Cargando Tipos de Analisis...';

IF NOT EXISTS (SELECT 1 FROM Tipos_Analisis WHERE Nombre = 'Hemograma Completo')
BEGIN
    INSERT INTO Tipos_Analisis (Nombre, Descripcion, Precio_Normal, Precio_Emergencia) VALUES
    -- Hematología
    ('Hemograma Completo', 'Recuento completo: GR, GB, plaquetas, hemoglobina, hematocrito', 50.00, 80.00),
    ('Grupo Sanguineo y Factor Rh', 'Determinacion ABO y Rh', 30.00, 50.00),
    ('Tiempo de Coagulacion', 'Tiempo de sangrado y coagulacion', 25.00, 40.00),
    ('Velocidad de Sedimentacion', 'VSG', 20.00, 35.00),
    ('Recuento de Reticulocitos', 'Determinacion de reticulocitos', 35.00, 55.00),
    
    -- Química Sanguínea
    ('Glucosa en Ayunas', 'Determinacion de glucosa basal', 15.00, 25.00),
    ('Glucosa Post Prandial', 'Glucosa 2 horas despues de comer', 15.00, 25.00),
    ('Hemoglobina Glicosilada', 'HbA1c - control diabetico', 80.00, 120.00),
    ('Urea', 'Funcion renal', 20.00, 35.00),
    ('Creatinina', 'Funcion renal', 20.00, 35.00),
    ('Acido Urico', 'Determinacion de uratos', 20.00, 30.00),
    ('Perfil Renal Completo', 'Urea, creatinina, acido urico, electrolitos', 60.00, 90.00),
    
    -- Perfil Lipídico
    ('Colesterol Total', 'Nivel de colesterol', 20.00, 35.00),
    ('Colesterol HDL', 'Colesterol bueno', 25.00, 40.00),
    ('Colesterol LDL', 'Colesterol malo', 25.00, 40.00),
    ('Trigliceridos', 'Nivel de trigliceridos', 20.00, 35.00),
    ('Perfil Lipidico Completo', 'Colesterol total, HDL, LDL, trigliceridos, VLDL', 60.00, 95.00),
    
    -- Perfil Hepático
    ('TGO (AST)', 'Transaminasa glutamico oxalacetica', 25.00, 40.00),
    ('TGP (ALT)', 'Transaminasa glutamico piruvica', 25.00, 40.00),
    ('Bilirrubina Total', 'Bilirrubina directa e indirecta', 25.00, 40.00),
    ('Fosfatasa Alcalina', 'Enzima hepatica', 25.00, 40.00),
    ('Proteinas Totales', 'Albumina y globulina', 25.00, 40.00),
    ('Perfil Hepatico Completo', 'TGO, TGP, bilirrubina, fosfatasa, proteinas', 80.00, 120.00),
    
    -- Electrolitos
    ('Sodio', 'Nivel de sodio serico', 20.00, 35.00),
    ('Potasio', 'Nivel de potasio serico', 20.00, 35.00),
    ('Cloro', 'Nivel de cloro serico', 20.00, 35.00),
    ('Calcio', 'Calcio serico', 20.00, 35.00),
    ('Magnesio', 'Magnesio serico', 25.00, 40.00),
    ('Fosforo', 'Fosforo serico', 20.00, 35.00),
    ('Electrolitos Completos', 'Na, K, Cl, Ca', 50.00, 80.00),
    
    -- Urianálisis
    ('Orina Completo', 'Examen fisico, quimico y microscopico', 25.00, 40.00),
    ('Urocultivo', 'Cultivo de orina con antibiograma', 60.00, 90.00),
    ('Depuracion de Creatinina', 'Prueba de funcion renal 24 horas', 50.00, 75.00),
    
    -- Coprología
    ('Heces Completo', 'Examen macroscopico y microscopico', 20.00, 35.00),
    ('Test de Graham', 'Deteccion de oxiuros', 15.00, 25.00),
    ('Coprocultivo', 'Cultivo de heces con antibiograma', 70.00, 105.00),
    ('Sangre Oculta en Heces', 'Test de hemorragia digestiva', 25.00, 40.00),
    
    -- Hormonas
    ('TSH', 'Hormona estimulante de tiroides', 45.00, 70.00),
    ('T3 Total', 'Triyodotironina', 40.00, 65.00),
    ('T4 Total', 'Tiroxina', 40.00, 65.00),
    ('T3 Libre', 'Triyodotironina libre', 50.00, 75.00),
    ('T4 Libre', 'Tiroxina libre', 50.00, 75.00),
    ('Perfil Tiroideo Completo', 'TSH, T3, T4', 100.00, 150.00),
    
    -- Marcadores Cardíacos
    ('Troponina I', 'Marcador de infarto', 80.00, 120.00),
    ('CPK Total', 'Creatinfosfoquinasa', 35.00, 55.00),
    ('CPK-MB', 'Fraccion cardiaca', 45.00, 70.00),
    ('LDH', 'Lactato deshidrogenasa', 30.00, 50.00),
    
    -- Marcadores Tumorales
    ('PSA Total', 'Antigeno prostatico especifico', 60.00, 90.00),
    ('PSA Libre', 'Fraccion libre de PSA', 65.00, 95.00),
    ('CEA', 'Antigeno carcinoembrionario', 70.00, 105.00),
    ('CA 19-9', 'Marcador tumoral gastrointestinal', 70.00, 105.00),
    ('CA 125', 'Marcador tumoral ovarico', 70.00, 105.00),
    ('AFP', 'Alfa fetoproteina', 65.00, 95.00),
    
    -- Serología Infecciosa
    ('VIH (ELISA)', 'Deteccion de anticuerpos VIH', 60.00, 90.00),
    ('VDRL', 'Prueba de sifilis', 25.00, 40.00),
    ('RPR', 'Reagina plasmatica rapida - sifilis', 30.00, 45.00),
    ('HBsAg', 'Antigeno de superficie hepatitis B', 50.00, 75.00),
    ('Anti-HCV', 'Anticuerpos hepatitis C', 55.00, 80.00),
    ('Chagas', 'Serologia para enfermedad de Chagas', 40.00, 65.00),
    ('Dengue NS1', 'Antigeno NS1 dengue', 80.00, 120.00),
    ('Dengue IgM/IgG', 'Anticuerpos dengue', 70.00, 105.00),
    ('COVID-19 Antigeno', 'Test rapido de antigeno', 60.00, 90.00),
    ('COVID-19 PCR', 'RT-PCR SARS-CoV-2', 150.00, 200.00),
    
    -- Inmunología
    ('Proteina C Reactiva', 'PCR - marcador inflamatorio', 35.00, 55.00),
    ('PCR Ultrasensible', 'PCR de alta sensibilidad', 50.00, 75.00),
    ('Factor Reumatoideo', 'Anticuerpos reumatoides', 40.00, 65.00),
    ('Antiestreptolisinas O', 'ASTO', 35.00, 55.00),
    ('Latex', 'Prueba de aglutinacion', 30.00, 50.00),
    
    -- Vitaminas
    ('Vitamina D', '25-OH vitamina D', 80.00, 120.00),
    ('Vitamina B12', 'Cianocobalamina', 60.00, 90.00),
    ('Acido Folico', 'Folatos sericos', 50.00, 75.00),
    ('Ferritina', 'Reservas de hierro', 55.00, 80.00),
    ('Hierro Serico', 'Nivel de hierro', 30.00, 50.00),
    
    -- Embarazo
    ('Test de Embarazo', 'Beta-HCG cualitativo', 20.00, 35.00),
    ('Beta-HCG Cuantitativo', 'Gonadotropina corionica', 45.00, 70.00),
    
    -- Microbiología
    ('Cultivo de Secrecion', 'Con antibiograma', 60.00, 90.00),
    ('Cultivo de Esputo', 'Con antibiograma', 60.00, 90.00),
    ('Hemocultivo', 'Cultivo de sangre', 100.00, 150.00),
    ('Test de BK', 'Baciloscopia tuberculosis', 30.00, 50.00);
    
    PRINT '  80 tipos de analisis creados';
END
ELSE
BEGIN
    PRINT '  Tipos de analisis ya existen';
END
GO

-- ==========================================
-- 5. TIPOS DE PROCEDIMIENTOS (Enfermería)
-- ==========================================
PRINT 'Cargando Tipos de Procedimientos...';

IF NOT EXISTS (SELECT 1 FROM Tipos_Procedimientos WHERE Nombre = 'Inyeccion Intramuscular')
BEGIN
    INSERT INTO Tipos_Procedimientos (Nombre, Descripcion, Precio_Normal, Precio_Emergencia) VALUES
    -- Administración de medicamentos
    ('Inyeccion Intramuscular', 'Aplicacion IM de medicamento', 15.00, 25.00),
    ('Inyeccion Endovenosa', 'Aplicacion EV directa', 20.00, 35.00),
    ('Inyeccion Subcutanea', 'Aplicacion SC de medicamento', 15.00, 25.00),
    ('Inyeccion Intradermica', 'Aplicacion ID (PPD, vacunas)', 15.00, 25.00),
    ('Nebulizacion', 'Terapia respiratoria nebulizada', 25.00, 40.00),
    ('Aplicacion de Medicamento Topico', 'Pomadas, cremas, unguentos', 15.00, 25.00),
    
    -- Vías de acceso
    ('Instalacion de Via Periferica', 'Canalizacion de vena periferica', 35.00, 55.00),
    ('Cambio de Via Periferica', 'Recambio de cateter venoso', 30.00, 50.00),
    ('Retiro de Via Periferica', 'Remocion de cateter', 15.00, 25.00),
    ('Flebotomia', 'Extraccion de sangre venosa', 15.00, 25.00),
    ('Puncion Capilar', 'Toma de muestra capilar', 10.00, 15.00),
    
    -- Curaciones
    ('Curacion Simple', 'Herida limpia sin complicaciones', 30.00, 50.00),
    ('Curacion Compleja', 'Herida infectada o complicada', 50.00, 80.00),
    ('Curacion de Quemadura', 'Tratamiento de quemaduras', 60.00, 95.00),
    ('Cambio de Vendaje', 'Renovacion de aposito', 20.00, 35.00),
    ('Lavado de Herida', 'Limpieza quirurgica', 40.00, 65.00),
    
    -- Suturas
    ('Sutura Simple', '1-5 puntos, herida limpia', 60.00, 95.00),
    ('Sutura Compleja', 'Mas de 5 puntos o zona complicada', 100.00, 150.00),
    ('Retiro de Puntos', 'Remocion de suturas', 30.00, 50.00),
    ('Retiro de Grapas', 'Remocion de grapas quirurgicas', 30.00, 50.00),
    
    -- Sondajes
    ('Sondaje Vesical', 'Instalacion de sonda Foley', 50.00, 80.00),
    ('Cambio de Sonda Vesical', 'Recambio de sonda urinaria', 40.00, 65.00),
    ('Retiro de Sonda Vesical', 'Remocion de cateter urinario', 25.00, 40.00),
    ('Sondaje Nasogastrico', 'Instalacion de SNG', 50.00, 80.00),
    ('Retiro de Sonda Nasogastrica', 'Remocion de SNG', 25.00, 40.00),
    
    -- Monitoreo
    ('Toma de Signos Vitales', 'PA, FC, FR, Tº, Sat O2', 15.00, 25.00),
    ('Control de Glucemia Capilar', 'Glucometria', 15.00, 25.00),
    ('Oximetria de Pulso', 'Saturacion de oxigeno', 10.00, 15.00),
    ('Electrocardiograma', 'ECG de 12 derivaciones', 50.00, 80.00),
    ('Monitoreo Continuo', 'Monitorizacion por hora', 25.00, 40.00),
    
    -- Oxigenoterapia
    ('Oxigenoterapia con Bigotera', 'Administracion O2 nasal', 30.00, 50.00),
    ('Oxigenoterapia con Mascarilla', 'Administracion O2 facial', 35.00, 55.00),
    ('Oxigenoterapia con Reservorio', 'Alto flujo de oxigeno', 45.00, 70.00),
    
    -- Procedimientos especiales
    ('Lavado Gastrico', 'Procedimiento de emergencia', 80.00, 120.00),
    ('Enema Evacuante', 'Lavado intestinal', 40.00, 65.00),
    ('Aspiracion de Secreciones', 'Succion orofaringea/nasal', 35.00, 55.00),
    ('Vendaje Compresivo', 'Vendaje para hemostasia', 35.00, 55.00),
    ('Entablillado', 'Inmovilizacion de extremidad', 50.00, 80.00),
    ('Colocacion de Collar Cervical', 'Inmovilizacion cervical', 40.00, 65.00),
    
    -- Vacunación
    ('Aplicacion de Vacuna', 'Inmunizacion (sin costo de vacuna)', 20.00, 30.00),
    ('Aplicacion de Toxoide', 'Antitetanico, antirrabico', 20.00, 30.00),
    
    -- Antropometría
    ('Control de Peso y Talla', 'Medicion antropometrica', 10.00, 15.00),
    ('Medicion de Perimetro Cefalico', 'En pediatria', 10.00, 15.00),
    ('Indice de Masa Corporal', 'Calculo IMC', 10.00, 15.00),
    
    -- Drenajes
    ('Instalacion de Drenaje', 'Colocacion de sistema de drenaje', 70.00, 105.00),
    ('Cambio de Bolsa de Drenaje', 'Renovacion de colector', 30.00, 50.00),
    ('Retiro de Drenaje', 'Remocion de dren', 40.00, 65.00),
    
    -- Otros
    ('Tapizado de Cama', 'Cambio de ropa de cama', 15.00, 25.00),
    ('Bano de Esponja', 'Higiene en cama', 25.00, 40.00),
    ('Atencion Post Mortem', 'Cuidados post defuncion', 100.00, 150.00);
    
    PRINT '  51 tipos de procedimientos creados';
END
ELSE
BEGIN
    PRINT '  Tipos de procedimientos ya existen';
END
GO

-- ==========================================
-- 6. MARCAS (Solo ejemplos básicos)
-- ==========================================
PRINT 'Cargando Marcas de ejemplo...';

IF NOT EXISTS (SELECT 1 FROM Marca WHERE Nombre = 'Generico')
BEGIN
    INSERT INTO Marca (Nombre, Detalles) VALUES
    ('Generico', 'Productos sin marca especifica'),
    ('Bayer', 'Laboratorio Bayer'),
    ('Pfizer', 'Laboratorio Pfizer'),
    ('Roche', 'Laboratorio Roche'),
    ('Nacional', 'Productos nacionales');
    
    PRINT '  5 marcas de ejemplo creadas';
    PRINT '  NOTA: El usuario debe agregar las marcas que utilice';
END
ELSE
BEGIN
    PRINT '  Marcas ya existen';
END
GO

-- ==========================================
-- 7. ESPECIALIDADES MÉDICAS
-- ==========================================
PRINT 'Cargando Especialidades Medicas...';

IF NOT EXISTS (SELECT 1 FROM Especialidad WHERE Nombre = 'Medicina General')
BEGIN
    INSERT INTO Especialidad (Nombre, Detalles, Precio_Normal, Precio_Emergencia) VALUES
    ('Medicina General', 'Consulta medica general', 80.00, 120.00),
    ('Medicina Interna', 'Medicina del adulto', 100.00, 150.00),
    ('Pediatria', 'Medicina infantil (0-18 anos)', 90.00, 135.00),
    ('Neonatologia', 'Atencion del recien nacido', 120.00, 180.00),
    ('Ginecologia', 'Salud femenina', 100.00, 150.00),
    ('Obstetricia', 'Control prenatal y parto', 100.00, 150.00),
    ('Cirugia General', 'Procedimientos quirurgicos', 150.00, 225.00),
    ('Traumatologia', 'Fracturas y lesiones oseas', 110.00, 165.00),
    ('Ortopedia', 'Sistema musculoesqueletico', 110.00, 165.00),
    ('Cardiologia', 'Enfermedades del corazon', 120.00, 180.00),
    ('Neumologia', 'Enfermedades respiratorias', 110.00, 165.00),
    ('Gastroenterologia', 'Sistema digestivo', 110.00, 165.00),
    ('Nefrologia', 'Enfermedades renales', 120.00, 180.00),
    ('Urologia', 'Sistema urinario y reproductor masculino', 100.00, 150.00),
    ('Endocrinologia', 'Diabetes y tiroides', 110.00, 165.00),
    ('Neurologia', 'Sistema nervioso', 120.00, 180.00),
    ('Psiquiatria', 'Salud mental', 110.00, 165.00),
    ('Dermatologia', 'Enfermedades de la piel', 90.00, 135.00),
    ('Oftalmologia', 'Ojos y vision', 95.00, 142.50),
    ('Otorrinolaringologia', 'Oido, nariz y garganta', 95.00, 142.50),
    ('Oncologia', 'Cancer', 130.00, 195.00),
    ('Hematologia', 'Enfermedades de la sangre', 110.00, 165.00),
    ('Reumatologia', 'Enfermedades autoinmunes y articulares', 105.00, 157.50),
    ('Infectologia', 'Enfermedades infecciosas', 110.00, 165.00),
    ('Geriatria', 'Medicina del adulto mayor', 100.00, 150.00),
    ('Medicina Fisica y Rehabilitacion', 'Terapia y rehabilitacion', 90.00, 135.00),
    ('Nutricion', 'Asesoramiento nutricional', 80.00, 120.00),
    ('Psicologia', 'Salud mental y terapia', 80.00, 120.00);
    
    PRINT '  28 especialidades medicas creadas';
END
ELSE
BEGIN
    PRINT '  Especialidades ya existen';
END
GO

-- ==========================================
-- 8. PRODUCTOS (Solo ejemplos básicos)
-- ==========================================
PRINT 'Cargando Productos de ejemplo...';

DECLARE @MarcaGenerico INT, @MarcaNacional INT;

SELECT @MarcaGenerico = id FROM Marca WHERE Nombre = 'Generico';
SELECT @MarcaNacional = id FROM Marca WHERE Nombre = 'Nacional';

IF NOT EXISTS (SELECT 1 FROM Productos WHERE Codigo = 'EJEMPLO001')
BEGIN
    INSERT INTO Productos (Codigo, Nombre, Detalles, Precio_compra, Precio_venta, Unidad_Medida, ID_Marca, Stock_Minimo, Activo) 
    VALUES 
    ('EJEMPLO001', 'Paracetamol 500mg', 'EJEMPLO - Eliminar y agregar productos reales', 0.50, 1.00, 'Tableta', @MarcaGenerico, 100, 1),
    ('EJEMPLO002', 'Ibuprofeno 400mg', 'EJEMPLO - Eliminar y agregar productos reales', 0.80, 1.50, 'Tableta', @MarcaGenerico, 100, 1),
    ('EJEMPLO003', 'Jeringa 5ml', 'EJEMPLO - Eliminar y agregar productos reales', 0.80, 1.50, 'Unidad', @MarcaNacional, 200, 1),
    ('EJEMPLO004', 'Gasa Esteril 10x10', 'EJEMPLO - Eliminar y agregar productos reales', 2.00, 4.00, 'Unidad', @MarcaNacional, 150, 1),
    ('EJEMPLO005', 'Alcohol 70%', 'EJEMPLO - Eliminar y agregar productos reales', 5.00, 10.00, 'Litro', @MarcaNacional, 50, 1);
    
    PRINT '  5 productos de EJEMPLO creados';
    PRINT '  IMPORTANTE: Estos son solo ejemplos para pruebas';
    PRINT '  El usuario debe ELIMINARLOS y agregar sus productos reales';
END
ELSE
BEGIN
    PRINT '  Productos ya existen';
END
GO

-- ==========================================
-- 9. USUARIO ADMINISTRADOR
-- ==========================================
PRINT 'Creando Usuario Administrador...';

DECLARE @RolAdminId INT;
SELECT @RolAdminId = id FROM Roles WHERE Nombre = 'Administrador';

IF @RolAdminId IS NULL
BEGIN
    PRINT '  ERROR: Rol Administrador no encontrado';
END
ELSE
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Usuario WHERE nombre_usuario = 'admin')
    BEGIN
        INSERT INTO Usuario (Nombre, Apellido_Paterno, Apellido_Materno, nombre_usuario, contrasena, Id_Rol, Estado)
        VALUES ('Administrador', 'Sistema', 'General', 'admin', 'admin123', @RolAdminId, 1);
        
        PRINT '  Usuario ADMIN creado';
    END
    ELSE
    BEGIN
        PRINT '  Usuario ADMIN ya existe';
    END
END
GO

-- ==========================================
-- RESUMEN FINAL
-- ==========================================
PRINT '';
PRINT '============================================';
PRINT 'DATOS INICIALES CARGADOS EXITOSAMENTE';
PRINT '============================================';
PRINT '';
PRINT 'CONFIGURACION DEL SISTEMA (Produccion):';
PRINT '  - Roles: 7';
PRINT '  - Tipos de Trabajadores: 20';
PRINT '  - Tipos de Gastos: 36 (completo)';
PRINT '  - Tipos de Analisis: 80 (completo)';
PRINT '  - Tipos de Procedimientos: 51 (completo)';
PRINT '  - Especialidades Medicas: 28 (completo)';
PRINT '';
PRINT 'DATOS DE EJEMPLO (Eliminar/Modificar):';
PRINT '  - Marcas: 5 ejemplos';
PRINT '  - Productos: 5 ejemplos';
PRINT '';
PRINT 'CREDENCIALES DE ACCESO:';
PRINT '  Usuario: admin';
PRINT '  Contrasena: admin123';
PRINT '';
PRINT 'ACCIONES REQUERIDAS ANTES DE PRODUCCION:';
PRINT '  1. CAMBIAR contrasena del administrador';
PRINT '  2. ELIMINAR los 5 productos de ejemplo';
PRINT '  3. AGREGAR productos reales de la clinica';
PRINT '  4. AGREGAR marcas reales utilizadas';
PRINT '  5. REVISAR y ajustar precios de analisis';
PRINT '  6. REVISAR y ajustar precios de procedimientos';
PRINT '  7. REVISAR y ajustar precios de especialidades';
PRINT '';
PRINT '============================================';
GO
