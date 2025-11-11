-- ============================================
-- DATOS INICIALES - Sistema Clínica María Inmaculada
-- Versión 1.0 - CORREGIDO según esquema real
-- Ejecutar DESPUÉS de 01_schema.sql
-- ============================================

USE ClinicaMariaInmaculada;
GO

PRINT '============================================';
PRINT 'INICIANDO CARGA DE DATOS INICIALES';
PRINT 'Sistema Clínica María Inmaculada v1.0';
PRINT '============================================';

-- ==========================================
-- 1. ROLES (Sistema de permisos)
-- ==========================================
PRINT 'Cargando Roles...';

IF NOT EXISTS (SELECT 1 FROM Roles WHERE Nombre = 'Administrador')
BEGIN
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES ('Administrador', 'Acceso completo al sistema', 1);
    PRINT '  Rol Administrador creado';
END

IF NOT EXISTS (SELECT 1 FROM Roles WHERE Nombre = 'Medico')
BEGIN
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES ('Medico', 'Acceso a consultas y pacientes', 1);
    PRINT '  Rol Medico creado';
END



PRINT '  2 roles creados exitosamente';
GO

-- ==========================================
-- 2. TIPOS DE TRABAJADORES
-- ==========================================
PRINT 'Cargando Tipos de Trabajadores...';

IF NOT EXISTS (SELECT 1 FROM Tipo_Trabajadores WHERE Tipo = 'Medico General')
BEGIN
    INSERT INTO Tipo_Trabajadores (Tipo, area_funcional) VALUES
    ('Medico General', 'MEDICO'),
    ('Medico Especialista', 'MEDICO'),
    ('Enfermera', 'ENFERMERIA'),
    ('Tecnico de Enfermeria', 'ENFERMERIA'),
    ('Tecnico de Laboratorio', 'LABORATORIO'),
    ('Jefe de Laboratorio', 'LABORATORIO'),
    ('Administrativo', 'ADMINISTRATIVO'),
    ('Recepcionista', 'ADMINISTRATIVO'),
    ('Farmaceutico', 'FARMACIA'),
    ('Auxiliar de Farmacia', 'FARMACIA'),
    ('Contador', 'ADMINISTRATIVO'),
    ('Director Medico', 'MEDICO');
    
    PRINT '  12 tipos de trabajadores creados';
END
GO

-- ==========================================
-- 3. TIPOS DE GASTOS
-- ==========================================
PRINT 'Cargando Tipos de Gastos...';

IF NOT EXISTS (SELECT 1 FROM Tipo_Gastos WHERE Nombre = 'Servicios Basicos')
BEGIN
    INSERT INTO Tipo_Gastos (Nombre) VALUES
    ('Servicios Basicos'),
    ('Agua'),
    ('Luz'),
    ('Internet'),
    ('Telefono'),
    ('Suministros Medicos'),
    ('Material de Laboratorio'),
    ('Medicamentos'),
    ('Mantenimiento'),
    ('Reparaciones'),
    ('Equipamiento'),
    ('Salarios'),
    ('Honorarios'),
    ('Impuestos'),
    ('Alquiler'),
    ('Seguros'),
    ('Publicidad'),
    ('Capacitacion'),
    ('Otros');
    
    PRINT '  19 tipos de gastos creados';
END
GO

-- ==========================================
-- 4. TIPOS DE ANÁLISIS DE LABORATORIO
-- ==========================================
PRINT 'Cargando Tipos de Analisis...';

