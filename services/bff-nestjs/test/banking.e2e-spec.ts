import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { BankingBffService } from '../src/modules/banking/banking.service';
import { RedisService } from '../src/modules/redis/redis.service';

describe('BankingBffController (e2e)', () => {
  let app: INestApplication;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(RedisService)
      .useValue({
        get: async () => null,
        set: async () => undefined,
        del: async () => undefined,
      })
      .overrideProvider(BankingBffService)
      .useValue({
        obtenerCuentas: async () => {
          throw new Error('Core unavailable');
        },
      })
      .compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  it('/api/v1/bff/clientes/1/cuentas (GET) sin token debe fallar o retornar error', () => {
    return request(app.getHttpServer())
      .get('/api/v1/bff/clientes/1/cuentas')
      .expect(500);
  });

  it('/health (GET) debe confirmar que el servicio está disponible', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect({ status: 'ok' });
  });
});
