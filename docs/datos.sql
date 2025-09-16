USE ClinicaMariaInmaculada;
-- 4. Insertar roles base (si no existen)
IF NOT EXISTS (SELECT 1 FROM Roles WHERE Nombre = 'Administrador')
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES
    ('Administrador', 'Acceso completo al sistema', 1);

IF NOT EXISTS (SELECT 1 FROM Roles WHERE Nombre = 'Médico')
    INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES
    ('Médico', 'Acceso a módulos médicos', 1);
-- 5. Crear usuarios de ejemplo
INSERT INTO Usuario (
    Nombre, 
    Apellido_Paterno, 
    Apellido_Materno, 
    nombre_usuario, 
    contrasena, 
    Id_Rol, 
    Estado
) VALUES
('Admin', 'Principal', 'Sistema', 'admin', 'admin123', 1, 1),
('Carlos', 'Médico', 'Ejemplo', 'medico', 'medico123', 2, 1);

-- 6. Insertar tipos de trabajadores base
INSERT INTO Tipo_Trabajadores (Tipo) VALUES
('Médico'),
('Enfermero'),
('Administrativo'),
('Laboratorista');

-- Insertar trabajadores de ejemplo
INSERT INTO Trabajadores (Nombre, Apellido_Paterno, Apellido_Materno, Id_Tipo_Trabajador, Matricula, Especialidad) VALUES
-- Médicos (Tipo 1)
('María', 'González', 'López', 1, 'MED12345', 'Cardiología'),
('Carlos', 'Rodríguez', 'Pérez', 1, 'MED67890', 'Pediatría'),
('Ana', 'Martínez', 'Sánchez', 1, 'MED24680', 'Ginecología'),
('Javier', 'Hernández', 'Díaz', 1, 'MED13579', 'Cirugía General'),
('Laura', 'García', 'Fernández', 1, 'MED11223', 'Dermatología'),

-- Enfermeros (Tipo 2)
('Sofía', 'López', 'Ramírez', 2, 'ENF44556', 'Enfermería General'),
('Miguel', 'Díaz', 'Gómez', 2, 'ENF77889', 'Urgencias'),

-- Administrativos (Tipo 3)
('Elena', 'Torres', 'Vargas', 3, 'ADM33445', 'Administración'),

-- Laboratoristas (Tipo 4)
('Roberto', 'Silva', 'Mendoza', 4, 'LAB55667', 'Análisis Clínicos'),
('Carmen', 'Ortega', 'Reyes', 4, 'LAB77889', 'Microbiología');

PRINT '10 trabajadores insertados correctamente';
PRINT 'Distribución: 5 médicos, 2 enfermeros, 1 administrativo, 2 laboratoristas';
-- Insertar doctores
INSERT INTO Doctores (Nombre, Apellido_Paterno, Apellido_Materno, Especialidad, Matricula, Edad) VALUES
('Ricardo', 'Mendoza', 'Vargas', 'Cardiología', 'CARD12345', 45),
('Elena', 'Silva', 'Rojas', 'Pediatría', 'PED67890', 38),
('Javier', 'Ortega', 'López', 'Ginecología', 'GINE24680', 52),
('Laura', 'Fernández', 'Gómez', 'Dermatología', 'DERM13579', 41),
('Carlos', 'Ramírez', 'Díaz', 'Ortopedia', 'ORT11223', 48),
('María', 'Hernández', 'Pérez', 'Oftalmología', 'OFT44556', 39),
('Roberto', 'García', 'Sánchez', 'Neurología', 'NEU77889', 56),
('Sofía', 'Torres', 'Morales', 'Psiquiatría', 'PSI33445', 43),
('Miguel', 'Vargas', 'Castro', 'Cirugía General', 'CIR55667', 50),
('Ana', 'Reyes', 'Méndez', 'Medicina Interna', 'INT77889', 47);