IF NOT EXISTS (SELECT 1 FROM Tipos_Analisis WHERE Nombre = 'Hemograma Completo')
BEGIN
    INSERT INTO Tipos_Analisis (Nombre, Descripcion, Precio_Normal, Precio_Emergencia) VALUES
    ('Hemograma Completo', 'Analisis completo de sangre (Hematies, Leucocitos, Plaquetas)', 50.00, 80.00),
    ('Quimica Sanguinea', 'Glucosa, urea, creatinina, acido urico', 40.00, 65.00),
    ('Orina Completo', 'Analisis fisico, quimico y microscopico de orina', 25.00, 40.00),
    ('Grupo Sanguineo', 'Determinacion de grupo ABO y factor Rh', 30.00, 45.00),
    ('Perfil Lipidico', 'Colesterol total, HDL, LDL, trigliceridos', 35.00, 55.00),
    ('Perfil Hepatico', 'TGO, TGP, bilirrubina, fosfatasa alcalina', 45.00, 70.00),
    ('Perfil Renal', 'Urea, creatinina, acido urico', 35.00, 55.00),
    ('Perfil Tiroideo', 'TSH, T3, T4', 60.00, 90.00),
    ('Proteina C Reactiva', 'Marcador de inflamacion', 30.00, 45.00),
    ('VIH', 'Deteccion de anticuerpos VIH', 50.00, 75.00),
    ('Hepatitis B', 'HBsAg', 40.00, 60.00),
    ('Hepatitis C', 'Anti-HCV', 40.00, 60.00),
    ('VDRL', 'Prueba de sifilis', 25.00, 40.00),
    ('Test de Embarazo', 'Determinacion de hCG', 20.00, 30.00),
    ('Coprocultivo', 'Cultivo de heces', 40.00, 65.00),
    ('Urocultivo', 'Cultivo de orina', 35.00, 55.00),
    ('Hemocultivo', 'Cultivo de sangre', 60.00, 90.00),
    ('PSA', 'Antigeno prostatico especifico', 45.00, 70.00),
    ('Vitamina D', 'Niveles de vitamina D', 55.00, 85.00),
    ('Vitamina B12', 'Niveles de vitamina B12', 45.00, 70.00);
    
    PRINT '  20 tipos de analisis creados';
END
GO

-- ==========================================
-- 5. TIPOS DE PROCEDIMIENTOS (Enfermería)
-- ==========================================
PRINT 'Cargando Tipos de Procedimientos...';

IF NOT EXISTS (SELECT 1 FROM Tipos_Procedimientos WHERE Nombre = 'Inyeccion Intramuscular')
BEGIN
    INSERT INTO Tipos_Procedimientos (Nombre, Descripcion, Precio_Normal, Precio_Emergencia) VALUES
    ('Inyeccion Intramuscular', 'Aplicacion de medicamento via intramuscular', 15.00, 25.00),
    ('Inyeccion Endovenosa', 'Aplicacion de medicamento via endovenosa', 20.00, 35.00),
    ('Inyeccion Subcutanea', 'Aplicacion de medicamento via subcutanea', 15.00, 25.00),
    ('Curacion Simple', 'Limpieza y vendaje de herida simple', 25.00, 40.00),
    ('Curacion Compleja', 'Limpieza y vendaje de herida compleja', 40.00, 65.00),
    ('Toma de Signos Vitales', 'Presion arterial, temperatura, pulso, respiracion', 10.00, 15.00),
    ('Control de Glucosa', 'Medicion de glucosa capilar', 15.00, 20.00),
    ('Oximetria', 'Medicion de saturacion de oxigeno', 10.00, 15.00),
    ('Nebulizacion', 'Terapia respiratoria', 20.00, 30.00),
    ('Canalizacion de Via', 'Instalacion de via endovenosa', 30.00, 45.00),
    ('Retiro de Puntos', 'Remocion de suturas', 25.00, 40.00),
    ('Colocacion de Sonda Vesical', 'Cateterizacion vesical', 35.00, 55.00),
    ('Colocacion de Sonda Nasogastrica', 'Instalacion de SNG', 35.00, 55.00),
    ('Lavado Gastrico', 'Procedimiento de urgencia', 50.00, 80.00),
    ('ECG', 'Electrocardiograma', 40.00, 65.00),
    ('Vacunacion', 'Aplicacion de vacunas', 20.00, 30.00),
    ('Control de Peso y Talla', 'Antropometria basica', 10.00, 15.00),
    ('Aplicacion de Oxigeno', 'Oxigenoterapia', 25.00, 40.00);
    
    PRINT '  18 tipos de procedimientos creados';
END
GO

-- ==========================================
-- 6. MARCAS PREDETERMINADAS
-- ==========================================
PRINT 'Cargando Marcas...';

