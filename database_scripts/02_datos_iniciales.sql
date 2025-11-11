-- ============================================
-- DATOS INICIALES - Sistema Clínica María Inmaculada
-- Versión 1.0 - Actualizado
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
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES
    ('Administrador', 'Acceso completo al sistema', 1);
    PRINT '  ✓ Rol Administrador creado';
END

IF NOT EXISTS (SELECT 1 FROM Roles WHERE Nombre = 'Médico')
BEGIN
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES
    ('Médico', 'Acceso a consultas y pacientes', 1);
    PRINT '  ✓ Rol Médico creado';
END

IF NOT EXISTS (SELECT 1 FROM Roles WHERE Nombre = 'Enfermería')
BEGIN
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES
    ('Enfermería', 'Acceso a procedimientos de enfermería', 1);
    PRINT '  ✓ Rol Enfermería creado';
END

IF NOT EXISTS (SELECT 1 FROM Roles WHERE Nombre = 'Laboratorio')
BEGIN
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES
    ('Laboratorio', 'Acceso a análisis de laboratorio', 1);
    PRINT '  ✓ Rol Laboratorio creado';
END

IF NOT EXISTS (SELECT 1 FROM Roles WHERE Nombre = 'Farmacia')
BEGIN
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES
    ('Farmacia', 'Acceso a inventario y ventas', 1);
    PRINT '  ✓ Rol Farmacia creado';
END

IF NOT EXISTS (SELECT 1 FROM Roles WHERE Nombre = 'Recepción')
BEGIN
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES
    ('Recepción', 'Acceso a registro de pacientes', 1);
    PRINT '  ✓ Rol Recepción creado';
END

-- ==========================================
-- 2. TIPOS DE TRABAJADORES
-- ==========================================
PRINT 'Cargando Tipos de Trabajadores...';

IF NOT EXISTS (SELECT 1 FROM Tipo_Trabajadores WHERE Tipo = 'Médico General')
BEGIN
    INSERT INTO Tipo_Trabajadores (Tipo, area_funcional) VALUES
    ('Médico General', 'MEDICO'),
    ('Médico Especialista', 'MEDICO'),
    ('Enfermera', 'ENFERMERIA'),
    ('Técnico de Enfermería', 'ENFERMERIA'),
    ('Técnico de Laboratorio', 'LABORATORIO'),
    ('Jefe de Laboratorio', 'LABORATORIO'),
    ('Administrativo', 'ADMINISTRATIVO'),
    ('Recepcionista', 'ADMINISTRATIVO'),
    ('Farmacéutico', 'FARMACIA'),
    ('Auxiliar de Farmacia', 'FARMACIA'),
    ('Contador', 'ADMINISTRATIVO'),
    ('Director Médico', 'MEDICO');
    
    PRINT '  ✓ 12 tipos de trabajadores creados';
END

-- ==========================================
-- 3. TIPOS DE GASTOS
-- ==========================================
PRINT 'Cargando Tipos de Gastos...';

IF NOT EXISTS (SELECT 1 FROM Tipo_Gastos WHERE Nombre = 'Servicios Básicos')
BEGIN
    INSERT INTO Tipo_Gastos (Nombre) VALUES
    ('Servicios Básicos'),
    ('Agua'),
    ('Luz'),
    ('Internet'),
    ('Teléfono'),
    ('Suministros Médicos'),
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
    ('Capacitación'),
    ('Otros');
    
    PRINT '  ✓ 19 tipos de gastos creados';
END

-- ==========================================
-- 4. TIPOS DE ANÁLISIS DE LABORATORIO
-- ==========================================
PRINT 'Cargando Tipos de Análisis...';

