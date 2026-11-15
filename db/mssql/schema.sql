/* =============================================================================
   schema.sql - MS SQL Server 2022 - BankingCore
   Idempotente. Requiere sqlcmd con: -I (QUOTED_IDENTIFIER ON), -f 65001 (UTF-8)
   y la variable -v APP_DB_PASSWORD="..." (login de minimo privilegio).
   Codigos de error de dominio (THROW) usados por sp_EjecutarTransferencia:
     50001 monto invalido | 50002 origen=destino | 50003 origen inexistente
     50004 destino inexistente | 50005 origen no activa | 50006 destino no activa
     50007 monedas distintas | 50008 saldo insuficiente
     50009 conflicto de idempotencia | 50010 idempotency key ausente
   ============================================================================= */
SET NOCOUNT ON;
GO

IF DB_ID(N'BankingCore') IS NULL
BEGIN
    CREATE DATABASE BankingCore;
END
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'BankingCore' AND is_read_committed_snapshot_on = 0)
BEGIN
    ALTER DATABASE BankingCore SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
END
GO

/* Login de aplicacion (minimo privilegio): lectura directa, escritura solo via SP */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'banking_app')
BEGIN
    CREATE LOGIN banking_app
        WITH PASSWORD = N'$(APP_DB_PASSWORD)', CHECK_POLICY = OFF, DEFAULT_DATABASE = BankingCore;
END
GO

USE BankingCore;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'banking_app')
BEGIN
    CREATE USER banking_app FOR LOGIN banking_app WITH DEFAULT_SCHEMA = dbo;
END
GO

/* ------------------------- RUT chileno (modulo 11) ------------------------- */
IF OBJECT_ID(N'dbo.Clientes', N'U') IS NOT NULL
   AND EXISTS
       (SELECT 1
          FROM sys.check_constraints
         WHERE parent_object_id = OBJECT_ID(N'dbo.Clientes')
           AND name = N'CK_Clientes_Rut')
BEGIN
    ALTER TABLE dbo.Clientes DROP CONSTRAINT CK_Clientes_Rut;
END
GO

CREATE OR ALTER FUNCTION dbo.fn_CalcularDvRut (@Cuerpo INT)
RETURNS CHAR(1)
AS
BEGIN
    DECLARE @Suma INT = 0, @Mult INT = 2, @N INT = @Cuerpo, @R INT;
    WHILE @N > 0
    BEGIN
        SET @Suma = @Suma + (@N % 10) * @Mult;
        SET @N    = @N / 10;
        SET @Mult = CASE WHEN @Mult = 7 THEN 2 ELSE @Mult + 1 END;
    END
    SET @R = 11 - (@Suma % 11);
    RETURN CASE @R WHEN 11 THEN '0' WHEN 10 THEN 'K' ELSE CAST(@R AS CHAR(1)) END;
END
GO

/* Formato normalizado esperado: cuerpo-DV, sin puntos (ej. 11222333-K) */
CREATE OR ALTER FUNCTION dbo.fn_ValidarRut (@Rut VARCHAR(12))
RETURNS BIT
AS
BEGIN
    IF @Rut IS NULL RETURN 0;
    DECLARE @Pos INT = CHARINDEX('-', @Rut);
    IF @Pos < 2 RETURN 0;
    IF LEN(@Rut) <> @Pos + 1 RETURN 0;
    DECLARE @Cuerpo VARCHAR(12) = LEFT(@Rut, @Pos - 1);
    DECLARE @Dv CHAR(1) = UPPER(SUBSTRING(@Rut, @Pos + 1, 1));
    IF @Cuerpo LIKE '%[^0-9]%' RETURN 0;
    IF LEN(@Cuerpo) NOT BETWEEN 7 AND 8 RETURN 0;
    RETURN CASE WHEN dbo.fn_CalcularDvRut(CAST(@Cuerpo AS INT)) = @Dv THEN 1 ELSE 0 END;
END
GO

