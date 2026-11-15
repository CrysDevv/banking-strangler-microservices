/* =============================================================================
   seed.sql - Datos semilla (idempotente: solo corre si Clientes esta vacia)
   Los RUT se generan con dbo.fn_CalcularDvRut => siempre son validos.
   Escenarios de prueba incluidos: saldo bajo, cuenta BLOQUEADA, cuenta USD.
   ============================================================================= */
USE BankingCore;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Clientes)
BEGIN
    SET NOCOUNT ON;

    INSERT dbo.Clientes (Rut, Nombre, Email, Telefono)
    SELECT CONCAT(v.Cuerpo, '-', dbo.fn_CalcularDvRut(v.Cuerpo)), v.Nombre, v.Email, v.Telefono
      FROM (VALUES
        (11222333, N'María Fernanda González Soto',    'maria.gonzalez@ejemplo.cl',   '+56911110001'),
        (15678901, N'Juan Pablo Muñoz Araya',          'juan.munoz@ejemplo.cl',       '+56911110002'),
        (17890123, N'Camila Andrea Rojas Pizarro',     'camila.rojas@ejemplo.cl',     '+56911110003'),
        (19456789, N'Diego Alejandro Fuentes Vera',    'diego.fuentes@ejemplo.cl',    '+56911110004'),
        (20123456, N'Valentina Ignacia Contreras Díaz','valentina.contreras@ejemplo.cl','+56911110005'),
        (8765432,  N'Sergio Antonio Pérez Lagos',      'sergio.perez@ejemplo.cl',     '+56911110006'),
        (12987654, N'Carolina Beatriz Núñez Tapia',    'carolina.nunez@ejemplo.cl',   '+56911110007'),
        (22333444, N'Matías Esteban Silva Orellana',   'matias.silva@ejemplo.cl',     '+56911110008'),
        (76123456, N'Comercial Los Andes SpA',         'tesoreria@losandes.cl',       '+56222220009')
      ) AS v (Cuerpo, Nombre, Email, Telefono);

    INSERT dbo.Cuentas (NumeroCuenta, ClienteId, Tipo, Moneda, Saldo, Estado)
    SELECT v.Numero, c.ClienteId, v.Tipo, v.Moneda, v.Saldo, v.Estado
      FROM (VALUES
        ('0000100001', 11222333, 'CORRIENTE', 'CLP',  5000000.00, 'ACTIVA'),
        ('0000100002', 11222333, 'AHORRO',    'CLP', 12500000.00, 'ACTIVA'),
        ('0000200001', 15678901, 'CORRIENTE', 'CLP',   850000.00, 'ACTIVA'),
        ('0000300001', 17890123, 'VISTA',     'CLP',   250000.00, 'ACTIVA'),
        ('0000400001', 19456789, 'CORRIENTE', 'CLP',  3200000.00, 'ACTIVA'),
        ('0000500001', 20123456, 'AHORRO',    'CLP',  7800000.00, 'ACTIVA'),
        ('0000600001', 8765432,  'VISTA',     'CLP',    15000.00, 'ACTIVA'),
        ('0000700001', 12987654, 'CORRIENTE', 'CLP',  1000000.00, 'ACTIVA'),
        ('0000800001', 22333444, 'CORRIENTE', 'CLP',  2400000.00, 'BLOQUEADA'),
        ('0000900001', 76123456, 'CORRIENTE', 'CLP', 45000000.00, 'ACTIVA'),
        ('0000900002', 76123456, 'CORRIENTE', 'USD',    10000.00, 'ACTIVA')
      ) AS v (Numero, CuerpoRut, Tipo, Moneda, Saldo, Estado)
      JOIN dbo.Clientes AS c
        ON c.Rut = CONCAT(v.CuerpoRut, '-', dbo.fn_CalcularDvRut(v.CuerpoRut));

    /* Deposito inicial: cuadra el saldo sembrado con el libro de movimientos */
    INSERT dbo.Movimientos (TransferenciaId, CuentaId, Tipo, Monto, SaldoPosterior, Glosa, CorrelationId)
    SELECT NULL, CuentaId, 'CREDITO', Saldo, Saldo, N'Depósito inicial', 'seed-init'
      FROM dbo.Cuentas
     WHERE Saldo > 0;

    /* Transferencias historicas reales: generan Movimientos y eventos Outbox PENDIENTES */
    EXEC dbo.sp_EjecutarTransferencia @IdempotencyKey = 'seed-tx-001', @CuentaOrigen = '0000100001', @CuentaDestino = '0000200001', @Monto = 150000,  @Glosa = N'Pago arriendo',          @CorrelationId = 'seed-0001';
    EXEC dbo.sp_EjecutarTransferencia @IdempotencyKey = 'seed-tx-002', @CuentaOrigen = '0000200001', @CuentaDestino = '0000300001', @Monto = 45000,   @Glosa = N'Transferencia familiar', @CorrelationId = 'seed-0002';
    EXEC dbo.sp_EjecutarTransferencia @IdempotencyKey = 'seed-tx-003', @CuentaOrigen = '0000900001', @CuentaDestino = '0000500001', @Monto = 1200000, @Glosa = N'Pago honorarios',       @CorrelationId = 'seed-0003';
    EXEC dbo.sp_EjecutarTransferencia @IdempotencyKey = 'seed-tx-004', @CuentaOrigen = '0000500001', @CuentaDestino = '0000100002', @Monto = 300000,  @Glosa = N'Ahorro mensual',        @CorrelationId = 'seed-0004';
    EXEC dbo.sp_EjecutarTransferencia @IdempotencyKey = 'seed-tx-005', @CuentaOrigen = '0000400001', @CuentaDestino = '0000700001', @Monto = 80000,   @Glosa = N'Pago servicios',        @CorrelationId = 'seed-0005';

    DECLARE @ClientesCount INT, @CuentasCount INT, @MovimientosCount INT, @OutboxCount INT;
    SELECT @ClientesCount = COUNT(*) FROM dbo.Clientes;
    SELECT @CuentasCount = COUNT(*) FROM dbo.Cuentas;
    SELECT @MovimientosCount = COUNT(*) FROM dbo.Movimientos;
    SELECT @OutboxCount = COUNT(*) FROM dbo.OutboxEventos;

    PRINT CONCAT(
        'Seed completado: ', @ClientesCount, ' clientes, ',
        @CuentasCount, ' cuentas, ',
        @MovimientosCount, ' movimientos, ',
        @OutboxCount, ' eventos outbox.'
    );
END
ELSE
    PRINT 'Seed omitido: la base ya contiene datos.';
GO
