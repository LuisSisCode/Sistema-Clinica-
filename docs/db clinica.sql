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
    Matricula,
    Especialidad,
    FOREIGN KEY (Id_Tipo_Trabajador) REFERENCES Tipo_Trabajadores(id)
);

-- Tabla Usuario
CREATE TABLE Usuario (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Apellido_Paterno VARCHAR(100) NOT NULL,
    Apellido_Materno VARCHAR(100) NOT NULL,
    nombre_usuario VARCHAR(200) NOT NULL UNIQUE,
    contrasena VARCHAR(255) NOT NULL
    FOREIGN KEY (Id_Rol) REFERENCES Roles(id);

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
    Stock_Unitario INT NOT NULL DEFAULT 0 CHECK (Stock_Unitario >= 0),
    Unidad_Medida VARCHAR(50) NOT NULL,
    ID_Marca INT NOT NULL,
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
    Tipo_Consulta VARCHAR(50) NOT NULL DEFAULT 'Normal' CHECK (Tipo_Consulta IN ('Normal', 'Emergencia')),
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
    Cantidad_Unitario INT NOT NULL DEFAULT 0 CHECK (Cantidad_Unitario >= 0),
    Fecha_Vencimiento DATE NOT NULL,
    FOREIGN KEY (Id_Producto) REFERENCES Productos(id)
);

-- Tabla DetalleCompra
CREATE TABLE DetalleCompra (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Id_Compra INT NOT NULL,
    Id_Lote INT NOT NULL,
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

    );

    -- Tabla Gastos actualizada
    CREATE TABLE Gastos (
        id INT IDENTITY(1,1) PRIMARY KEY,
        ID_Tipo INT NOT NULL,
        Descripcion VARCHAR(500) NOT NULL,
        Monto DECIMAL(12,2) NOT NULL CHECK (Monto >= 0),
        Fecha DATETIME NOT NULL DEFAULT GETDATE(),
        Id_RegistradoPor INT NOT NULL,
        ID_Proveedor INT NULL,
        FOREIGN KEY (ID_Tipo) REFERENCES Tipo_Gastos(id),
        FOREIGN KEY (Id_RegistradoPor) REFERENCES Usuario(id),
        FOREIGN KEY (ID_Proveedor) REFERENCES Proveedor_Gastos(id)
    );

    CREATE TABLE [dbo].[Tipos_Analisis](
    [id] INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
    [Nombre] VARCHAR(100) NOT NULL,
    [Descripcion] VARCHAR(300) NULL,
    [Precio_Normal] DECIMAL(10,2) NOT NULL,
    [Precio_Emergencia] DECIMAL(10,2) NOT NULL
);

-- Tabla de Cierre de caja
CREATE TABLE CierreCaja (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Fecha DATE NOT NULL,
    HoraInicio TIME NOT NULL,
    HoraFin TIME NOT NULL,
    EfectivoReal DECIMAL(12,2) NOT NULL CHECK (EfectivoReal >= 0),
    SaldoTeorico DECIMAL(12,2) NOT NULL CHECK (SaldoTeorico >= 0),
    Diferencia DECIMAL(12,2) NOT NULL,
    IdUsuario INT NOT NULL,
    FechaCierre DATETIME NOT NULL DEFAULT GETDATE(),
    Observaciones VARCHAR(500),
    FOREIGN KEY (IdUsuario) REFERENCES Usuario(id)
);

-- Tabla de Ingresos Extras
CREATE TABLE IngresosExtras (
    id INT IDENTITY(1,1) PRIMARY KEY,
    descripcion VARCHAR(500) NOT NULL,
    monto DECIMAL(12,2) NOT NULL CHECK (monto >= 0),
    fecha DATETIME NOT NULL DEFAULT GETDATE(),
    id_registradoPor INT NOT NULL,
    FOREIGN KEY (id_registradoPor) REFERENCES Usuario(id)
);

CREATE TABLE Proveedor_Gastos (
    id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(200) NOT NULL UNIQUE,
    Telefono NVARCHAR(50) NULL,
    Direccion NVARCHAR(300) NULL,
    Frecuencia_Uso INT DEFAULT 0,
    Estado BIT DEFAULT 1,
    Fecha_Creacion DATETIME DEFAULT GETDATE(),
    Notas NVARCHAR(500) NULL
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



