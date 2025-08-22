
CREATE DATABASE ClinicaMariaInmaculada;
GO

USE ClinicaDB;
GO

-- Tabla Tipo_Trabajadores
CREATE TABLE Tipo_Trabajadores (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Tipo VARCHAR(100) NOT NULL
);

-- Tabla Trabajadores
CREATE TABLE Trabajadores (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Apellido_Paterno VARCHAR(100) NOT NULL,
    Apellido_Materno VARCHAR(100) NOT NULL,
    Id_Tipo_Trabajador INT NOT NULL,
    FOREIGN KEY (Id_Tipo_Trabajador) REFERENCES Tipo_Trabajadores(id)
);



-- Tabla Usuario
CREATE TABLE Usuario (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Apellido_Paterno VARCHAR(100) NOT NULL,
    Apellido_Materno VARCHAR(100) NOT NULL,
    correo VARCHAR(200) NOT NULL UNIQUE,
    contrasena VARCHAR(255) NOT NULL
);

-- Tabla Pacientes
CREATE TABLE Pacientes (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Apellido_Paterno VARCHAR(100) NOT NULL,
    Apellido_Materno VARCHAR(100) NOT NULL,
    Edad INT NOT NULL CHECK (Edad >= 0 AND Edad <= 120)
);

-- Tabla Doctores
CREATE TABLE Doctores (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Apellido_Paterno VARCHAR(100) NOT NULL,
    Apellido_Materno VARCHAR(100) NOT NULL,
    Especialidad VARCHAR(150) NOT NULL,
    Matricula VARCHAR(50) NOT NULL UNIQUE,
    Edad INT NOT NULL CHECK (Edad >= 18 AND Edad <= 80)
);

-- Tabla Marca
CREATE TABLE Marca (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(150) NOT NULL,
    Detalles VARCHAR(500)
);

-- Tabla Productos
CREATE TABLE Productos (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Codigo VARCHAR(50) NOT NULL UNIQUE,
    Nombre VARCHAR(200) NOT NULL,
    Detalles VARCHAR(500),
    Precio_compra DECIMAL(10,2) NOT NULL CHECK (Precio_compra >= 0),
    Precio_venta DECIMAL(10,2) NOT NULL CHECK (Precio_venta >= 0),
    Stock_Caja INT NOT NULL DEFAULT 0 CHECK (Stock_Caja >= 0),
    Stock_Unitario INT NOT NULL DEFAULT 0 CHECK (Stock_Unitario >= 0),
    Unidad_Medida VARCHAR(50) NOT NULL,
    ID_Marca INT NOT NULL,
    Fecha_Venc DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (ID_Marca) REFERENCES Marca(id)
);

-- Tabla Especialidad
CREATE TABLE Especialidad (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(150) NOT NULL,
    Detalles VARCHAR(500),
    Precio_Normal DECIMAL(10,2) NOT NULL CHECK (Precio_Normal >= 0),
    Precio_Emergencia DECIMAL(10,2) NOT NULL CHECK (Precio_Emergencia >= 0),
    Id_Doctor INT NOT NULL,
    FOREIGN KEY (Id_Doctor) REFERENCES Doctores(id)
);

-- Tabla Consultas
CREATE TABLE Consultas (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Id_Usuario INT NOT NULL,
    Id_Paciente INT NOT NULL,
    Id_Especialidad INT NOT NULL,
    Fecha DATETIME NOT NULL DEFAULT GETDATE(),
    Detalles TEXT NOT NULL,
    tipo_consulta VARCHAR(50) NOT NULL DEFAULT 'Normal' CHECK (tipo_consulta IN ('Normal', 'Emergencia')),
    FOREIGN KEY (Id_Usuario) REFERENCES Usuario(id),
    FOREIGN KEY (Id_Paciente) REFERENCES Pacientes(id),
    FOREIGN KEY (Id_Especialidad) REFERENCES Especialidad(id)
);

-- Tabla Laboratorio
CREATE TABLE Laboratorio (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(200) NOT NULL,
    Detalles VARCHAR(500),
    Precio_Normal DECIMAL(10,2) NOT NULL CHECK (Precio_Normal >= 0),
    Precio_Emergencia DECIMAL(10,2) NOT NULL CHECK (Precio_Emergencia >= 0),
    Id_Paciente INT NOT NULL,
    Id_Trabajador INT,
    FOREIGN KEY (Id_Paciente) REFERENCES Pacientes(id),
    FOREIGN KEY (Id_Trabajador) REFERENCES Trabajadores(id)
);

-- Tabla Proveedor
CREATE TABLE Proveedor (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(200) NOT NULL,
    Direccion VARCHAR(300) NOT NULL
);

-- Tabla Compra
CREATE TABLE Compra (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Id_Proveedor INT NOT NULL,
    Id_Usuario INT NOT NULL,
    Fecha DATETIME NOT NULL DEFAULT GETDATE(),
    Total DECIMAL(12,2) NOT NULL CHECK (Total >= 0),
    FOREIGN KEY (Id_Proveedor) REFERENCES Proveedor(id),
    FOREIGN KEY (Id_Usuario) REFERENCES Usuario(id)
);

