import { createServer } from 'node:http';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { BankingBffService } from './banking.service';
import { RedisService } from '../redis/redis.service';

describe('BankingBffService', () => {
  it('preserves the service-unavailable error when the circuit breaker is open', async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        BankingBffService,
        { provide: ConfigService, useValue: { get: () => 'http://core:8080' } },
        { provide: RedisService, useValue: {} },
      ],
    }).compile();
    const service = moduleRef.get(BankingBffService);

    service['breaker'].open();

    await expect(
      service.ejecutarTransferencia(
        {
          idempotencyKey: 'test-key',
          cuentaOrigen: '0000100001',
          cuentaDestino: '0000200001',
          monto: 100,
        },
        'test-correlation',
        '',
      ),
    ).rejects.toMatchObject({
      status: 503,
      response: 'El Core Bancario no se encuentra disponible (Circuit Breaker Abierto)',
    });

    await moduleRef.close();
  });

  it('returns Core 4xx responses without opening the circuit breaker', async () => {
    const server = createServer((_request, response) => {
      response.writeHead(422, { 'Content-Type': 'application/json' });
      response.end(JSON.stringify({ detail: 'Saldo insuficiente' }));
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    const address = server.address();
    if (!address || typeof address === 'string') {
      throw new Error('Could not start the test Core server');
    }

    const moduleRef = await Test.createTestingModule({
      providers: [
        BankingBffService,
        { provide: ConfigService, useValue: { get: () => `http://127.0.0.1:${address.port}` } },
        { provide: RedisService, useValue: {} },
      ],
    }).compile();
    const service = moduleRef.get(BankingBffService);

    try {
      await expect(
        service.ejecutarTransferencia(
          {
            idempotencyKey: 'test-key',
            cuentaOrigen: '0000100001',
            cuentaDestino: '0000200001',
            monto: 100,
          },
          'test-correlation',
          'Bearer test-token',
        ),
      ).rejects.toMatchObject({
        status: 422,
        response: { detail: 'Saldo insuficiente' },
      });
      expect(service['breaker'].opened).toBe(false);
    } finally {
      await moduleRef.close();
      await new Promise<void>((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      });
    }
  });
});