IF NOT EXISTS (SELECT 1 FROM Tipos_Analisis WHERE Nombre = 'Hemograma Completo')
BEGIN
    INSERT INTO Tipos_Analisis (Nombre, Descripcion, Precio_Normal, Precio_Emergencia) VALUES
    ('Hemograma Completo', 'Análisis completo de sangre (Hematíes, Leucocitos, Plaquetas)', 50.00, 80.00),
    ('Química Sanguínea', 'Glucosa, urea, creatinina, ácido úrico', 40.00, 65.00),
    ('Orina Completo', 'Análisis físico, químico y microscópico de orina', 25.00, 40.00),
    ('Grupo Sanguíneo', 'Determinación de grupo ABO y factor Rh', 30.00, 45.00),
    ('Perfil Lipídico', 'Colesterol total, HDL, LDL, triglicéridos', 35.00, 55.00),
    ('Perfil Hepático', 'TGO, TGP, bilirrubina, fosfatasa alcalina', 45.00, 70.00),
    ('Perfil Renal', 'Urea, creatinina, ácido úrico', 35.00, 55.00),
    ('Perfil Tiroideo', 'TSH, T3, T4', 60.00, 90.00),
    ('Proteína C Reactiva', 'Marcador de inflamación', 30.00, 45.00),
    ('VIH', 'Detección de anticuerpos VIH', 50.00, 75.00),
    ('Hepatitis B', 'HBsAg', 40.00, 60.00),
    ('Hepatitis C', 'Anti-HCV', 40.00, 60.00),
    ('VDRL', 'Prueba de sífilis', 25.00, 40.00),
    ('Test de Embarazo', 'Determinación de hCG', 20.00, 30.00),
    ('Coprocultivo', 'Cultivo de heces', 40.00, 65.00),
    ('Urocultivo', 'Cultivo de orina', 35.00, 55.00),
    ('Hemocultivo', 'Cultivo de sangre', 60.00, 90.00),
    ('PSA', 'Antígeno prostático específico', 45.00, 70.00),
    ('Vitamina D', 'Niveles de vitamina D', 55.00, 85.00),
    ('Vitamina B12', 'Niveles de vitamina B12', 45.00, 70.00);
    
    PRINT '  ✓ 20 tipos de análisis creados';
END

-- ==========================================
-- 5. TIPOS DE PROCEDIMIENTOS (Enfermería)
-- ==========================================
PRINT 'Cargando Tipos de Procedimientos...';

IF NOT EXISTS (SELECT 1 FROM Tipos_Procedimientos WHERE Nombre = 'Inyección Intramuscular')
BEGIN
    INSERT INTO Tipos_Procedimientos (Nombre, Descripcion, Precio_Normal, Precio_Emergencia) VALUES
    ('Inyección Intramuscular', 'Aplicación de medicamento vía intramuscular', 15.00, 25.00),
    ('Inyección Endovenosa', 'Aplicación de medicamento vía endovenosa', 20.00, 35.00),
    ('Inyección Subcutánea', 'Aplicación de medicamento vía subcutánea', 15.00, 25.00),
    ('Curación Simple', 'Limpieza y vendaje de herida simple', 25.00, 40.00),
    ('Curación Compleja', 'Limpieza y vendaje de herida compleja', 40.00, 65.00),
    ('Toma de Signos Vitales', 'Presión arterial, temperatura, pulso, respiración', 10.00, 15.00),
    ('Control de Glucosa', 'Medición de glucosa capilar', 15.00, 20.00),
    ('Oximetría', 'Medición de saturación de oxígeno', 10.00, 15.00),
    ('Nebulización', 'Terapia respiratoria', 20.00, 30.00),
    ('Canalización de Vía', 'Instalación de vía endovenosa', 30.00, 45.00),
    ('Retiro de Puntos', 'Remoción de suturas', 25.00, 40.00),
    ('Colocación de Sonda Vesical', 'Cateterización vesical', 35.00, 55.00),
    ('Colocación de Sonda Nasogástrica', 'Instalación de SNG', 35.00, 55.00),
    ('Lavado Gástrico', 'Procedimiento de urgencia', 50.00, 80.00),
    ('ECG', 'Electrocardiograma', 40.00, 65.00),
    ('Vacunación', 'Aplicación de vacunas', 20.00, 30.00),
    ('Control de Peso y Talla', 'Antropometría básica', 10.00, 15.00),
    ('Aplicación de Oxígeno', 'Oxigenoterapia', 25.00, 40.00);
    
    PRINT '  ✓ 18 tipos de procedimientos creados';
END

-- ==========================================
-- 6. MARCAS PREDETERMINADAS
-- ==========================================
PRINT 'Cargando Marcas...';