IF NOT EXISTS (SELECT 1 FROM Marca WHERE Nombre = 'Generico')
BEGIN
    INSERT INTO Marca (Nombre, Detalles) VALUES
    ('Generico', 'Medicamentos sin marca especifica'),
    ('Bayer', 'Productos farmaceuticos Bayer'),
    ('Roche', 'Laboratorio farmaceutico Roche'),
    ('Pfizer', 'Medicamentos Pfizer'),
    ('Novartis', 'Productos Novartis'),
    ('Abbott', 'Laboratorio Abbott'),
    ('GlaxoSmithKline', 'GSK productos farmaceuticos'),
    ('Sanofi', 'Medicamentos Sanofi'),
    ('Merck', 'Productos Merck'),
    ('Johnson & Johnson', 'J&J productos medicos'),
    ('Nacional', 'Productos nacionales'),
    ('Bago', 'Laboratorio Bago'),
    ('Roemmers', 'Laboratorio Roemmers'),
    ('Genfar', 'Laboratorio Genfar');
    
    PRINT '  14 marcas creadas';
END
GO

-- ==========================================
-- 7. ESPECIALIDADES BÁSICAS (SIN Id_Doctor)
-- ==========================================
PRINT 'Cargando Especialidades Medicas...';

IF NOT EXISTS (SELECT 1 FROM Especialidad WHERE Nombre = 'Medicina General')
BEGIN
    INSERT INTO Especialidad (Nombre, Detalles, Precio_Normal, Precio_Emergencia) VALUES
    ('Medicina General', 'Consulta medica general', 80.00, 120.00),
    ('Pediatria', 'Atencion medica infantil', 90.00, 135.00),
    ('Ginecologia', 'Salud femenina y reproductiva', 100.00, 150.00),
    ('Obstetricia', 'Control prenatal y parto', 100.00, 150.00),
    ('Traumatologia', 'Lesiones y fracturas oseas', 110.00, 165.00),
    ('Cardiologia', 'Enfermedades cardiovasculares', 120.00, 180.00),
    ('Dermatologia', 'Enfermedades de la piel', 90.00, 135.00),
    ('Oftalmologia', 'Enfermedades oculares', 95.00, 142.50),
    ('Otorrinolaringologia', 'Oido, nariz y garganta', 95.00, 142.50),
    ('Neurologia', 'Sistema nervioso', 120.00, 180.00),
    ('Psiquiatria', 'Salud mental', 110.00, 165.00),
    ('Urologia', 'Sistema urinario', 100.00, 150.00),
    ('Endocrinologia', 'Sistema endocrino y hormonal', 110.00, 165.00),
    ('Gastroenterologia', 'Sistema digestivo', 110.00, 165.00),
    ('Neumologia', 'Sistema respiratorio', 110.00, 165.00);
    
    PRINT '  15 especialidades medicas creadas';
END
GO

-- ==========================================
-- 8. PRODUCTOS BÁSICOS (SIN Id_Categoria)
-- ==========================================
PRINT 'Cargando Productos de Ejemplo...';

DECLARE @MarcaGenerico INT, @MarcaBayer INT;

SELECT @MarcaGenerico = id FROM Marca WHERE Nombre = 'Generico';
SELECT @MarcaBayer = id FROM Marca WHERE Nombre = 'Bayer';

IF NOT EXISTS (SELECT 1 FROM Productos WHERE Codigo = 'MED001')
BEGIN
    INSERT INTO Productos (Codigo, Nombre, Detalles, Precio_compra, Precio_venta, Stock_Unitario, Unidad_Medida, ID_Marca) 
    VALUES 
    ('MED001', 'Paracetamol 500mg', 'Analgesico y antipiretico', 0.50, 1.00, 0, 'Tableta', @MarcaGenerico),
    ('MED002', 'Ibuprofeno 400mg', 'Antiinflamatorio', 0.80, 1.50, 0, 'Tableta', @MarcaGenerico),
    ('MED003', 'Aspirina 100mg', 'Analgesico', 0.60, 1.20, 0, 'Tableta', @MarcaBayer),
    ('MAT001', 'Gasa Esteril 10x10', 'Material de curacion', 2.00, 4.00, 0, 'Unidad', @MarcaGenerico),
    ('MAT002', 'Jeringa 5ml', 'Descartable', 0.80, 1.50, 0, 'Unidad', @MarcaGenerico);
    
    PRINT '  5 productos de ejemplo creados';
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
        
        PRINT '  Usuario ADMIN creado (Usuario: admin / Contrasena: admin123)';
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
PRINT 'CREDENCIALES DE ACCESO INICIAL:';
PRINT '  Usuario: admin';
PRINT '  Contrasena: admin123';
PRINT '';
PRINT 'IMPORTANTE: Cambiar la contrasena despues';
PRINT 'del primer inicio de sesion';
PRINT '============================================';
GO