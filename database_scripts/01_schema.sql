USE [master]
GO
/****** Object:  Database [ClinicaMariaInmaculada]    Script Date: 09/10/2025 17:08:51 ******/
CREATE DATABASE [ClinicaMariaInmaculada]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'ClinicaMariaInmaculada', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\ClinicaMariaInmaculada.mdf' , SIZE = 73728KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'ClinicaMariaInmaculada_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\ClinicaMariaInmaculada_log.ldf' , SIZE = 8192KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
 WITH CATALOG_COLLATION = DATABASE_DEFAULT, LEDGER = OFF
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET COMPATIBILITY_LEVEL = 160
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [ClinicaMariaInmaculada].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET ARITHABORT OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET  DISABLE_BROKER 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET  MULTI_USER 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET DB_CHAINING OFF 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET ACCELERATED_DATABASE_RECOVERY = OFF  
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET QUERY_STORE = ON
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30), DATA_FLUSH_INTERVAL_SECONDS = 900, INTERVAL_LENGTH_MINUTES = 60, MAX_STORAGE_SIZE_MB = 1000, QUERY_CAPTURE_MODE = AUTO, SIZE_BASED_CLEANUP_MODE = AUTO, MAX_PLANS_PER_QUERY = 200, WAIT_STATS_CAPTURE_MODE = ON)
GO
USE [ClinicaMariaInmaculada]
GO
/****** Object:  User [ADMIN]    Script Date: 09/10/2025 17:08:51 ******/
CREATE USER [ADMIN] WITHOUT LOGIN WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_owner] ADD MEMBER [ADMIN]
GO
ALTER ROLE [db_datareader] ADD MEMBER [ADMIN]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [ADMIN]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_CalcularEdad]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fn_CalcularEdad](@fecha_nacimiento DATE)
RETURNS INT
AS
BEGIN
    DECLARE @edad INT;
    SET @edad = DATEDIFF(YEAR, @fecha_nacimiento, GETDATE());
    
    -- Ajustar si no ha cumplido años este año
    IF (DATEADD(YEAR, @edad, @fecha_nacimiento) > GETDATE())
        SET @edad = @edad - 1;
    
    RETURN @edad;
END