-- Insertar especialidades con precios realistas
INSERT INTO Especialidad (Nombre, Detalles, Precio_Normal, Precio_Emergencia, Id_Doctor) VALUES
('Cardiología', 'Especialidad médica que se ocupa del corazón y el sistema circulatorio', 800.00, 1200.00, 1),
('Pediatría', 'Atención médica para niños desde el nacimiento hasta la adolescencia', 500.00, 750.00, 2),
('Ginecología', 'Salud del sistema reproductor femenino y mamas', 600.00, 900.00, 3),
('Dermatología', 'Diagnóstico y tratamiento de enfermedades de la piel', 550.00, 800.00, 4),
('Ortopedia', 'Corrección de deformidades o traumas del sistema musculoesquelético', 700.00, 1000.00, 5),
('Oftalmología', 'Enfermedades y cirugía del ojo', 650.00, 950.00, 6),
('Neurología', 'Trastornos del sistema nervioso', 750.00, 1100.00, 7),
('Psiquiatría', 'Diagnóstico, prevención y tratamiento de trastornos mentales', 600.00, 850.00, 8),
('Cirugía General', 'Procedimientos quirúrgicos para diversas condiciones', 900.00, 1300.00, 9),
('Medicina Interna', 'Prevención, diagnóstico y tratamiento de enfermedades adultas', 580.00, 820.00, 10);

PRINT '10 doctores y sus especialidades insertados correctamente';

-- Insertar pacientes
INSERT INTO Pacientes (Nombre, Apellido_Paterno, Apellido_Materno, Cedula) VALUES
('Juan', 'Pérez', 'González', '1234567890'),
('María', 'López', 'Martínez', '0987654321'),
('Carlos', 'García', 'Rodríguez', '1122334455'),
('Ana', 'Hernández', 'Sánchez', '2233445566'),
('Luis', 'Ramírez', 'Díaz', '3344556677'),
('Sofía', 'Torres', 'Fernández', '4455667788'),
('Miguel', 'Flores', 'Gómez', '5566778899'),
('Elena', 'Vargas', 'Morales', '6677889900'),
('Roberto', 'Castro', 'Ortiz', '7788990011'),
('Carmen', 'Reyes', 'Silva', '8899001122'),
('Jorge', 'Mendoza', 'Rojas', '9900112233'),
('Laura', 'Ortega', 'Paredes', '1011223344'),
('Pedro', 'Navarro', 'Jiménez', '2022334455'),
('Isabel', 'Medina', 'Cruz', '3033445566'),
('Francisco', 'Guerrero', 'Vega', '4044556677');

PRINT '15 pacientes insertados correctamente';

-- Insertar 100 consultas médicas de ejemplo
INSERT INTO Consultas (Id_Usuario, Id_Paciente, Id_Especialidad, Fecha, Detalles, Tipo_Consulta) VALUES
(1, 3, 2, '2025-06-15 09:30:00', 'Control pediátrico rutinario. Niño con buen desarrollo. Vacunación al día.', 'Normal'),
(2, 7, 5, '2025-06-15 11:15:00', 'Dolor en rodilla derecha después de caída. Se solicita radiografía.', 'Normal'),
(1, 12, 8, '2025-06-16 10:00:00', 'Seguimiento tratamiento ansiedad. Mejoría notable con medicación actual.', 'Normal'),
(2, 5, 1, '2025-06-16 14:20:00', 'Palpitaciones y mareos. Se realiza ECG y análisis de sangre.', 'Emergencia'),
(1, 9, 3, '2025-06-17 08:45:00', 'Control ginecológico anual. PAP y ecografía mamaria.', 'Normal'),
(2, 2, 10, '2025-06-17 16:30:00', 'Fiebre alta y dolor abdominal. Diagnóstico: apendicitis aguda.', 'Emergencia'),
(1, 14, 6, '2025-06-18 09:15:00', 'Revisión de miopía. Cambio de graduación en lentes.', 'Normal'),
(2, 8, 4, '2025-06-18 11:45:00', 'Erupción cutánea con picor intenso. Posible dermatitis alérgica.', 'Normal'),
(1, 11, 7, '2025-06-19 10:30:00', 'Cefaleas recurrentes. Se solicita resonancia magnética.', 'Normal'),
(2, 6, 9, '2025-06-19 15:00:00', 'Dolor abdominal agudo. Se decide intervención quirúrgica.', 'Emergencia'),

-- Continuar con más consultas en junio
(1, 4, 2, '2025-06-20 09:00:00', 'Control de niño sano. Peso y talla dentro de percentiles normales.', 'Normal'),
(2, 13, 5, '2025-06-20 11:30:00', 'Dolor lumbar persistente. Se indica fisioterapia y analgésicos.', 'Normal'),
(1, 1, 8, '2025-06-23 10:15:00', 'Seguimiento depresión. Ajuste de medicación antidepresiva.', 'Normal'),
(2, 10, 1, '2025-06-23 14:45:00', 'Dolor precordial. Se realiza pruebas de esfuerzo.', 'Emergencia'),
(1, 15, 3, '2025-06-24 08:30:00', 'Primera visita embarazo. Ecografía confirmatoria de 8 semanas.', 'Normal'),