-- Tabla Lote
CREATE TABLE Lote (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Id_Producto INT NOT NULL,
    Cantidad_Caja INT NOT NULL DEFAULT 0 CHECK (Cantidad_Caja >= 0),
    Cantidad_Unitario INT NOT NULL DEFAULT 0 CHECK (Cantidad_Unitario >= 0),
    Fecha_Vencimiento DATE NOT NULL,
    FOREIGN KEY (Id_Producto) REFERENCES Productos(id)
);

-- Tabla DetalleCompra
CREATE TABLE DetalleCompra (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Id_Compra INT NOT NULL,
    Id_Lote INT NOT NULL,
    Cantidad_Caja INT NOT NULL DEFAULT 0 CHECK (Cantidad_Caja >= 0),
    Cantidad_Unitario INT NOT NULL DEFAULT 0 CHECK (Cantidad_Unitario >= 0),
    Precio_Unitario DECIMAL(10,2) NOT NULL CHECK (Precio_Unitario >= 0),
    FOREIGN KEY (Id_Compra) REFERENCES Compra(id),
    FOREIGN KEY (Id_Lote) REFERENCES Lote(id)
);

-- Tabla Ventas
CREATE TABLE Ventas (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Id_Usuario INT NOT NULL,
    Fecha DATETIME NOT NULL DEFAULT GETDATE(),
    Total DECIMAL(12,2) NOT NULL CHECK (Total >= 0),
    FOREIGN KEY (Id_Usuario) REFERENCES Usuario(id)
);

-- Tabla DetallesVentas
CREATE TABLE DetallesVentas (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Id_Venta INT NOT NULL,
    Id_Lote INT NOT NULL,
    Cantidad_Unitario INT NOT NULL CHECK (Cantidad_Unitario > 0),
    Precio_Unitario DECIMAL(10,2) NOT NULL CHECK (Precio_Unitario >= 0),
    Detalles TEXT,
    FOREIGN KEY (Id_Venta) REFERENCES Ventas(id),
    FOREIGN KEY (Id_Lote) REFERENCES Lote(id)
);

-- Tabla Tipo_Gastos
CREATE TABLE Tipo_Gastos (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(150) NOT NULL,
    fecha DATETIME NOT NULL DEFAULT GETDATE()
);

-- Tabla Gastos
CREATE TABLE Gastos (
    id INT IDENTITY(1,1) PRIMARY KEY,
    ID_Tipo INT NOT NULL,
    Descripcion VARCHAR(500) NOT NULL,
    Monto DECIMAL(12,2) NOT NULL CHECK (Monto >= 0),
    Fecha DATETIME NOT NULL DEFAULT GETDATE(),
    Proveedor VARCHAR(200),
    Id_RegistradoPor INT NOT NULL,  -- SIN DEFAULT - la app debe enviarlo
    
    -- Claves foráneas
    FOREIGN KEY (ID_Tipo) REFERENCES Tipo_Gastos(id),
    FOREIGN KEY (Id_RegistradoPor) REFERENCES Usuario(id)
);



-- �ndices para control interno y consultas r�pidas
CREATE INDEX IX_Consultas_Fecha ON Consultas(Fecha);
CREATE INDEX IX_Productos_Codigo ON Productos(Codigo);
CREATE INDEX IX_Productos_Stock ON Productos(Stock_Caja, Stock_Unitario);
CREATE INDEX IX_Lote_FechaVencimiento ON Lote(Fecha_Vencimiento);
CREATE INDEX IX_Ventas_Fecha ON Ventas(Fecha);
CREATE INDEX IX_Compra_Fecha ON Compra(Fecha);

-- Comentarios de documentaci�n
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Sistema de control interno para cl�nica m�dica - Gesti�n de inventario, consultas y operaciones', 
    @level0type = N'SCHEMA', @level0name = 'dbo';

PRINT 'Base de datos de Control Interno ClinicaDB creada exitosamente';
PRINT 'Sistema configurado para control interno con gesti�n de apellidos paterno/materno';
PRINT 'Inventario configurado con Stock_Caja y Stock_Unitario';


-- 1. Crear la tabla Roles
CREATE TABLE Roles (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL UNIQUE,
    Descripcion VARCHAR(300),
    Estado BIT NOT NULL DEFAULT 1
);
GO

-- 2. Insertar roles predefinidos (solo M�dico y Administrador)
INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES
('Administrador', 'Acceso completo al sistema de control interno', 1),
('M�dico', 'Acceso a consultas, pacientes y laboratorio', 1);
GO

-- 3. Agregar columnas a la tabla Usuario existente
ALTER TABLE Usuario 
ADD Id_Rol INT,
    Estado BIT DEFAULT 1;
GO

-- 4. Actualizar usuarios existentes con rol por defecto (Administrador)
UPDATE Usuario 
SET Id_Rol = 1, Estado = 1 
WHERE Id_Rol IS NULL;
GO

-- 5. Hacer obligatorio el campo Id_Rol
ALTER TABLE Usuario 
ALTER COLUMN Id_Rol INT NOT NULL;
GO