IF NOT EXISTS (SELECT 1 FROM Marca WHERE Nombre = 'Genérico')
BEGIN
    INSERT INTO Marca (Nombre, Detalles) VALUES
    ('Genérico', 'Medicamentos sin marca específica'),
    ('Bayer', 'Productos farmacéuticos Bayer'),
    ('Roche', 'Laboratorio farmacéutico Roche'),
    ('Pfizer', 'Medicamentos Pfizer'),
    ('Novartis', 'Productos Novartis'),
    ('Abbott', 'Laboratorio Abbott'),
    ('GlaxoSmithKline', 'GSK productos farmacéuticos'),
    ('Sanofi', 'Medicamentos Sanofi'),
    ('Merck', 'Productos Merck'),
    ('Johnson & Johnson', 'J&J productos médicos'),
    ('Nacional', 'Productos nacionales'),
    ('Bagó', 'Laboratorio Bagó'),
    ('Roemmers', 'Laboratorio Roemmers'),
    ('Genfar', 'Laboratorio Genfar');
    
    PRINT '  ✓ 14 marcas creadas';
END

-- ==========================================
-- 7. USUARIO Y DOCTOR SISTEMA (para especialidades)
-- ==========================================
PRINT 'Creando Usuario y Doctor del Sistema...';

-- Verificar si el rol Administrador existe
DECLARE @RolAdminId INT;
SELECT @RolAdminId = Id FROM Roles WHERE Nombre = 'Administrador';

-- Crear usuario ADMIN si no existe
IF NOT EXISTS (SELECT 1 FROM Usuario WHERE Nombre = 'admin')
BEGIN
    INSERT INTO Usuario (Nombre, Apellido_Paterno, Apellido_Materno, Email, 
                        Usuario_Nombre, Contraseña, Id_Rol, Estado, Fecha_Creacion)
    VALUES ('Administrador', 'Sistema', 'General', 'admin@clinica.com',
            'admin', 'admin123', @RolAdminId, 1, GETDATE());
    
    PRINT '  ✓ Usuario ADMIN creado (Usuario: admin / Contraseña: admin123)';
END

-- Crear Doctor Sistema si no existe
IF NOT EXISTS (SELECT 1 FROM Doctores WHERE Matricula = 'SYS-001')
BEGIN
    INSERT INTO Doctores (Nombre, Apellido_Paterno, Apellido_Materno, 
                         Especialidad, Matricula, Edad) 
    VALUES ('Sistema', 'Administrador', 'General', 'Administrador', 'SYS-001', 30);
    
    PRINT '  ✓ Doctor Sistema creado';
END

-- ==========================================
-- 8. ESPECIALIDADES BÁSICAS
-- ==========================================
PRINT 'Cargando Especialidades Médicas...';

DECLARE @DoctorSistemaId INT;
SELECT @DoctorSistemaId = id FROM Doctores WHERE Matricula = 'SYS-001';

IF NOT EXISTS (SELECT 1 FROM Especialidad WHERE Nombre = 'Medicina General')
BEGIN
    INSERT INTO Especialidad (Nombre, Detalles, Precio_Normal, Precio_Emergencia, Id_Doctor) VALUES
    ('Medicina General', 'Consulta médica general', 80.00, 120.00, @DoctorSistemaId),
    ('Pediatría', 'Atención médica infantil', 90.00, 135.00, @DoctorSistemaId),
    ('Ginecología', 'Salud femenina y reproductiva', 100.00, 150.00, @DoctorSistemaId),
    ('Obstetricia', 'Control prenatal y parto', 100.00, 150.00, @DoctorSistemaId),
    ('Traumatología', 'Lesiones y fracturas óseas', 110.00, 165.00, @DoctorSistemaId),
    ('Cardiología', 'Enfermedades cardiovasculares', 120.00, 180.00, @DoctorSistemaId),
    ('Dermatología', 'Enfermedades de la piel', 90.00, 135.00, @DoctorSistemaId),
    ('Oftalmología', 'Enfermedades oculares', 95.00, 142.50, @DoctorSistemaId),
    ('Otorrinolaringología', 'Oído, nariz y garganta', 95.00, 142.50, @DoctorSistemaId),
    ('Neurología', 'Sistema nervioso', 120.00, 180.00, @DoctorSistemaId),
    ('Psiquiatría', 'Salud mental', 110.00, 165.00, @DoctorSistemaId),
    ('Urología', 'Sistema urinario', 100.00, 150.00, @DoctorSistemaId),
    ('Endocrinología', 'Sistema endocrino y hormonal', 110.00, 165.00, @DoctorSistemaId),
    ('Gastroenterología', 'Sistema digestivo', 110.00, 165.00, @DoctorSistemaId),
    ('Neumología', 'Sistema respiratorio', 110.00, 165.00, @DoctorSistemaId);
    
    PRINT '  ✓ 15 especialidades médicas creadas';
