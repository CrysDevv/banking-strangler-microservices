/* =============================================================================
   stored_procedures.sql - sp_EjecutarTransferencia
   - Aislamiento SERIALIZABLE (alcance: solo dentro del procedimiento).
   - Bloqueo de cuentas en orden determinista (NumeroCuenta ascendente) para
     evitar deadlocks entre transferencias cruzadas (A->B vs B->A).
   - Idempotencia por IdempotencyKey (reintentos devuelven el resultado original).
   - Escribe Transferencias + 2 Movimientos + 1 OutboxEvento en UNA transaccion
     (Transactional Outbox).
   - Errores de dominio via THROW 500xx (ver schema.sql). Ante 1205 (deadlock)
     el llamador debe reintentar.
   ============================================================================= */
USE BankingCore;
GO

CREATE OR ALTER PROCEDURE dbo.sp_EjecutarTransferencia
    @IdempotencyKey  VARCHAR(64),
    @CuentaOrigen    VARCHAR(20),
    @CuentaDestino   VARCHAR(20),
    @Monto           DECIMAL(18,2),
    @Glosa           NVARCHAR(200) = NULL,
    @CorrelationId   VARCHAR(64)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    /* ---- Validaciones de entrada (sin transaccion abierta) ---- */
    IF @IdempotencyKey IS NULL OR LTRIM(RTRIM(@IdempotencyKey)) = ''
        THROW 50010, N'La clave de idempotencia es obligatoria.', 1;
    IF @Monto IS NULL OR @Monto <= 0
        THROW 50001, N'El monto debe ser mayor que cero.', 1;
    IF @CuentaOrigen IS NULL OR @CuentaDestino IS NULL OR @CuentaOrigen = @CuentaDestino
        THROW 50002, N'La cuenta de origen y destino deben ser distintas.', 1;

    DECLARE @TransferenciaId UNIQUEIDENTIFIER = NEWID();
    DECLARE @Ahora           DATETIME2(3)     = SYSUTCDATETIME();
    DECLARE @OrigenId BIGINT, @DestinoId BIGINT, @Tmp BIGINT;
    DECLARE @SaldoOrigen DECIMAL(18,2), @SaldoDestino DECIMAL(18,2);
    DECLARE @EstadoOrigen VARCHAR(10), @EstadoDestino VARCHAR(10);
    DECLARE @MonedaOrigen CHAR(3), @MonedaDestino CHAR(3);
    DECLARE @Primero VARCHAR(20), @Segundo VARCHAR(20);
    DECLARE @ExId UNIQUEIDENTIFIER, @ExMonto DECIMAL(18,2), @ExOrigenId BIGINT, @ExDestinoId BIGINT;
    DECLARE @Payload NVARCHAR(MAX);

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ---- Idempotencia: lock de rango sobre la clave ---- */
        SELECT @ExId = t.TransferenciaId, @ExMonto = t.Monto,
               @ExOrigenId = t.CuentaOrigenId, @ExDestinoId = t.CuentaDestinoId
          FROM dbo.Transferencias AS t WITH (UPDLOCK, HOLDLOCK)
         WHERE t.IdempotencyKey = @IdempotencyKey;

        IF @ExId IS NOT NULL
        BEGIN
            IF @ExMonto <> @Monto
               OR NOT EXISTS (SELECT 1
                                FROM dbo.Cuentas AS co, dbo.Cuentas AS cd
                               WHERE co.CuentaId = @ExOrigenId  AND co.NumeroCuenta = @CuentaOrigen
                                 AND cd.CuentaId = @ExDestinoId AND cd.NumeroCuenta = @CuentaDestino)
                THROW 50009, N'La clave de idempotencia ya fue usada con parametros distintos.', 1;

            COMMIT TRANSACTION;

            SELECT t.TransferenciaId,
                   t.Estado,
                   (SELECT m.SaldoPosterior FROM dbo.Movimientos m WHERE m.TransferenciaId = t.TransferenciaId AND m.Tipo = 'DEBITO')  AS SaldoOrigen,
                   (SELECT m.SaldoPosterior FROM dbo.Movimientos m WHERE m.TransferenciaId = t.TransferenciaId AND m.Tipo = 'CREDITO') AS SaldoDestino,
                   CAST(1 AS BIT) AS Replay,
                   t.FechaCreacion
              FROM dbo.Transferencias AS t
             WHERE t.TransferenciaId = @ExId;
            RETURN;
        END

        /* ---- Bloqueo ordenado de ambas cuentas (previene deadlocks) ---- */
        SET @Primero = CASE WHEN @CuentaOrigen < @CuentaDestino THEN @CuentaOrigen  ELSE @CuentaDestino END;
        SET @Segundo = CASE WHEN @CuentaOrigen < @CuentaDestino THEN @CuentaDestino ELSE @CuentaOrigen  END;

        SELECT @Tmp = CuentaId FROM dbo.Cuentas WITH (UPDLOCK, HOLDLOCK) WHERE NumeroCuenta = @Primero;
        SELECT @Tmp = CuentaId FROM dbo.Cuentas WITH (UPDLOCK, HOLDLOCK) WHERE NumeroCuenta = @Segundo;

        SELECT @OrigenId = CuentaId, @SaldoOrigen = Saldo, @EstadoOrigen = Estado, @MonedaOrigen = Moneda
          FROM dbo.Cuentas WHERE NumeroCuenta = @CuentaOrigen;
        SELECT @DestinoId = CuentaId, @SaldoDestino = Saldo, @EstadoDestino = Estado, @MonedaDestino = Moneda
          FROM dbo.Cuentas WHERE NumeroCuenta = @CuentaDestino;

        IF @OrigenId  IS NULL THROW 50003, N'La cuenta de origen no existe.', 1;
        IF @DestinoId IS NULL THROW 50004, N'La cuenta de destino no existe.', 1;
        IF @EstadoOrigen  <> 'ACTIVA' THROW 50005, N'La cuenta de origen no esta activa.', 1;
        IF @EstadoDestino <> 'ACTIVA' THROW 50006, N'La cuenta de destino no esta activa.', 1;
        IF @MonedaOrigen  <> @MonedaDestino THROW 50007, N'Las cuentas operan en monedas distintas.', 1;
        IF @SaldoOrigen < @Monto THROW 50008, N'Saldo insuficiente en la cuenta de origen.', 1;

        SET @SaldoOrigen  = @SaldoOrigen  - @Monto;
        SET @SaldoDestino = @SaldoDestino + @Monto;

        UPDATE dbo.Cuentas SET Saldo = @SaldoOrigen  WHERE CuentaId = @OrigenId;
        UPDATE dbo.Cuentas SET Saldo = @SaldoDestino WHERE CuentaId = @DestinoId;

        INSERT dbo.Transferencias
            (TransferenciaId, IdempotencyKey, CuentaOrigenId, CuentaDestinoId, Monto, Moneda, Glosa, Estado, CorrelationId, FechaCreacion)
        VALUES
            (@TransferenciaId, @IdempotencyKey, @OrigenId, @DestinoId, @Monto, @MonedaOrigen, @Glosa, 'COMPLETADA', @CorrelationId, @Ahora);

        INSERT dbo.Movimientos
            (TransferenciaId, CuentaId, Tipo, Monto, SaldoPosterior, Glosa, CorrelationId, FechaMovimiento)
        VALUES
            (@TransferenciaId, @OrigenId,  'DEBITO',  @Monto, @SaldoOrigen,  @Glosa, @CorrelationId, @Ahora),
            (@TransferenciaId, @DestinoId, 'CREDITO', @Monto, @SaldoDestino, @Glosa, @CorrelationId, @Ahora);

        /* ---- Transactional Outbox: mismo commit que el cambio de estado ---- */
        SET @Payload =
        (
            SELECT @TransferenciaId AS transferenciaId,
                   @CuentaOrigen    AS cuentaOrigen,
                   @CuentaDestino   AS cuentaDestino,
                   @Monto           AS monto,
                   @MonedaOrigen    AS moneda,
                   @Glosa           AS glosa,
                   @SaldoOrigen     AS saldoOrigen,
                   @SaldoDestino    AS saldoDestino,
                   @CorrelationId   AS correlationId,
                   CONVERT(VARCHAR(30), @Ahora, 127) + 'Z' AS fecha
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        INSERT dbo.OutboxEventos (AggregateType, AggregateId, EventType, Payload, CorrelationId)
        VALUES ('Transferencia', CAST(@TransferenciaId AS VARCHAR(36)), 'TransferenciaRealizada', @Payload, @CorrelationId);

        COMMIT TRANSACTION;

        SELECT @TransferenciaId AS TransferenciaId,
               CAST('COMPLETADA' AS VARCHAR(12)) AS Estado,
               @SaldoOrigen  AS SaldoOrigen,
               @SaldoDestino AS SaldoDestino,
               CAST(0 AS BIT) AS Replay,
               @Ahora AS FechaCreacion;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

GRANT EXECUTE ON dbo.sp_EjecutarTransferencia TO banking_app;
GO