-- 6. Agregar la clave for�nea
ALTER TABLE Usuario 
ADD CONSTRAINT FK_Usuario_Rol 
FOREIGN KEY (Id_Rol) REFERENCES Roles(id);
GO

-- 7. Crear �ndices para mejorar rendimiento
CREATE INDEX IX_Usuario_Rol ON Usuario(Id_Rol);
CREATE INDEX IX_Roles_Estado ON Roles(Estado);
GO

-- 8. Verificar que todo se cre� correctamente
SELECT 'Tabla Roles creada correctamente' AS Mensaje;
SELECT COUNT(*) AS 'Total_Roles_Insertados' FROM Roles;
SELECT 'Columnas agregadas a Usuario correctamente' AS Mensaje;

PRINT 'Sistema de Roles implementado exitosamente - Solo Administrador y M�dico';
PRINT 'Todos los usuarios existentes asignados como Administrador por defecto';


DELETE FROM Gastos_Usuario;
DELETE FROM Gastos;
DELETE FROM Tipo_Gastos;
DELETE FROM DetallesVentas;
DELETE FROM Ventas;
DELETE FROM DetalleCompra;
DELETE FROM Lote;
DELETE FROM Compra;
DELETE FROM Proveedor;
DELETE FROM Laboratorio;
DELETE FROM Consultas;
DELETE FROM Especialidad;
DELETE FROM Productos;
DELETE FROM Marca;
DELETE FROM Doctores;
DELETE FROM Pacientes;
DELETE FROM Trabajadores;
DELETE FROM Tipo_Trabajadores;
DELETE FROM Usuario;

DBCC CHECKIDENT ('Gastos_Usuario', RESEED, 0);
DBCC CHECKIDENT ('Gastos', RESEED, 0);
DBCC CHECKIDENT ('Tipo_Gastos', RESEED, 0);
DBCC CHECKIDENT ('DetallesVentas', RESEED, 0);
DBCC CHECKIDENT ('Ventas', RESEED, 0);
DBCC CHECKIDENT ('DetalleCompra', RESEED, 0);
DBCC CHECKIDENT ('Lote', RESEED, 0);
DBCC CHECKIDENT ('Compra', RESEED, 0);
DBCC CHECKIDENT ('Proveedor', RESEED, 0);
DBCC CHECKIDENT ('Laboratorio', RESEED, 0);
DBCC CHECKIDENT ('Consultas', RESEED, 0);
DBCC CHECKIDENT ('Especialidad', RESEED, 0);
DBCC CHECKIDENT ('Productos', RESEED, 0);
DBCC CHECKIDENT ('Marca', RESEED, 0);
DBCC CHECKIDENT ('Doctores', RESEED, 0);
DBCC CHECKIDENT ('Pacientes', RESEED, 0);
DBCC CHECKIDENT ('Trabajadores', RESEED, 0);
DBCC CHECKIDENT ('Tipo_Trabajadores', RESEED, 0);
DBCC CHECKIDENT ('Usuario', RESEED, 0);

INSERT INTO Usuario (Nombre, Apellido_Paterno, Apellido_Materno, correo, contrase�a, Id_Rol, Estado) VALUES
('Carlos', 'Rodr�guez', 'Mendoza', 'carlos.rodriguez@clinica.com', 'Admin123*', 1, 1),
('Mar�a', 'Gonz�lez', 'Silva', 'maria.gonzalez@clinica.com', 'Medico456*', 2, 1),
('Ana', 'L�pez', 'Torres', 'ana.lopez@clinica.com', 'Admin789*', 1, 1),
('Jos�', 'Mart�nez', 'Vargas', 'jose.martinez@clinica.com', 'Medico321*', 2, 1),
('Patricia', 'Hern�ndez', 'Cruz', 'patricia.hernandez@clinica.com', 'Admin654*', 1, 1),
('Roberto', 'S�nchez', 'Flores', 'roberto.sanchez@clinica.com', 'Medico987*', 2, 1),
('Laura', 'P�rez', 'Morales', 'laura.perez@clinica.com', 'Admin147*', 1, 1),
('Miguel', 'Jim�nez', 'Castro', 'miguel.jimenez@clinica.com', 'Medico258*', 2, 1),
('Carmen', 'Ruiz', 'Ramos', 'carmen.ruiz@clinica.com', 'Admin369*', 1, 1),
('Fernando', 'Garc�a', 'Delgado', 'fernando.garcia@clinica.com', 'Medico741*', 2, 1);

INSERT INTO Tipo_Trabajadores (Tipo) VALUES
('Enfermero'),
('T�cnico en Laboratorio'),
('Auxiliar de Farmacia'),
('T�cnico Radi�logo'),
('Fisioterapeuta'),
('Nutricionista'),
('Psic�logo'),
('T�cnico en Mantenimiento'),
('Secretaria'),
('Contador');