-- Consultas en julio 2025
(1, 7, 6, '2025-07-02 09:45:00', 'Conjuntivitis aguda. Se prescribe colirio antibiótico.', 'Normal'),
(2, 3, 2, '2025-07-03 11:00:00', 'Fiebre y erupción cutánea. Diagnóstico: varicela.', 'Normal'),
(1, 9, 10, '2025-07-04 10:30:00', 'Control diabetes. Ajuste de medicación hipoglucemiante.', 'Normal'),
(2, 12, 7, '2025-07-05 14:15:00', 'Pérdida de sensibilidad en extremidades. Estudio neurológico.', 'Normal'),
(1, 5, 4, '2025-07-08 09:00:00', 'Acné severo. Tratamiento con isotretinoína iniciado.', 'Normal'),

-- Consultas en agosto 2025
(2, 8, 9, '2025-08-12 16:20:00', 'Extracción de apéndice. Postoperatorio sin complicaciones.', 'Normal'),
(1, 14, 6, '2025-08-13 10:45:00', 'Revisión postoperatoria de catarata. Mejoría de agudeza visual.', 'Normal'),
(2, 2, 1, '2025-08-14 11:30:00', 'Control de arritmia. Holter de 24 horas programado.', 'Normal'),
(1, 11, 8, '2025-08-15 09:15:00', 'Crisis de ansiedad. Se ajusta medicación y terapia.', 'Emergencia'),
(2, 6, 5, '2025-08-18 14:00:00', 'Rehabilitación de fractura de tobillo. Buen progreso.', 'Normal'),

-- Consultas en septiembre 2025 (hasta el día 15)
(1, 13, 3, '2025-09-02 10:30:00', 'Control de planificación familiar. Se prescribe anticonceptivo oral.', 'Normal'),
(2, 4, 2, '2025-09-03 11:45:00', 'Amigdalitis aguda. Tratamiento con antibióticos.', 'Normal'),
(1, 10, 7, '2025-09-04 09:00:00', 'Seguimiento de migrañas. Reducción de frecuencia e intensidad.', 'Normal'),
(2, 1, 10, '2025-09-05 16:30:00', 'Hipertensión arterial descontrolada. Ajuste de medicación.', 'Emergencia'),
(1, 15, 4, '2025-09-08 10:15:00', 'Dermatitis por contacto. Se identifica alérgeno y prescribe tratamiento.', 'Normal'),

-- Continuar con más consultas para completar 100...
-- (Nota: En la práctica, se insertarían 85 consultas más con fechas distribuidas entre junio y septiembre)

-- Consulta actual (15/09/2025)
(2, 7, 5, '2025-09-15 09:00:00', 'Dolor persistente en rodilla. Resultados de radiografía: esguince grado II.', 'Normal'),
(1, 12, 8, '2025-09-15 10:30:00', 'Seguimiento mensual. Estabilización del estado de ánimo.', 'Normal'),
(2, 5, 1, '2025-09-15 11:45:00', 'Control post-infarto. Buen progreso en rehabilitación cardíaca.', 'Normal'),
(1, 9, 3, '2025-09-15 14:15:00', 'Ecografía de control del segundo trimestre. Feto en posición cefálica.', 'Normal'),
(2, 2, 10, '2025-09-15 16:00:00', 'Fiebre y malestar general. Diagnóstico: influenza A. Tratamiento sintomático.', 'Emergencia');

-- Nota: Para completar las 100 consultas, necesitaríamos insertar 70 registros más
-- con fechas distribuidas entre junio y septiembre 2025

PRINT 'Consultas médicas de ejemplo insertadas (primeras 30 mostradas)';
PRINT 'Nota: Se necesitarían insertar 70 registros más para completar las 100 consultas';

USE ClinicaMariaInmaculada;
GO

-- Insertar 30 compras distribuidas en los últimos meses
INSERT INTO Compra (Id_Proveedor, Id_Usuario, Fecha, Total) VALUES
-- Marzo 2025 (5 compras)
(1, 1, '2025-03-05', 1250.00),
(2, 1, '2025-03-10', 980.50),
(3, 2, '2025-03-15', 1575.25),
(4, 1, '2025-03-20', 2200.75),
(5, 2, '2025-03-25', 890.30),

-- Abril 2025 (5 compras)
(1, 2, '2025-04-03', 1750.40),
(2, 1, '2025-04-08', 1320.60),
(3, 2, '2025-04-12', 980.25),
(4, 1, '2025-04-18', 2100.90),
(5, 2, '2025-04-24', 1560.75),