/* ------------------------------- Clientes ---------------------------------- */
IF OBJECT_ID(N'dbo.Clientes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Clientes
    (
        ClienteId      BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_Clientes PRIMARY KEY,
        Rut            VARCHAR(10)   NOT NULL CONSTRAINT UQ_Clientes_Rut UNIQUE
                                     CONSTRAINT CK_Clientes_Rut CHECK (dbo.fn_ValidarRut(Rut) = 1),
        Nombre         NVARCHAR(150) NOT NULL,
        Email          VARCHAR(150)  NOT NULL CONSTRAINT UQ_Clientes_Email UNIQUE,
        Telefono       VARCHAR(20)   NULL,
        FechaCreacion  DATETIME2(3)  NOT NULL CONSTRAINT DF_Clientes_Fecha DEFAULT SYSUTCDATETIME()
    );
END
GO

IF OBJECT_ID(N'dbo.Clientes', N'U') IS NOT NULL
   AND NOT EXISTS
       (SELECT 1
          FROM sys.check_constraints
         WHERE parent_object_id = OBJECT_ID(N'dbo.Clientes')
           AND name = N'CK_Clientes_Rut')
BEGIN
    ALTER TABLE dbo.Clientes WITH CHECK
        ADD CONSTRAINT CK_Clientes_Rut CHECK (dbo.fn_ValidarRut(Rut) = 1);
END
GO

/* -------------------------------- Cuentas ---------------------------------- */
IF OBJECT_ID(N'dbo.Cuentas', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Cuentas
    (
        CuentaId       BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_Cuentas PRIMARY KEY,
        NumeroCuenta   VARCHAR(20)   NOT NULL CONSTRAINT UQ_Cuentas_Numero UNIQUE
                                     CONSTRAINT CK_Cuentas_Numero CHECK (NumeroCuenta NOT LIKE '%[^0-9]%'),
        ClienteId      BIGINT        NOT NULL CONSTRAINT FK_Cuentas_Clientes REFERENCES dbo.Clientes (ClienteId),
        Tipo           VARCHAR(10)   NOT NULL CONSTRAINT CK_Cuentas_Tipo   CHECK (Tipo   IN ('CORRIENTE','VISTA','AHORRO')),
        Moneda         CHAR(3)       NOT NULL CONSTRAINT DF_Cuentas_Moneda DEFAULT 'CLP'
                                     CONSTRAINT CK_Cuentas_Moneda CHECK (Moneda IN ('CLP','USD')),
        Saldo          DECIMAL(18,2) NOT NULL CONSTRAINT DF_Cuentas_Saldo  DEFAULT 0
                                     CONSTRAINT CK_Cuentas_Saldo CHECK (Saldo >= 0),
        Estado         VARCHAR(10)   NOT NULL CONSTRAINT DF_Cuentas_Estado DEFAULT 'ACTIVA'
                                     CONSTRAINT CK_Cuentas_Estado CHECK (Estado IN ('ACTIVA','BLOQUEADA','CERRADA')),
        RowVer         ROWVERSION    NOT NULL,   -- concurrencia optimista (JPA @Version / lecturas condicionales)
        FechaCreacion  DATETIME2(3)  NOT NULL CONSTRAINT DF_Cuentas_Fecha DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_Cuentas_Cliente ON dbo.Cuentas (ClienteId);
END
GO

/* ----------------------------- Transferencias ------------------------------ */
IF OBJECT_ID(N'dbo.Transferencias', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Transferencias
    (
        TransferenciaId  UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Transferencias PRIMARY KEY,
        IdempotencyKey   VARCHAR(64)      NOT NULL CONSTRAINT UQ_Transferencias_Idem UNIQUE,
        CuentaOrigenId   BIGINT           NOT NULL CONSTRAINT FK_Transf_Origen  REFERENCES dbo.Cuentas (CuentaId),
        CuentaDestinoId  BIGINT           NOT NULL CONSTRAINT FK_Transf_Destino REFERENCES dbo.Cuentas (CuentaId),
        Monto            DECIMAL(18,2)    NOT NULL CONSTRAINT CK_Transf_Monto CHECK (Monto > 0),
        Moneda           CHAR(3)          NOT NULL,
        Glosa            NVARCHAR(200)    NULL,
        Estado           VARCHAR(12)      NOT NULL CONSTRAINT CK_Transf_Estado CHECK (Estado IN ('COMPLETADA','RECHAZADA')),
        CorrelationId    VARCHAR(64)      NULL,
        FechaCreacion    DATETIME2(3)     NOT NULL CONSTRAINT DF_Transf_Fecha DEFAULT SYSUTCDATETIME(),
        CONSTRAINT CK_Transf_CuentasDistintas CHECK (CuentaOrigenId <> CuentaDestinoId)
    );
END
GO

/* ------------------------------ Movimientos -------------------------------- */
IF OBJECT_ID(N'dbo.Movimientos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Movimientos
    (
        MovimientoId     BIGINT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_Movimientos PRIMARY KEY,
        TransferenciaId  UNIQUEIDENTIFIER NULL CONSTRAINT FK_Mov_Transferencia REFERENCES dbo.Transferencias (TransferenciaId),
        CuentaId         BIGINT           NOT NULL CONSTRAINT FK_Mov_Cuenta REFERENCES dbo.Cuentas (CuentaId),
        Tipo             VARCHAR(7)       NOT NULL CONSTRAINT CK_Mov_Tipo CHECK (Tipo IN ('DEBITO','CREDITO')),
        Monto            DECIMAL(18,2)    NOT NULL CONSTRAINT CK_Mov_Monto CHECK (Monto > 0),
        SaldoPosterior   DECIMAL(18,2)    NOT NULL,
        Glosa            NVARCHAR(200)    NULL,
        CorrelationId    VARCHAR(64)      NULL,
        FechaMovimiento  DATETIME2(3)     NOT NULL CONSTRAINT DF_Mov_Fecha DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_Movimientos_Cuenta_Fecha
        ON dbo.Movimientos (CuentaId, FechaMovimiento DESC)
        INCLUDE (Tipo, Monto, SaldoPosterior, Glosa);
    CREATE INDEX IX_Movimientos_Transferencia ON dbo.Movimientos (TransferenciaId) WHERE TransferenciaId IS NOT NULL;
END
GO

/* ----------------------------- OutboxEventos ------------------------------- */
IF OBJECT_ID(N'dbo.OutboxEventos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.OutboxEventos
    (
        SecuenciaId     BIGINT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_OutboxEventos PRIMARY KEY,
        EventoId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT UQ_Outbox_EventoId UNIQUE
                                         CONSTRAINT DF_Outbox_EventoId DEFAULT NEWID(),
        AggregateType   VARCHAR(50)      NOT NULL,
        AggregateId     VARCHAR(64)      NOT NULL,
        EventType       VARCHAR(100)     NOT NULL,
        Payload         NVARCHAR(MAX)    NOT NULL CONSTRAINT CK_Outbox_Payload CHECK (ISJSON(Payload) = 1),
        CorrelationId   VARCHAR(64)      NULL,
        Estado          VARCHAR(10)      NOT NULL CONSTRAINT DF_Outbox_Estado DEFAULT 'PENDIENTE'
                                         CONSTRAINT CK_Outbox_Estado CHECK (Estado IN ('PENDIENTE','PUBLICADO','FALLIDO')),
        Intentos        INT              NOT NULL CONSTRAINT DF_Outbox_Intentos DEFAULT 0,
        UltimoError     NVARCHAR(1000)   NULL,
        FechaCreacion   DATETIME2(3)     NOT NULL CONSTRAINT DF_Outbox_Fecha DEFAULT SYSUTCDATETIME(),
        FechaPublicado  DATETIME2(3)     NULL
    );
    -- Indice filtrado: el OutboxPoller (UPDLOCK, READPAST) solo recorre pendientes.
    CREATE INDEX IX_Outbox_Pendientes
        ON dbo.OutboxEventos (SecuenciaId)
        INCLUDE (EventoId, AggregateType, AggregateId, EventType, CorrelationId, Intentos)
        WHERE Estado = 'PENDIENTE';
END
GO

/* ------------- Permisos de minimo privilegio para banking_app --------------
   Escrituras sobre Cuentas/Movimientos/Transferencias/Outbox(insert) ocurren
   solo dentro de dbo.sp_EjecutarTransferencia (ownership chaining en dbo). */
GRANT SELECT ON dbo.Clientes        TO banking_app;
GRANT SELECT ON dbo.Cuentas         TO banking_app;
GRANT SELECT ON dbo.Movimientos     TO banking_app;
GRANT SELECT ON dbo.Transferencias  TO banking_app;
GRANT SELECT, UPDATE, DELETE ON dbo.OutboxEventos TO banking_app;
GO