INSERT INTO Trabajadores (Nombre, Apellido_Paterno, Apellido_Materno, Id_Tipo_Trabajador) VALUES
('Ana', 'Garc�a', 'L�pez', 1),
('Carlos', 'Mart�nez', 'Rodr�guez', 2),
('Mar�a', 'Hern�ndez', 'S�nchez', 3),
('Jos�', 'Gonz�lez', 'P�rez', 4),
('Laura', 'Jim�nez', 'Morales', 5),
('Miguel', 'Ruiz', 'Castro', 6),
('Carmen', 'Vargas', 'Flores', 7),
('Roberto', 'Mendoza', 'Torres', 8),
('Patricia', 'Ram�rez', 'Guzm�n', 9),
('Fernando', 'Silva', 'Ortega', 10);

INSERT INTO Pacientes (Nombre, Apellido_Paterno, Apellido_Materno, Edad) VALUES
('Pedro', '�lvarez', 'Cruz', 45),
('Sof�a', 'Moreno', 'Vega', 32),
('Diego', 'Reyes', 'Campos', 28),
('Valeria', 'Castillo', 'Luna', 67),
('Andr�s', 'Guerrero', 'Herrera', 54),
('Isabella', 'Ramos', 'Medina', 23),
('Sebasti�n', 'Navarro', 'Aguilar', 41),
('Camila', 'Paredes', 'Romero', 36),
('Mateo', 'Salinas', 'Delgado', 19),
('Valentina', 'Cort�s', 'Pe�a', 58);

INSERT INTO Doctores (Nombre, Apellido_Paterno, Apellido_Materno, Especialidad, Matricula, Edad) VALUES
('Dr. Juan', 'P�rez', 'Garc�a', 'Cardiolog�a', 'MAT001', 42),
('Dra. Elena', 'L�pez', 'Mart�n', 'Pediatr�a', 'MAT002', 38),
('Dr. Ricardo', 'S�nchez', 'Flores', 'Neurolog�a', 'MAT003', 55),
('Dra. M�nica', 'Torres', 'Silva', 'Ginecolog�a', 'MAT004', 45),
('Dr. Alberto', 'Morales', 'Cruz', 'Traumatolog�a', 'MAT005', 50),
('Dra. Claudia', 'Vega', 'Rojas', 'Dermatolog�a', 'MAT006', 35),
('Dr. Francisco', 'Herrera', 'Mendoza', 'Oftalmolog�a', 'MAT007', 48),
('Dra. Gabriela', 'Castro', 'Vargas', 'Psiquiatr�a', 'MAT008', 43),
('Dr. Luis', 'Guzm�n', 'Ramos', 'Urolog�a', 'MAT009', 52),
('Dra. Andrea', 'Delgado', 'Navarro', 'Endocrinolog�a', 'MAT010', 40);

INSERT INTO Marca (Nombre, Detalles) VALUES
('Bayer', 'Productos farmac�uticos alemanes'),
('Pfizer', 'Medicamentos de alta calidad'),
('Novartis', 'Innovaci�n en salud'),
('Roche', 'Biotecnolog�a avanzada'),
('Johnson & Johnson', 'Cuidado de la salud'),
('Abbott', 'Dispositivos m�dicos'),
('Merck', 'Investigaci�n farmac�utica'),
('GSK', 'Vacunas y medicamentos'),
('Sanofi', 'Soluciones de salud'),
('AstraZeneca', 'Medicamentos especializados');

INSERT INTO Productos (Codigo, Nombre, Detalles, Precio, Stock_Caja, Stock_Unitario, Unidad_Medida, ID_Marca) VALUES
('MED001', 'Paracetamol 500mg', 'Analg�sico y antipir�tico', 15.50, 20, 500, 'Tabletas', 1),
('MED002', 'Amoxicilina 250mg', 'Antibi�tico de amplio espectro', 45.00, 15, 300, 'C�psulas', 2),
('MED003', 'Ibuprofeno 400mg', 'Antiinflamatorio no esteroideo', 22.75, 25, 600, 'Tabletas', 3),
('MED004', 'Loratadina 10mg', 'Antihistam�nico', 18.90, 30, 750, 'Tabletas', 4),
('MED005', 'Omeprazol 20mg', 'Inhibidor de bomba de protones', 35.60, 18, 450, 'C�psulas', 5),
('MED006', 'Metformina 850mg', 'Antidiab�tico', 28.40, 22, 550, 'Tabletas', 6),
('MED007', 'Atorvastatina 20mg', 'Hipolipemiante', 52.30, 12, 300, 'Tabletas', 7),
('MED008', 'Losart�n 50mg', 'Antihipertensivo', 41.80, 16, 400, 'Tabletas', 8),
('MED009', 'Cetirizina 10mg', 'Antihistam�nico', 19.75, 28, 700, 'Tabletas', 9),
('MED010', 'Diclofenaco 75mg', 'Antiinflamatorio', 31.20, 20, 500, 'Tabletas', 10);