END

-- ==========================================
-- 9. CATEGORÍAS DE PRODUCTOS (Farmacia)
-- ==========================================
PRINT 'Cargando Categorías de Productos...';

IF NOT EXISTS (SELECT 1 FROM Categoria WHERE Nombre = 'Analgésicos')
BEGIN
    INSERT INTO Categoria (Nombre, Descripcion) VALUES
    ('Analgésicos', 'Medicamentos para aliviar el dolor'),
    ('Antibióticos', 'Medicamentos contra infecciones bacterianas'),
    ('Antiinflamatorios', 'Reduce inflamación'),
    ('Antipiréticos', 'Reduce la fiebre'),
    ('Antihipertensivos', 'Control de presión arterial'),
    ('Antidiabéticos', 'Control de glucosa'),
    ('Vitaminas', 'Suplementos vitamínicos'),
    ('Suero y Soluciones', 'Hidratación endovenosa'),
    ('Material de Curación', 'Vendas, gasas, apósitos'),
    ('Instrumental Médico', 'Jeringas, agujas, catéteres'),
    ('Antisépticos', 'Desinfectantes'),
    ('Antiácidos', 'Control de acidez gástrica'),
    ('Expectorantes', 'Medicamentos respiratorios'),
    ('Antihistamínicos', 'Alergias'),
    ('Otros', 'Productos varios');
    
    PRINT '  ✓ 15 categorías de productos creadas';
END

-- ==========================================
-- 10. PRODUCTOS BÁSICOS (Ejemplos)
-- ==========================================
PRINT 'Cargando Productos de Ejemplo...';

DECLARE @CategoriaAnalgesicos INT, @CategoriaMaterialCuracion INT;
DECLARE @MarcaGenerico INT, @MarcaBayer INT;

SELECT @CategoriaAnalgesicos = Id FROM Categoria WHERE Nombre = 'Analgésicos';
SELECT @CategoriaMaterialCuracion = Id FROM Categoria WHERE Nombre = 'Material de Curación';
SELECT @MarcaGenerico = id FROM Marca WHERE Nombre = 'Genérico';
SELECT @MarcaBayer = id FROM Marca WHERE Nombre = 'Bayer';

IF NOT EXISTS (SELECT 1 FROM Productos WHERE Nombre = 'Paracetamol 500mg')
BEGIN
    INSERT INTO Productos (Nombre, Precio_compra, Precio_venta, Stock_Unitario, 
                          Id_Categoria, Id_Marca, Estado) 
    VALUES 
    ('Paracetamol 500mg', 0.50, 1.00, 0, @CategoriaAnalgesicos, @MarcaGenerico, 1),
    ('Ibuprofeno 400mg', 0.80, 1.50, 0, @CategoriaAnalgesicos, @MarcaGenerico, 1),
    ('Aspirina 100mg', 0.60, 1.20, 0, @CategoriaAnalgesicos, @MarcaBayer, 1),
    ('Gasa Estéril 10x10', 2.00, 4.00, 0, @CategoriaMaterialCuracion, @MarcaGenerico, 1),
    ('Jeringa 5ml', 0.80, 1.50, 0, @CategoriaMaterialCuracion, @MarcaGenerico, 1);
    
    PRINT '  ✓ 5 productos de ejemplo creados';
END

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
PRINT '  Contraseña: admin123';
PRINT '';
PRINT 'IMPORTANTE: Cambiar la contraseña después';
PRINT 'del primer inicio de sesión';
PRINT '============================================';

GO