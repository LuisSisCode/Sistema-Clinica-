CREATE DATABASE ClinicaMariaInmaculada;
GO

USE ClinicaMariaInmaculada;
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
    Cedula VARCHAR(50) NOT NULL UNIQUE CHECK (LEN(Cedula) >= 5 AND Cedula LIKE '%[0-9]%[0-9]%[0-9]%[0-9]%[0-9]%')

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

-- Tabla Tipos_Procedimientos (Nueva tabla añadida)
CREATE TABLE Tipos_Procedimientos (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(500),
    Precio_Normal DECIMAL(10,2) NOT NULL CHECK (Precio_Normal >= 0),
    Precio_Emergencia DECIMAL(10,2) NOT NULL CHECK (Precio_Emergencia >= 0)
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

-- Tabla Laboratorio -- Actualizada para incluir Id_Trabajador y Id_Tipo_Analisis
CREATE TABLE Laboratorio (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Id_Paciente INT NOT NULL,
    Id_Trabajador INT NOT NULL,
    Id_Tipo_Analisis INT NOT NULL,
    Fecha DATETIME NOT NULL DEFAULT GETDATE(),
    Id_RegistradoPor INT NOT NULL,
    Tipo VARCHAR(20) NOT NULL DEFAULT 'Normal' CHECK (Tipo IN ('Normal', 'Emergencia')),
    Detalles VARCHAR(500),
    FOREIGN KEY (Id_Paciente) REFERENCES Pacientes(id),
    FOREIGN KEY (Id_Trabajador) REFERENCES Trabajadores(id),
    FOREIGN KEY (Id_Tipo_Analisis) REFERENCES Tipos_Analisis(id),
    FOREIGN KEY (Id_RegistradoPor) REFERENCES Usuario(id)
);

-- Tabla Enfermeria (Nueva tabla añadida)
CREATE TABLE Enfermeria (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Id_Paciente INT NOT NULL,
    Id_Procedimiento INT NOT NULL,
    Cantidad INT NOT NULL CHECK (Cantidad > 0),
    Fecha DATETIME NOT NULL DEFAULT GETDATE(),
    Id_RegistradoPor INT NOT NULL,
    Id_Trabajador INT NOT NULL,
    Tipo VARCHAR(50) NOT NULL CHECK (Tipo IN ('Normal', 'Emergencia')),
    FOREIGN KEY (Id_Paciente) REFERENCES Pacientes(id),
    FOREIGN KEY (Id_Procedimiento) REFERENCES Tipos_Procedimientos(id),
    FOREIGN KEY (Id_RegistradoPor) REFERENCES Usuario(id),
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
    Id_RegistradoPor INT NOT NULL,
    FOREIGN KEY (ID_Tipo) REFERENCES Tipo_Gastos(id),
    FOREIGN KEY (Id_RegistradoPor) REFERENCES Usuario(id)
);

CREATE TABLE [dbo].[Tipos_Analisis](
    [id] INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
    [Nombre] VARCHAR(100) NOT NULL,
    [Descripcion] VARCHAR(300) NULL,
    [Precio_Normal] DECIMAL(10,2) NOT NULL,
    [Precio_Emergencia] DECIMAL(10,2) NOT NULL
);

-- Índices para control interno y consultas rápidas
CREATE INDEX IX_Consultas_Fecha ON Consultas(Fecha);
CREATE INDEX IX_Productos_Codigo ON Productos(Codigo);
CREATE INDEX IX_Productos_Stock ON Productos(Stock_Caja, Stock_Unitario);
CREATE INDEX IX_Lote_FechaVencimiento ON Lote(Fecha_Vencimiento);
CREATE INDEX IX_Ventas_Fecha ON Ventas(Fecha);
CREATE INDEX IX_Compra_Fecha ON Compra(Fecha);
CREATE INDEX IX_Enfermeria_Fecha ON Enfermeria(Fecha);
CREATE INDEX IX_Tipos_Procedimientos_Nombre ON Tipos_Procedimientos(Nombre);

-- Comentarios de documentación
EXEC sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Sistema de control interno para clínica médica - Gestión de inventario, consultas y operaciones', 
    @level0type = N'SCHEMA', @level0name = 'dbo';

PRINT 'Base de datos de Control Interno ClinicaMariaInmaculada creada exitosamente';
PRINT 'Sistema configurado para control interno con gestión de apellidos paterno/materno';
PRINT 'Inventario configurado con Stock_Caja y Stock_Unitario';

-- 1. Crear la tabla Roles
CREATE TABLE Roles (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL UNIQUE,
    Descripcion VARCHAR(300),
    Estado BIT NOT NULL DEFAULT 1
);
GO

-- 2. Insertar roles predefinidos (solo Médico y Administrador)
INSERT INTO Roles (Nombre, Descripcion, Estado) VALUES
('Administrador', 'Acceso completo al sistema de control interno', 1),
('Médico', 'Acceso a consultas, pacientes y laboratorio', 1);
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

-- 6. Agregar la clave foránea
ALTER TABLE Usuario 
ADD CONSTRAINT FK_Usuario_Rol 
FOREIGN KEY (Id_Rol) REFERENCES Roles(id);
GO

-- 7. Crear índices para mejorar rendimiento
CREATE INDEX IX_Usuario_Rol ON Usuario(Id_Rol);
CREATE INDEX IX_Roles_Estado ON Roles(Estado);
GO

-- 8. Verificar que todo se creó correctamente
SELECT 'Tabla Roles creada correctamente' AS Mensaje;
SELECT COUNT(*) AS 'Total_Roles_Insertados' FROM Roles;
SELECT 'Columnas agregadas a Usuario correctamente' AS Mensaje;

PRINT 'Sistema de Roles implementado exitosamente - Solo Administrador y Médico';
PRINT 'Todos los usuarios existentes asignados como Administrador por defecto';