INSERT INTO Especialidad (Nombre, Detalles, Precio_Normal, Precio_Emergencia, Id_Doctor) VALUES
('Consulta Cardiol�gica', 'Evaluaci�n del sistema cardiovascular', 150.00, 250.00, 1),
('Consulta Pedi�trica', 'Atenci�n m�dica infantil', 120.00, 200.00, 2),
('Consulta Neurol�gica', 'Evaluaci�n del sistema nervioso', 180.00, 300.00, 3),
('Consulta Ginecol�gica', 'Atenci�n en salud femenina', 140.00, 230.00, 4),
('Consulta Traumatol�gica', 'Atenci�n de lesiones musculoesquel�ticas', 160.00, 270.00, 5),
('Consulta Dermatol�gica', 'Evaluaci�n de la piel', 130.00, 220.00, 6),
('Consulta Oftalmol�gica', 'Evaluaci�n de la vista', 125.00, 210.00, 7),
('Consulta Psiqui�trica', 'Atenci�n en salud mental', 170.00, 280.00, 8),
('Consulta Urol�gica', 'Atenci�n del sistema urinario', 155.00, 260.00, 9),
('Consulta Endocrinol�gica', 'Evaluaci�n hormonal', 165.00, 275.00, 10);

INSERT INTO Consultas (Id_Usuario, Id_Paciente, Id_Especialidad, Fecha, Detalles) VALUES
(1, 1, 1, '2025-01-15 09:30:00', 'Dolor de pecho, evaluaci�n cardiol�gica completa'),
(2, 2, 2, '2025-01-15 10:15:00', 'Control pedi�trico de rutina'),
(3, 3, 3, '2025-01-16 11:00:00', 'Cefaleas recurrentes, estudios neurol�gicos'),
(4, 4, 4, '2025-01-16 14:30:00', 'Control ginecol�gico anual'),
(5, 5, 5, '2025-01-17 08:45:00', 'Dolor lumbar cr�nico'),
(6, 6, 6, '2025-01-17 15:20:00', 'Revisi�n dermatol�gica de lunares'),
(7, 7, 7, '2025-01-18 09:10:00', 'Disminuci�n de la visi�n'),
(8, 8, 8, '2025-01-18 16:00:00', 'Evaluaci�n psiqui�trica por ansiedad'),
(9, 9, 9, '2025-01-19 10:30:00', 'Problemas urinarios'),
(10, 10, 10, '2025-01-19 13:15:00', 'Control de diabetes');

INSERT INTO Laboratorio (Nombre, Detalles, Precio_Normal, Precio_Emergencia, Id_Paciente, Id_Trabajador) VALUES
('Hemograma Completo', 'An�lisis completo de sangre', 80.00, 120.00, 1, 2),
('Perfil Lip�dico', 'Colesterol y triglic�ridos', 95.00, 140.00, 2, 2),
('Glucosa en Ayunas', 'Nivel de az�car en sangre', 35.00, 50.00, 3, 2),
('Examen de Orina', 'An�lisis completo de orina', 45.00, 65.00, 4, 2),
('Perfil Hep�tico', 'Funci�n del h�gado', 110.00, 160.00, 5, 2),
('Perfil Renal', 'Funci�n de los ri�ones', 85.00, 125.00, 6, 2),
('Perfil Tiroideo', 'Hormonas tiroideas', 150.00, 220.00, 7, 2),
('Electrolitos', 'Sodio, potasio, cloro', 60.00, 90.00, 8, 2),
('Prote�na C Reactiva', 'Marcador de inflamaci�n', 70.00, 100.00, 9, 2),
('Vitamina D', 'Nivel de vitamina D en sangre', 120.00, 180.00, 10, 2);

INSERT INTO Proveedor (Nombre, Direccion) VALUES
('Distribuidora M�dica SA', 'Av. Salud 123, Santa Cruz'),
('Farmac�utica Central', 'Calle Medicina 456, La Paz'),
('Suministros Hospitalarios', 'Zona Norte 789, Cochabamba'),
('Medicamentos del Sur', 'Av. Principal 321, Tarija'),
('Distribuciones Andinas', 'Plaza Central 654, Oruro'),
('Farmacia Mayorista', 'Barrio Comercial 987, Potos�'),
('Suministros Cl�nicos', 'Av. Libertad 147, Sucre'),
('Medicamentos Express', 'Zona Este 258, Santa Cruz'),
('Distribuidora Nacional', 'Calle Central 369, La Paz'),
('Farmac�utica Regional', 'Av. Bolivia 741, Cochabamba');

INSERT INTO Compra (Id_Proveedor, Id_Usuario, Fecha, Total) VALUES
(1, 1, '2025-01-10 08:30:00', 1250.75),
(2, 2, '2025-01-11 09:15:00', 2340.50),
(3, 3, '2025-01-12 10:45:00', 1875.25),
(4, 4, '2025-01-13 11:30:00', 3210.80),
(5, 5, '2025-01-14 14:20:00', 1650.40),
(6, 6, '2025-01-15 15:10:00', 2890.60),
(7, 7, '2025-01-16 16:00:00', 1420.90),
(8, 8, '2025-01-17 08:45:00', 2750.35),
(9, 9, '2025-01-18 09:30:00', 1980.70),
(10, 10, '2025-01-19 10:20:00', 2450.85);