GO
/****** Object:  Table [dbo].[Pacientes]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Pacientes](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Nombre] [varchar](100) NOT NULL,
	[Apellido_Paterno] [varchar](100) NOT NULL,
	[Apellido_Materno] [varchar](100) NOT NULL,
	[Cedula] [varchar](20) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[vw_Pacientes_ConEdad]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vw_Pacientes_ConEdad] AS
SELECT 
    id,
    Nombre,
    Apellido_Paterno,
    Apellido_Materno,
    Cedula,
    Fecha_Nacimiento,
    dbo.fn_CalcularEdad(Fecha_Nacimiento) AS Edad
FROM Pacientes;

GO
/****** Object:  Table [dbo].[CierreCaja]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CierreCaja](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Fecha] [date] NOT NULL,
	[HoraInicio] [time](7) NOT NULL,
	[HoraFin] [time](7) NOT NULL,
	[EfectivoReal] [decimal](10, 2) NOT NULL,
	[SaldoTeorico] [decimal](10, 2) NOT NULL,
	[Diferencia] [decimal](10, 2) NOT NULL,
	[IdUsuario] [int] NOT NULL,
	[FechaCierre] [datetime] NULL,
	[Observaciones] [text] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UC_CierresCaja_FechaHora] UNIQUE NONCLUSTERED 
(
	[Fecha] ASC,
	[HoraInicio] ASC,
	[HoraFin] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Compra]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Compra](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Id_Proveedor] [int] NOT NULL,
	[Id_Usuario] [int] NOT NULL,
	[Fecha] [datetime] NOT NULL,
	[Total] [decimal](12, 2) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Consultas]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Consultas](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Id_Usuario] [int] NOT NULL,
	[Id_Paciente] [int] NOT NULL,
	[Id_Especialidad] [int] NOT NULL,
	[Fecha] [datetime] NOT NULL,
	[Detalles] [text] NOT NULL,
	[Tipo_Consulta] [varchar](20) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DetalleCompra]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DetalleCompra](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Id_Compra] [int] NOT NULL,
	[Id_Lote] [int] NOT NULL,
	[Cantidad_Unitario] [int] NOT NULL,
	[Precio_Unitario] [decimal](10, 2) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DetallesVentas]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DetallesVentas](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Id_Venta] [int] NOT NULL,
	[Id_Lote] [int] NOT NULL,
	[Cantidad_Unitario] [int] NOT NULL,
	[Precio_Unitario] [decimal](10, 2) NOT NULL,
	[Detalles] [text] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Doctores]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Doctores](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Nombre] [varchar](100) NOT NULL,
	[Apellido_Paterno] [varchar](100) NOT NULL,
	[Apellido_Materno] [varchar](100) NOT NULL,
	[Especialidad] [varchar](150) NOT NULL,
	[Matricula] [varchar](50) NOT NULL,
	[Edad] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Matricula] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Enfermeria]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Enfermeria](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Id_Paciente] [int] NOT NULL,
	[Id_Procedimiento] [int] NOT NULL,
	[Cantidad] [int] NOT NULL,
	[Fecha] [datetime] NOT NULL,
	[Id_RegistradoPor] [int] NOT NULL,
	[Id_Trabajador] [int] NULL,
	[Tipo] [varchar](50) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Especialidad]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Especialidad](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Nombre] [varchar](150) NOT NULL,
	[Detalles] [varchar](500) NULL,
	[Precio_Normal] [decimal](10, 2) NOT NULL,
	[Precio_Emergencia] [decimal](10, 2) NOT NULL,
	[Id_Doctor] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Gastos]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Gastos](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[ID_Tipo] [int] NOT NULL,
	[Descripcion] [varchar](500) NOT NULL,
	[Monto] [decimal](12, 2) NOT NULL,
	[Fecha] [datetime] NOT NULL,
	[Id_RegistradoPor] [int] NOT NULL,
	[ID_Proveedor] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[IngresosExtras]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IngresosExtras](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[descripcion] [varchar](500) NOT NULL,
	[monto] [decimal](10, 2) NOT NULL,
	[fecha] [datetime] NULL,
	[id_registradoPor] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Laboratorio]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Laboratorio](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Id_Paciente] [int] NOT NULL,
	[Id_Trabajador] [int] NULL,
	[Id_Tipo_Analisis] [int] NULL,
	[Fecha] [datetime] NOT NULL,
	[Id_RegistradoPor] [int] NOT NULL,
	[Tipo] [varchar](50) NOT NULL,
	[Detalles] [varchar](500) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Lote]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Lote](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Id_Producto] [int] NOT NULL,
	[Cantidad_Unitario] [int] NOT NULL,
	[Fecha_Vencimiento] [date] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Marca]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Marca](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Nombre] [varchar](150) NOT NULL,
	[Detalles] [varchar](500) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Productos]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Productos](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Codigo] [varchar](50) NOT NULL,
	[Nombre] [varchar](200) NOT NULL,
	[Detalles] [varchar](500) NULL,
	[Precio_compra] [decimal](10, 2) NOT NULL,
	[Precio_venta] [decimal](10, 2) NOT NULL,
	[Stock_Unitario] [int] NOT NULL,
	[Unidad_Medida] [varchar](50) NOT NULL,
	[ID_Marca] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Codigo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Proveedor]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Proveedor](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Nombre] [varchar](200) NOT NULL,
	[Direccion] [varchar](300) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Proveedor_Gastos]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Proveedor_Gastos](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Nombre] [nvarchar](200) NOT NULL,
	[Frecuencia_Uso] [int] NULL,
	[Estado] [bit] NULL,
	[Fecha_Creacion] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Nombre] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Roles]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Roles](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Nombre] [varchar](100) NOT NULL,
	[Descripcion] [varchar](300) NULL,
	[Estado] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Nombre] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Tipo_Gastos]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Tipo_Gastos](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Nombre] [varchar](150) NOT NULL,
	[descripcion] [nvarchar](500) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Tipo_Trabajadores]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Tipo_Trabajadores](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Tipo] [varchar](100) NOT NULL,
	[descripcion] [nvarchar](255) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Tipos_Analisis]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Tipos_Analisis](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Nombre] [varchar](200) NOT NULL,
	[Descripcion] [varchar](500) NULL,
	[Precio_Normal] [decimal](10, 2) NOT NULL,
	[Precio_Emergencia] [decimal](10, 2) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Tipos_Procedimientos]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Tipos_Procedimientos](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Nombre] [varchar](200) NOT NULL,
	[Descripcion] [varchar](500) NULL,
	[Precio_Normal] [decimal](10, 2) NOT NULL,
	[Precio_Emergencia] [decimal](10, 2) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Trabajadores]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Trabajadores](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Nombre] [varchar](100) NOT NULL,
	[Apellido_Paterno] [varchar](100) NOT NULL,
	[Apellido_Materno] [varchar](100) NOT NULL,
	[Id_Tipo_Trabajador] [int] NOT NULL,
	[Matricula] [varchar](50) NULL,
	[Especialidad] [varchar](150) NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Usuario]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Usuario](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Nombre] [varchar](100) NOT NULL,
	[Apellido_Paterno] [varchar](100) NOT NULL,
	[Apellido_Materno] [varchar](100) NOT NULL,
	[contrasena] [varchar](255) NOT NULL,
	[Id_Rol] [int] NOT NULL,
	[Estado] [bit] NULL,
	[nombre_usuario] [varchar](50) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UK_Usuario_NombreUsuario] UNIQUE NONCLUSTERED 
(
	[nombre_usuario] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Ventas]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Ventas](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[Id_Usuario] [int] NOT NULL,
	[Fecha] [datetime] NOT NULL,
	[Total] [decimal](12, 2) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Index [IX_Gastos_IDProveedor]    Script Date: 09/10/2025 17:08:52 ******/