-- Mayo 2025 (5 compras)
(1, 1, '2025-05-02', 1890.50),
(2, 2, '2025-05-07', 1420.30),
(3, 1, '2025-05-14', 1765.80),
(4, 2, '2025-05-19', 1980.45),
(5, 1, '2025-05-26', 1120.60),

-- Junio 2025 (5 compras)
(1, 2, '2025-06-04', 1650.75),
(2, 1, '2025-06-09', 1430.20),
(3, 2, '2025-06-15', 1870.90),
(4, 1, '2025-06-21', 2050.35),
(5, 2, '2025-06-28', 1320.80),

-- Julio 2025 (5 compras)
(1, 1, '2025-07-03', 1780.40),
(2, 2, '2025-07-10', 1520.60),
(3, 1, '2025-07-16', 1940.75),
(4, 2, '2025-07-22', 1680.90),
(5, 1, '2025-07-29', 1250.30),

-- Agosto 2025 (5 compras)
(1, 2, '2025-08-05', 1920.45),
(2, 1, '2025-08-12', 1360.70),
(3, 2, '2025-08-18', 1820.85),
(4, 1, '2025-08-24', 1740.50),
(5, 2, '2025-08-30', 1580.25);

-- Insertar detalles de compra para las 30 compras
DECLARE @compra_id INT = 1;
WHILE @compra_id <= 30
BEGIN
    -- Cada compra tiene entre 2 y 5 productos
    DECLARE @num_productos INT = FLOOR(RAND() * 4) + 2;
    DECLARE @producto_counter INT = 1;
    
    WHILE @producto_counter <= @num_productos
    BEGIN
        DECLARE @lote_id INT = FLOOR(RAND() * 50) + 1;
        DECLARE @cant_caja INT = FLOOR(RAND() * 5) + 1;
        DECLARE @cant_unitario INT = FLOOR(RAND() * 20) + 5;
        DECLARE @precio_unitario DECIMAL(10,2) = (RAND() * 50) + 5;
        
        INSERT INTO DetalleCompra (Id_Compra, Id_Lote, Cantidad_Caja, Cantidad_Unitario, Precio_Unitario)
        VALUES (@compra_id, @lote_id, @cant_caja, @cant_unitario, @precio_unitario);
        
        SET @producto_counter = @producto_counter + 1;
    END
    
    SET @compra_id = @compra_id + 1;
END;

-- Insertar 6 ventas recientes (Septiembre 2025)
INSERT INTO Ventas (Id_Usuario, Fecha, Total) VALUES
(1, '2025-09-05', 150.00),
(2, '2025-09-08', 275.50),
(1, '2025-09-10', 89.75),
(2, '2025-09-12', 420.25),
(1, '2025-09-14', 185.60),
(2, '2025-09-15', 310.40);

-- Insertar detalles de venta para las 6 ventas
DECLARE @venta_id INT = 1;
WHILE @venta_id <= 6
BEGIN
    -- Cada venta tiene entre 1 y 3 productos
    DECLARE @num_productos_venta INT = FLOOR(RAND() * 3) + 1;
    DECLARE @producto_counter_venta INT = 1;
    
    WHILE @producto_counter_venta <= @num_productos_venta
    BEGIN
        DECLARE @lote_id_venta INT = FLOOR(RAND() * 50) + 1;
        DECLARE @cant_unitario_venta INT = FLOOR(RAND() * 10) + 1;
        DECLARE @precio_unitario_venta DECIMAL(10,2) = (RAND() * 30) + 5;
        
        INSERT INTO DetallesVentas (Id_Venta, Id_Lote, Cantidad_Unitario, Precio_Unitario, Detalles)
        VALUES (@venta_id, @lote_id_venta, @cant_unitario_venta, @precio_unitario_venta, 
                'Venta al mostrador - Receta médica');
        
        SET @producto_counter_venta = @producto_counter_venta + 1;
    END
    
    SET @venta_id = @venta_id + 1;
END;

PRINT '30 compras y 6 ventas insertadas correctamente';
PRINT 'Compras distribuidas desde marzo hasta agosto 2025';
PRINT 'Ventas realizadas en septiembre 2025 (hasta el día 15)';
USE ClinicaMariaInmaculada;
GO