INSERT INTO Lote (Id_Producto, Cantidad_Caja, Cantidad_Unitario, Fecha_Vencimiento) VALUES
(1, 5, 125, '2026-12-31'),
(2, 3, 75, '2025-08-15'),
(3, 6, 150, '2027-03-20'),
(4, 8, 200, '2026-09-10'),
(5, 4, 100, '2025-11-25'),
(6, 7, 175, '2026-06-30'),
(7, 2, 50, '2025-07-18'),
(8, 5, 125, '2026-10-12'),
(9, 9, 225, '2027-01-08'),
(10, 6, 150, '2025-12-05');

INSERT INTO DetalleCompra (Id_Compra, Id_Lote, Cantidad_Caja, Cantidad_Unitario, Precio_Unitario) VALUES
(1, 1, 5, 125, 12.50),
(2, 2, 3, 75, 38.00),
(3, 3, 6, 150, 18.20),
(4, 4, 8, 200, 15.10),
(5, 5, 4, 100, 28.80),
(6, 6, 7, 175, 22.40),
(7, 7, 2, 50, 42.30),
(8, 8, 5, 125, 33.60),
(9, 9, 9, 225, 15.80),
(10, 10, 6, 150, 25.20);

INSERT INTO Ventas (Id_Usuario, Fecha, Total) VALUES
(1, '2025-01-15 12:30:00', 185.50),
(2, '2025-01-15 14:45:00', 315.75),
(3, '2025-01-16 09:20:00', 145.80),
(4, '2025-01-16 16:10:00', 425.60),
(5, '2025-01-17 10:35:00', 275.40),
(6, '2025-01-17 15:25:00', 195.90),
(7, '2025-01-18 11:15:00', 365.25),
(8, '2025-01-18 17:40:00', 255.30),
(9, '2025-01-19 08:50:00', 485.70),
(10, '2025-01-19 14:20:00', 335.85);

INSERT INTO DetallesVentas (Id_Venta, Id_Lote, Cantidad_Unitario, Precio_Unitario, Detalles) VALUES
(1, 1, 12, 15.50, 'Venta al mostrador'),
(2, 2, 7, 45.00, 'Receta m�dica'),
(3, 3, 6, 22.75, 'Venta directa'),
(4, 4, 22, 18.90, 'Receta m�dica'),
(5, 5, 8, 35.60, 'Venta al mostrador'),
(6, 6, 7, 28.40, 'Receta m�dica'),
(7, 7, 7, 52.30, 'Venta directa'),
(8, 8, 6, 41.80, 'Receta m�dica'),
(9, 9, 24, 19.75, 'Venta al mostrador'),
(10, 10, 13, 31.20, 'Receta m�dica');

INSERT INTO Tipo_Gastos (Nombre, fecha) VALUES
('Servicios B�sicos', '2025-01-15 08:00:00'),
('Mantenimiento', '2025-01-15 09:30:00'),
('Suministros de Oficina', '2025-01-16 10:15:00'),
('Publicidad', '2025-01-16 11:45:00'),
('Seguros', '2025-01-17 14:20:00'),
('Capacitaci�n', '2025-01-17 15:10:00'),
('Transporte', '2025-01-18 08:30:00'),
('Comunicaciones', '2025-01-18 09:45:00'),
('Limpieza', '2025-01-19 10:30:00'),
('Equipamiento', '2025-01-19 11:15:00');

INSERT INTO Gastos (ID_Tipo, Monto, Fecha) VALUES
(1, 850.00, '2025-01-15 08:00:00'),
(2, 1200.50, '2025-01-15 09:30:00'),
(3, 345.75, '2025-01-16 10:15:00'),
(4, 750.00, '2025-01-16 11:45:00'),
(5, 2200.00, '2025-01-17 14:20:00'),
(6, 980.25, '2025-01-17 15:10:00'),
(7, 425.60, '2025-01-18 08:30:00'),
(8, 680.40, '2025-01-18 09:45:00'),
(9, 390.80, '2025-01-19 10:30:00'),
(10, 1850.75, '2025-01-19 11:15:00');

INSERT INTO Gastos_Usuario (Id_Usuario, Id_Gastos) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 4),
(5, 5),
(6, 6),
(7, 7),
(8, 8),
(9, 9),
(10, 10);


-- 1. VERIFICAR CONTEO DE REGISTROS EN TODAS LAS TABLAS
SELECT 'Roles' AS Tabla, COUNT(*) AS Total_Registros FROM Roles
UNION ALL
SELECT 'Usuario', COUNT(*) FROM Usuario
UNION ALL
SELECT 'Tipo_Trabajadores', COUNT(*) FROM Tipo_Trabajadores
UNION ALL
SELECT 'Trabajadores', COUNT(*) FROM Trabajadores
UNION ALL
SELECT 'Pacientes', COUNT(*) FROM Pacientes
UNION ALL
SELECT 'Doctores', COUNT(*) FROM Doctores
UNION ALL
SELECT 'Marca', COUNT(*) FROM Marca
UNION ALL
SELECT 'Productos', COUNT(*) FROM Productos
UNION ALL
SELECT 'Especialidad', COUNT(*) FROM Especialidad
UNION ALL
SELECT 'Consultas', COUNT(*) FROM Consultas
UNION ALL
SELECT 'Laboratorio', COUNT(*) FROM Laboratorio
UNION ALL
SELECT 'Proveedor', COUNT(*) FROM Proveedor
UNION ALL
SELECT 'Compra', COUNT(*) FROM Compra
UNION ALL
SELECT 'Lote', COUNT(*) FROM Lote
UNION ALL
SELECT 'DetalleCompra', COUNT(*) FROM DetalleCompra
UNION ALL
SELECT 'Ventas', COUNT(*) FROM Ventas
UNION ALL
SELECT 'DetallesVentas', COUNT(*) FROM DetallesVentas
UNION ALL
SELECT 'Tipo_Gastos', COUNT(*) FROM Tipo_Gastos
UNION ALL
SELECT 'Gastos', COUNT(*) FROM Gastos
UNION ALL
SELECT 'Gastos_Usuario', COUNT(*) FROM Gastos_Usuario;

