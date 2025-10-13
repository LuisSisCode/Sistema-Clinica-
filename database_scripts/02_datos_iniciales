-- ============================================
-- DATOS INICIALES - Sistema Clínica
-- Ejecutar DESPUÉS de 01_schema.sql
-- ============================================

USE ClinicaMariaInmaculada;
GO

-- ==========================================
-- 1. ROLES (Sistema de permisos)
-- ==========================================
IF NOT EXISTS (SELECT 1 FROM Roles WHERE Nombre = 'Administrador')
BEGIN
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES
    ('Administrador', 'Acceso completo al sistema', 1);
END

IF NOT EXISTS (SELECT 1 FROM Roles WHERE Nombre = 'Médico')
BEGIN
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES
    ('Médico', 'Acceso a consultas y pacientes', 1);
END

-- ==========================================
-- 2. TIPOS DE TRABAJADORES
-- ==========================================
IF NOT EXISTS (SELECT 1 FROM Tipo_Trabajadores WHERE Tipo = 'Médico General')
BEGIN
    INSERT INTO Tipo_Trabajadores (Tipo) VALUES
    ('Médico General'),
    ('Médico Especialista'),
    ('Enfermera'),
    ('Técnico de Laboratorio'),
    ('Administrativo'),
    ('Farmacéutico');
END

-- ==========================================
-- 3. TIPOS DE GASTOS
-- ==========================================
IF NOT EXISTS (SELECT 1 FROM Tipo_Gastos WHERE Nombre = 'Servicios Básicos')
BEGIN
    INSERT INTO Tipo_Gastos (Nombre) VALUES
    ('Servicios Básicos'),
    ('Suministros Médicos'),
    ('Mantenimiento'),
    ('Salarios'),
    ('Impuestos'),
    ('Otros');
END

-- ==========================================
-- 4. TIPOS DE ANÁLISIS DE LABORATORIO
-- ==========================================
IF NOT EXISTS (SELECT 1 FROM Tipos_Analisis WHERE Nombre = 'Hemograma Completo')
BEGIN
    INSERT INTO Tipos_Analisis (Nombre, Descripcion, Precio_Normal, Precio_Emergencia) VALUES
    ('Hemograma Completo', 'Análisis completo de sangre', 50.00, 80.00),
    ('Química Sanguínea', 'Glucosa, urea, creatinina', 40.00, 65.00),
    ('Orina Completo', 'Análisis completo de orina', 25.00, 40.00),
    ('Grupo Sanguíneo', 'Determinación de grupo y factor Rh', 30.00, 45.00),
    ('Perfil Lipídico', 'Colesterol, triglicéridos', 35.00, 55.00);
END

-- ==========================================
-- 5. TIPOS DE PROCEDIMIENTOS (Enfermería)
-- ==========================================
IF NOT EXISTS (SELECT 1 FROM Tipos_Procedimientos WHERE Nombre = 'Inyección Intramuscular')
BEGIN
    INSERT INTO Tipos_Procedimientos (Nombre, Descripcion, Precio_Normal, Precio_Emergencia) VALUES
    ('Inyección Intramuscular', 'Aplicación de medicamento IM', 15.00, 25.00),
    ('Inyección Endovenosa', 'Aplicación de medicamento EV', 20.00, 35.00),
    ('Curación Simple', 'Limpieza y vendaje', 25.00, 40.00),
    ('Toma de Signos Vitales', 'Presión, temperatura, pulso', 10.00, 15.00),
    ('Control de Glucosa', 'Medición de glucosa capilar', 15.00, 20.00);
END

-- ==========================================
-- 6. MARCAS PREDETERMINADAS
-- ==========================================
IF NOT EXISTS (SELECT 1 FROM Marca WHERE Nombre = 'Genérico')
BEGIN
    INSERT INTO Marca (Nombre, Detalles) VALUES
    ('Genérico', 'Medicamentos sin marca'),
    ('Bayer', 'Productos farmacéuticos'),
    ('Roche', 'Laboratorio farmacéutico'),
    ('Pfizer', 'Medicamentos varios');
END

-- ==========================================
-- 7. DOCTOR SISTEMA (para especialidades)
-- ==========================================
IF NOT EXISTS (SELECT 1 FROM Doctores WHERE Matricula = 'SYS-001')
BEGIN
    INSERT INTO Doctores (Nombre, Apellido_Paterno, Apellido_Materno, Especialidad, Matricula, Edad) 
    VALUES ('Sistema', 'Administrador', 'General', 'Administrador', 'SYS-001', 30);
END

-- ==========================================
-- 8. ESPECIALIDADES BÁSICAS
-- ==========================================
DECLARE @DoctorSistemaId INT;
SELECT @DoctorSistemaId = id FROM Doctores WHERE Matricula = 'SYS-001';

IF NOT EXISTS (SELECT 1 FROM Especialidad WHERE Nombre = 'Medicina General')
BEGIN
    INSERT INTO Especialidad (Nombre, Detalles, Precio_Normal, Precio_Emergencia, Id_Doctor) VALUES
    ('Medicina General', 'Consulta general', 80.00, 120.00, @DoctorSistemaId),
    ('Pediatría', 'Atención infantil', 90.00, 135.00, @DoctorSistemaId),
    ('Ginecología', 'Salud femenina', 100.00, 150.00, @DoctorSistemaId),
    ('Traumatología', 'Lesiones y fracturas', 110.00, 165.00, @DoctorSistemaId),
    ('Cardiología', 'Enfermedades del corazón', 120.00, 180.00, @DoctorSistemaId);
END

PRINT 'Datos iniciales cargados exitosamente';
GO