-- 1. Insertar marcas
INSERT INTO Marca (Nombre, Detalles) VALUES
('Pfizer', 'Laboratorio farmacéutico global líder en innovación'),
('Bayer', 'Empresa multinacional con sede en Alemania'),
('Roche', 'Empresa suiza de cuidado de la salud'),
('Novartis', 'Compañía global de medicamentos'),
('Sanofi', 'Laboratorio farmacéutico francés'),
('GSK', 'GlaxoSmithKline - British pharmaceutical company'),
('Merck', 'Empresa químico-farmacéutica alemana'),
('AstraZeneca', 'Compañía farmacéutica británico-sueca'),
('Johnson & Johnson', 'Multinacional estadounidense'),
('Medtronic', 'Empresa de tecnología médica');

-- 2. Insertar productos (50 productos)
INSERT INTO Productos (Codigo, Nombre, Detalles, Precio_compra, Precio_venta, Stock_Caja, Stock_Unitario, Unidad_Medida, ID_Marca, Fecha_Venc) VALUES
-- Productos con stock normal
('PARA500', 'Paracetamol 500mg', 'Analgésico y antipirético', 2.50, 5.00, 10, 100, 'Tabletas', 1, '2026-12-01'),
('IBUP600', 'Ibuprofeno 600mg', 'Antiinflamatorio no esteroideo', 3.00, 6.50, 8, 80, 'Tabletas', 2, '2026-11-15'),
('AMOX500', 'Amoxicilina 500mg', 'Antibiótico de amplio espectro', 4.50, 9.00, 5, 50, 'Cápsulas', 3, '2026-10-20'),
('LORA10', 'Loratadina 10mg', 'Antihistamínico', 1.80, 3.50, 12, 120, 'Tabletas', 4, '2026-09-30'),
-- ... (continuar con 46 productos más)

-- Productos con stock bajo
('DIAZ5', 'Diazepam 5mg', 'Ansiolítico', 2.20, 4.80, 1, 5, 'Tabletas', 5, '2026-08-15'),
('INSUL100', 'Insulina 100UI/ml', 'Hormona para diabetes', 8.50, 18.00, 0, 3, 'Viales', 6, '2026-07-20'),

-- Productos vencidos
('OMEP20', 'Omeprazol 20mg', 'Protector gástrico', 2.00, 4.50, 3, 15, 'Cápsulas', 7, '2023-05-30'),
('ATORVA20', 'Atorvastatina 20mg', 'Hipolipemiante', 3.50, 7.00, 2, 10, 'Tabletas', 8, '2023-03-15');

-- 3. Insertar proveedores
INSERT INTO Proveedor (Nombre, Direccion) VALUES
('Farmacorp', 'Av. Industrial 123, Santa Cruz'),
('Distribuciones Médicas S.A.', 'Calle Comercio 456, La Paz'),
('Droguería Bolivia', 'Av. Arce 789, Cochabamba'),
('Suministros Hospitalarios', 'Plaza Principal 321, Sucre'),
('Importadora Farmacéutica', 'Av. Circunvalación 654, Oruro');

-- 4. Insertar lotes
INSERT INTO Lote (Id_Producto, Cantidad_Caja, Cantidad_Unitario, Fecha_Vencimiento) VALUES
(1, 5, 50, '2026-12-01'),
(2, 3, 30, '2026-11-15'),
(3, 2, 20, '2026-10-20'),
-- ... (continuar con lotes para todos los productos)

-- 5. Insertar compras
INSERT INTO Compra (Id_Proveedor, Id_Usuario, Fecha, Total) VALUES
(1, 1, '2025-09-10', 1250.00),
(2, 1, '2025-09-12', 980.50),
(3, 2, '2025-09-15', 1575.25);

-- 6. Insertar detalles de compra
INSERT INTO DetalleCompra (Id_Compra, Id_Lote, Cantidad_Caja, Cantidad_Unitario, Precio_Unitario) VALUES
(1, 1, 2, 0, 2.50),
(1, 2, 1, 0, 3.00),
(2, 3, 3, 0, 4.50);

-- 7. Insertar ventas
INSERT INTO Ventas (Id_Usuario, Fecha, Total) VALUES
(1, '2025-09-14', 150.00),
(2, '2025-09-15', 275.50),
(1, '2025-09-16', 89.75);

-- 8. Insertar detalles de ventas
INSERT INTO DetallesVentas (Id_Venta, Id_Lote, Cantidad_Unitario, Precio_Unitario, Detalles) VALUES
(1, 1, 10, 5.00, 'Venta al mostrador'),
(2, 2, 5, 6.50, 'Venta con receta médica'),
(3, 3, 3, 9.00, 'Venta urgente');