-- 2. VERIFICAR ROLES Y USUARIOS
SELECT 
    r.Nombre AS Rol,
    COUNT(u.id) AS Cantidad_Usuarios,
    STRING_AGG(CONCAT(u.Nombre, ' ', u.Apellido_Paterno), ', ') AS Usuarios
FROM Roles r
LEFT JOIN Usuario u ON r.id = u.Id_Rol
GROUP BY r.id, r.Nombre;

-- 3. VERIFICAR INTEGRIDAD DE CLAVES FOR�NEAS - USUARIOS
SELECT 
    u.id,
    CONCAT(u.Nombre, ' ', u.Apellido_Paterno, ' ', u.Apellido_Materno) AS Usuario_Completo,
    u.correo,
    r.Nombre AS Rol,
    u.Estado
FROM Usuario u
INNER JOIN Roles r ON u.Id_Rol = r.id;


-- 4. VERIFICAR TRABAJADORES Y SUS TIPOS
SELECT 
    tt.Tipo,
    COUNT(t.id) AS Cantidad_Trabajadores,
    STRING_AGG(CONCAT(t.Nombre, ' ', t.Apellido_Paterno), ', ') AS Trabajadores
FROM Tipo_Trabajadores tt
LEFT JOIN Trabajadores t ON tt.id = t.Id_Tipo_Trabajador
GROUP BY tt.id, tt.Tipo;


-- 5. VERIFICAR DOCTORES Y SUS ESPECIALIDADES
SELECT 
    CONCAT(d.Nombre, ' ', d.Apellido_Paterno, ' ', d.Apellido_Materno) AS Doctor,
    d.Especialidad AS Especialidad_Doctor,
    d.Matricula,
    COUNT(e.id) AS Especialidades_Registradas
FROM Doctores d
LEFT JOIN Especialidad e ON d.id = e.Id_Doctor
GROUP BY d.id, d.Nombre, d.Apellido_Paterno, d.Apellido_Materno, d.Especialidad, d.Matricula;

-- 6. VERIFICAR PRODUCTOS E INVENTARIO
SELECT 
    p.Codigo,
    p.Nombre,
    m.Nombre AS Marca,
    p.Precio,
    p.Stock_Caja,
    p.Stock_Unitario,
    (p.Stock_Caja + p.Stock_Unitario) AS Stock_Total
FROM Productos p
INNER JOIN Marca m ON p.ID_Marca = m.id
ORDER BY p.Stock_Caja + p.Stock_Unitario DESC;


-- 7. VERIFICAR CONSULTAS M�DICAS
SELECT 
    c.id AS Consulta_ID,
    CONCAT(u.Nombre, ' ', u.Apellido_Paterno) AS Usuario_Registro,
    CONCAT(p.Nombre, ' ', p.Apellido_Paterno) AS Paciente,
    e.Nombre AS Especialidad,
    c.Fecha,
    LEFT(c.Detalles, 50) + '...' AS Resumen_Detalles
FROM Consultas c
INNER JOIN Usuario u ON c.Id_Usuario = u.id
INNER JOIN Pacientes p ON c.Id_Paciente = p.id
INNER JOIN Especialidad e ON c.Id_Especialidad = e.id
ORDER BY c.Fecha DESC;

-- 8. VERIFICAR LABORATORIO Y TRABAJADORES
SELECT 
    l.Nombre AS Examen,
    CONCAT(p.Nombre, ' ', p.Apellido_Paterno) AS Paciente,
    CONCAT(t.Nombre, ' ', t.Apellido_Paterno) AS Trabajador_Encargado,
    tt.Tipo AS Tipo_Trabajador,
    l.Precio_Normal,
    l.Precio_Emergencia
FROM Laboratorio l
INNER JOIN Pacientes p ON l.Id_Paciente = p.id
LEFT JOIN Trabajadores t ON l.Id_Trabajador = t.id
LEFT JOIN Tipo_Trabajadores tt ON t.Id_Tipo_Trabajador = tt.id;

-- 9. VERIFICAR COMPRAS Y PROVEEDORES
SELECT 
    c.id AS Compra_ID,
    pr.Nombre AS Proveedor,
    CONCAT(u.Nombre, ' ', u.Apellido_Paterno) AS Usuario_Compra,
    c.Fecha,
    c.Total,
    COUNT(dc.id) AS Items_Comprados