CREATE NONCLUSTERED INDEX [IX_Gastos_IDProveedor] ON [dbo].[Gastos]
(
	[ID_Proveedor] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_Pacientes_Cedula]    Script Date: 09/10/2025 17:08:52 ******/
CREATE NONCLUSTERED INDEX [IX_Pacientes_Cedula] ON [dbo].[Pacientes]
(
	[Cedula] ASC
)
WHERE ([Cedula] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_ProveedorGastos_Estado]    Script Date: 09/10/2025 17:08:52 ******/
CREATE NONCLUSTERED INDEX [IX_ProveedorGastos_Estado] ON [dbo].[Proveedor_Gastos]
(
	[Estado] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_ProveedorGastos_Nombre]    Script Date: 09/10/2025 17:08:52 ******/
CREATE NONCLUSTERED INDEX [IX_ProveedorGastos_Nombre] ON [dbo].[Proveedor_Gastos]
(
	[Nombre] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[CierreCaja] ADD  DEFAULT (getdate()) FOR [FechaCierre]
GO
ALTER TABLE [dbo].[Compra] ADD  DEFAULT (getdate()) FOR [Fecha]
GO
ALTER TABLE [dbo].[Consultas] ADD  DEFAULT (getdate()) FOR [Fecha]
GO
ALTER TABLE [dbo].[Consultas] ADD  DEFAULT ('Normal') FOR [Tipo_Consulta]
GO
ALTER TABLE [dbo].[DetalleCompra] ADD  DEFAULT ((0)) FOR [Cantidad_Unitario]
GO
ALTER TABLE [dbo].[Enfermeria] ADD  DEFAULT ((1)) FOR [Cantidad]
GO
ALTER TABLE [dbo].[Enfermeria] ADD  DEFAULT (getdate()) FOR [Fecha]
GO
ALTER TABLE [dbo].[Enfermeria] ADD  DEFAULT ('Normal') FOR [Tipo]
GO
ALTER TABLE [dbo].[Gastos] ADD  DEFAULT (getdate()) FOR [Fecha]
GO
ALTER TABLE [dbo].[IngresosExtras] ADD  CONSTRAINT [DF_IngresosExtras_fecha]  DEFAULT (getdate()) FOR [fecha]
GO
ALTER TABLE [dbo].[Laboratorio] ADD  DEFAULT (getdate()) FOR [Fecha]
GO
ALTER TABLE [dbo].[Laboratorio] ADD  DEFAULT ((1)) FOR [Id_RegistradoPor]
GO
ALTER TABLE [dbo].[Laboratorio] ADD  DEFAULT ('Normal') FOR [Tipo]
GO
ALTER TABLE [dbo].[Lote] ADD  DEFAULT ((0)) FOR [Cantidad_Unitario]
GO
ALTER TABLE [dbo].[Proveedor_Gastos] ADD  DEFAULT ((0)) FOR [Frecuencia_Uso]
GO
ALTER TABLE [dbo].[Proveedor_Gastos] ADD  DEFAULT ((1)) FOR [Estado]
GO
ALTER TABLE [dbo].[Proveedor_Gastos] ADD  DEFAULT (getdate()) FOR [Fecha_Creacion]
GO
ALTER TABLE [dbo].[Roles] ADD  DEFAULT ((1)) FOR [Estado]
GO
ALTER TABLE [dbo].[Usuario] ADD  DEFAULT ((1)) FOR [Estado]
GO
ALTER TABLE [dbo].[Ventas] ADD  DEFAULT (getdate()) FOR [Fecha]
GO
ALTER TABLE [dbo].[CierreCaja]  WITH CHECK ADD  CONSTRAINT [FK_CierresCaja_Usuario] FOREIGN KEY([IdUsuario])
REFERENCES [dbo].[Usuario] ([id])
GO
ALTER TABLE [dbo].[CierreCaja] CHECK CONSTRAINT [FK_CierresCaja_Usuario]
GO
ALTER TABLE [dbo].[Compra]  WITH CHECK ADD FOREIGN KEY([Id_Proveedor])
REFERENCES [dbo].[Proveedor] ([id])
GO
ALTER TABLE [dbo].[Compra]  WITH CHECK ADD FOREIGN KEY([Id_Usuario])
REFERENCES [dbo].[Usuario] ([id])
GO
ALTER TABLE [dbo].[Consultas]  WITH NOCHECK ADD FOREIGN KEY([Id_Especialidad])
REFERENCES [dbo].[Especialidad] ([id])
GO
ALTER TABLE [dbo].[Consultas]  WITH NOCHECK ADD FOREIGN KEY([Id_Paciente])
REFERENCES [dbo].[Pacientes] ([id])
GO
ALTER TABLE [dbo].[Consultas]  WITH NOCHECK ADD FOREIGN KEY([Id_Usuario])
REFERENCES [dbo].[Usuario] ([id])
GO
ALTER TABLE [dbo].[DetalleCompra]  WITH NOCHECK ADD FOREIGN KEY([Id_Compra])
REFERENCES [dbo].[Compra] ([id])
GO
ALTER TABLE [dbo].[DetalleCompra]  WITH NOCHECK ADD FOREIGN KEY([Id_Lote])
REFERENCES [dbo].[Lote] ([id])
GO
ALTER TABLE [dbo].[DetallesVentas]  WITH NOCHECK ADD FOREIGN KEY([Id_Lote])
REFERENCES [dbo].[Lote] ([id])
GO
ALTER TABLE [dbo].[DetallesVentas]  WITH NOCHECK ADD FOREIGN KEY([Id_Venta])
REFERENCES [dbo].[Ventas] ([id])
GO
ALTER TABLE [dbo].[Enfermeria]  WITH CHECK ADD  CONSTRAINT [FK_Enfermeria_Paciente] FOREIGN KEY([Id_Paciente])
REFERENCES [dbo].[Pacientes] ([id])
GO
ALTER TABLE [dbo].[Enfermeria] CHECK CONSTRAINT [FK_Enfermeria_Paciente]
GO
ALTER TABLE [dbo].[Enfermeria]  WITH CHECK ADD  CONSTRAINT [FK_Enfermeria_Procedimiento] FOREIGN KEY([Id_Procedimiento])
REFERENCES [dbo].[Tipos_Procedimientos] ([id])
GO
ALTER TABLE [dbo].[Enfermeria] CHECK CONSTRAINT [FK_Enfermeria_Procedimiento]
GO
ALTER TABLE [dbo].[Enfermeria]  WITH CHECK ADD  CONSTRAINT [FK_Enfermeria_Trabajador] FOREIGN KEY([Id_Trabajador])
REFERENCES [dbo].[Trabajadores] ([id])
GO
ALTER TABLE [dbo].[Enfermeria] CHECK CONSTRAINT [FK_Enfermeria_Trabajador]
GO
ALTER TABLE [dbo].[Enfermeria]  WITH CHECK ADD  CONSTRAINT [FK_Enfermeria_Usuario] FOREIGN KEY([Id_RegistradoPor])
REFERENCES [dbo].[Usuario] ([id])
GO
ALTER TABLE [dbo].[Enfermeria] CHECK CONSTRAINT [FK_Enfermeria_Usuario]
GO
ALTER TABLE [dbo].[Especialidad]  WITH CHECK ADD FOREIGN KEY([Id_Doctor])
REFERENCES [dbo].[Doctores] ([id])
GO
ALTER TABLE [dbo].[Gastos]  WITH CHECK ADD FOREIGN KEY([Id_RegistradoPor])
REFERENCES [dbo].[Usuario] ([id])
GO
ALTER TABLE [dbo].[Gastos]  WITH CHECK ADD FOREIGN KEY([ID_Tipo])
REFERENCES [dbo].[Tipo_Gastos] ([id])
GO
ALTER TABLE [dbo].[Gastos]  WITH CHECK ADD  CONSTRAINT [FK_Gastos_ProveedorGastos] FOREIGN KEY([ID_Proveedor])
REFERENCES [dbo].[Proveedor_Gastos] ([id])
GO
ALTER TABLE [dbo].[Gastos] CHECK CONSTRAINT [FK_Gastos_ProveedorGastos]
GO
ALTER TABLE [dbo].[IngresosExtras]  WITH CHECK ADD FOREIGN KEY([id_registradoPor])
REFERENCES [dbo].[Usuario] ([id])
GO
ALTER TABLE [dbo].[Laboratorio]  WITH NOCHECK ADD FOREIGN KEY([Id_Paciente])
REFERENCES [dbo].[Pacientes] ([id])
GO
ALTER TABLE [dbo].[Laboratorio]  WITH NOCHECK ADD FOREIGN KEY([Id_Trabajador])
REFERENCES [dbo].[Trabajadores] ([id])
GO
ALTER TABLE [dbo].[Laboratorio]  WITH CHECK ADD  CONSTRAINT [FK_Laboratorio_TipoAnalisis] FOREIGN KEY([Id_Tipo_Analisis])
REFERENCES [dbo].[Tipos_Analisis] ([id])
GO
ALTER TABLE [dbo].[Laboratorio] CHECK CONSTRAINT [FK_Laboratorio_TipoAnalisis]
GO
ALTER TABLE [dbo].[Laboratorio]  WITH CHECK ADD  CONSTRAINT [FK_Laboratorio_Usuario] FOREIGN KEY([Id_RegistradoPor])
REFERENCES [dbo].[Usuario] ([id])
GO
ALTER TABLE [dbo].[Laboratorio] CHECK CONSTRAINT [FK_Laboratorio_Usuario]
GO
ALTER TABLE [dbo].[Lote]  WITH CHECK ADD FOREIGN KEY([Id_Producto])
REFERENCES [dbo].[Productos] ([id])
GO
ALTER TABLE [dbo].[Productos]  WITH CHECK ADD FOREIGN KEY([ID_Marca])
REFERENCES [dbo].[Marca] ([id])
GO
ALTER TABLE [dbo].[Trabajadores]  WITH CHECK ADD FOREIGN KEY([Id_Tipo_Trabajador])
REFERENCES [dbo].[Tipo_Trabajadores] ([id])
GO
ALTER TABLE [dbo].[Usuario]  WITH NOCHECK ADD  CONSTRAINT [FK_Usuario_Rol] FOREIGN KEY([Id_Rol])
REFERENCES [dbo].[Roles] ([id])
GO
ALTER TABLE [dbo].[Usuario] CHECK CONSTRAINT [FK_Usuario_Rol]
GO
ALTER TABLE [dbo].[Ventas]  WITH CHECK ADD FOREIGN KEY([Id_Usuario])
REFERENCES [dbo].[Usuario] ([id])
GO
ALTER TABLE [dbo].[Compra]  WITH CHECK ADD CHECK  (([Total]>=(0)))
GO
ALTER TABLE [dbo].[DetalleCompra]  WITH NOCHECK ADD CHECK  (([Cantidad_Unitario]>=(0)))
GO
ALTER TABLE [dbo].[DetalleCompra]  WITH NOCHECK ADD CHECK  (([Precio_Unitario]>=(0)))
GO
ALTER TABLE [dbo].[DetallesVentas]  WITH NOCHECK ADD CHECK  (([Cantidad_Unitario]>(0)))
GO
ALTER TABLE [dbo].[DetallesVentas]  WITH NOCHECK ADD CHECK  (([Precio_Unitario]>=(0)))
GO
ALTER TABLE [dbo].[Doctores]  WITH CHECK ADD CHECK  (([Edad]>=(18) AND [Edad]<=(80)))
GO
ALTER TABLE [dbo].[Enfermeria]  WITH CHECK ADD CHECK  (([Cantidad]>(0)))
GO
ALTER TABLE [dbo].[Enfermeria]  WITH CHECK ADD CHECK  (([Tipo]='Emergencia' OR [Tipo]='Normal'))
GO
ALTER TABLE [dbo].[Especialidad]  WITH CHECK ADD CHECK  (([Precio_Normal]>=(0)))
GO
ALTER TABLE [dbo].[Especialidad]  WITH CHECK ADD CHECK  (([Precio_Emergencia]>=(0)))
GO
ALTER TABLE [dbo].[Gastos]  WITH CHECK ADD CHECK  (([Monto]>=(0)))
GO
ALTER TABLE [dbo].[IngresosExtras]  WITH CHECK ADD CHECK  (([monto]>=(0)))
GO
ALTER TABLE [dbo].[Laboratorio]  WITH CHECK ADD CHECK  (([Tipo]='Emergencia' OR [Tipo]='Normal'))
GO
ALTER TABLE [dbo].[Lote]  WITH CHECK ADD CHECK  (([Cantidad_Unitario]>=(0)))
GO
ALTER TABLE [dbo].[Pacientes]  WITH CHECK ADD  CONSTRAINT [CK_Pacientes_Cedula_Formato] CHECK  (([Cedula] IS NULL OR len([CEDULA])>=(5) AND NOT [CEDULA] like '%[^0-9]%'))
GO
ALTER TABLE [dbo].[Pacientes] CHECK CONSTRAINT [CK_Pacientes_Cedula_Formato]
GO
ALTER TABLE [dbo].[Productos]  WITH CHECK ADD CHECK  (([Precio_compra]>=(0)))
GO
ALTER TABLE [dbo].[Productos]  WITH CHECK ADD CHECK  (([Precio_venta]>=(0)))
GO
ALTER TABLE [dbo].[Productos]  WITH CHECK ADD CHECK  (([Stock_Unitario]>=(0)))
GO
ALTER TABLE [dbo].[Tipos_Analisis]  WITH CHECK ADD CHECK  (([Precio_Normal]>=(0)))
GO
ALTER TABLE [dbo].[Tipos_Analisis]  WITH CHECK ADD CHECK  (([Precio_Emergencia]>=(0)))
GO
ALTER TABLE [dbo].[Tipos_Procedimientos]  WITH CHECK ADD CHECK  (([Precio_Normal]>=(0)))
GO
ALTER TABLE [dbo].[Tipos_Procedimientos]  WITH CHECK ADD CHECK  (([Precio_Emergencia]>=(0)))
GO
ALTER TABLE [dbo].[Ventas]  WITH CHECK ADD CHECK  (([Total]>=(0)))
GO
/****** Object:  StoredProcedure [dbo].[sp_UpsertPaciente]    Script Date: 09/10/2025 17:08:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_UpsertPaciente]
    @Nombre VARCHAR(100),
    @Apellido_Paterno VARCHAR(100), 
    @Apellido_Materno VARCHAR(100),
    @Fecha_Nacimiento DATE,
    @Cedula VARCHAR(20) = NULL,
    @Id INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Verificar si existe por cédula (si se proporciona)
    IF @Cedula IS NOT NULL
    BEGIN
        SELECT @Id = id FROM Pacientes WHERE Cedula = @Cedula;
    END
    
    -- Si no existe, buscar por nombre completo
    IF @Id IS NULL
    BEGIN
        SELECT @Id = id FROM Pacientes 
        WHERE Nombre = @Nombre 
        AND Apellido_Paterno = @Apellido_Paterno
        AND Apellido_Materno = @Apellido_Materno;
    END
    
    IF @Id IS NULL
    BEGIN
        -- Crear nuevo paciente
        INSERT INTO Pacientes (Nombre, Apellido_Paterno, Apellido_Materno, Fecha_Nacimiento, Cedula)
        VALUES (@Nombre, @Apellido_Paterno, @Apellido_Materno, @Fecha_Nacimiento, @Cedula);
        
        SET @Id = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        -- Actualizar paciente existente
        UPDATE Pacientes 
        SET Fecha_Nacimiento = @Fecha_Nacimiento,
            Cedula = COALESCE(@Cedula, Cedula)
        WHERE id = @Id;
    END
END

GO
USE [master]
GO
ALTER DATABASE [ClinicaMariaInmaculada] SET  READ_WRITE 
GO