FROM Compra c
INNER JOIN Proveedor pr ON c.Id_Proveedor = pr.id
INNER JOIN Usuario u ON c.Id_Usuario = u.id
LEFT JOIN DetalleCompra dc ON c.id = dc.Id_Compra
GROUP BY c.id, pr.Nombre, u.Nombre, u.Apellido_Paterno, c.Fecha, c.Total
ORDER BY c.Fecha DESC;

-- 10. VERIFICAR LOTES Y FECHAS DE VENCIMIENTO
SELECT 
    l.id AS Lote_ID,
    p.Codigo,
    p.Nombre AS Producto,
    l.Cantidad_Caja,
    l.Cantidad_Unitario,
    l.Fecha_Vencimiento,
    CASE 
        WHEN l.Fecha_Vencimiento < GETDATE() THEN 'VENCIDO'
        WHEN l.Fecha_Vencimiento < DATEADD(MONTH, 3, GETDATE()) THEN 'POR VENCER'
        ELSE 'VIGENTE'
    END AS Estado_Vencimiento
FROM Lote l
INNER JOIN Productos p ON l.Id_Producto = p.id
ORDER BY l.Fecha_Vencimiento ASC;

-- 11. VERIFICAR VENTAS Y DETALLES
SELECT 
    v.id AS Venta_ID,
    CONCAT(u.Nombre, ' ', u.Apellido_Paterno) AS Vendedor,
    v.Fecha,
    v.Total,
    COUNT(dv.id) AS Items_Vendidos,
    SUM(dv.Cantidad_Unitario) AS Total_Unidades_Vendidas
FROM Ventas v
INNER JOIN Usuario u ON v.Id_Usuario = u.id
LEFT JOIN DetallesVentas dv ON v.id = dv.Id_Venta
GROUP BY v.id, u.Nombre, u.Apellido_Paterno, v.Fecha, v.Total
ORDER BY v.Fecha DESC;

-- 12. VERIFICAR GASTOS POR TIPO
SELECT 
    tg.Nombre AS Tipo_Gasto,
    COUNT(g.id) AS Cantidad_Gastos,
    SUM(g.Monto) AS Total_Monto,
    AVG(g.Monto) AS Promedio_Monto,
    MIN(g.Monto) AS Monto_Minimo,
    MAX(g.Monto) AS Monto_Maximo
FROM Tipo_Gastos tg
LEFT JOIN Gastos g ON tg.id = g.ID_Tipo
GROUP BY tg.id, tg.Nombre
ORDER BY SUM(g.Monto) DESC;

-- 13. VERIFICAR RELACIONES USUARIO-GASTOS
SELECT 
    CONCAT(u.Nombre, ' ', u.Apellido_Paterno) AS Usuario,
    tg.Nombre AS Tipo_Gasto,
    g.Monto,
    g.Fecha
FROM Gastos_Usuario gu
INNER JOIN Usuario u ON gu.Id_Usuario = u.id
INNER JOIN Gastos g ON gu.Id_Gastos = g.id
INNER JOIN Tipo_Gastos tg ON g.ID_Tipo = tg.id
ORDER BY g.Fecha DESC;

-- 14. RESUMEN GENERAL DEL SISTEMA
SELECT 
    'RESUMEN GENERAL DEL SISTEMA' AS Descripcion,
    (SELECT COUNT(*) FROM Usuario) AS Total_Usuarios,
    (SELECT COUNT(*) FROM Pacientes) AS Total_Pacientes,
    (SELECT COUNT(*) FROM Doctores) AS Total_Doctores,
    (SELECT COUNT(*) FROM Productos) AS Total_Productos,
    (SELECT COUNT(*) FROM Consultas) AS Total_Consultas,
    (SELECT COUNT(*) FROM Ventas) AS Total_Ventas,
    (SELECT SUM(Total) FROM Ventas) AS Ingresos_Ventas,
    (SELECT SUM(Total) FROM Compra) AS Gastos_Compras,
    (SELECT SUM(Monto) FROM Gastos) AS Gastos_Operativos;

-- 15. VERIFICAR CONSTRAINTS Y DATOS V�LIDOS
SELECT 'Verificaciones de Integridad' AS Tipo_Verificacion
UNION ALL
SELECT 'Usuarios sin rol: ' + CAST(COUNT(*) AS VARCHAR) FROM Usuario WHERE Id_Rol IS NULL
UNION ALL
SELECT 'Pacientes con edad inv�lida: ' + CAST(COUNT(*) AS VARCHAR) FROM Pacientes WHERE Edad < 0 OR Edad > 120
UNION ALL
SELECT 'Productos con precio negativo: ' + CAST(COUNT(*) AS VARCHAR) FROM Productos WHERE Precio < 0
UNION ALL
SELECT 'Productos con stock negativo: ' + CAST(COUNT(*) AS VARCHAR) FROM Productos WHERE Stock_Caja < 0 OR Stock_Unitario < 0
UNION ALL
SELECT 'Lotes vencidos: ' + CAST(COUNT(*) AS VARCHAR) FROM Lote WHERE Fecha_Vencimiento < GETDATE();