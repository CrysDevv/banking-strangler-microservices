import { Injectable, HttpException, HttpStatus, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse, Method } from 'axios';
import * as CircuitBreaker from 'opossum';
import { RedisService } from '../redis/redis.service';
import { TransferenciaBffDto } from './dto/transferencias.dto';

@Injectable()
export class BankingBffService {
  private readonly logger = new Logger(BankingBffService.name);
  private readonly coreClient: AxiosInstance;
  private readonly breaker: CircuitBreaker<
    [Method, string, unknown, AxiosRequestConfig['headers']],
    AxiosResponse<unknown>
  >;

  constructor(
    private configService: ConfigService,
    private redisService: RedisService,
  ) {
    const coreBaseUrl = this.configService.get<string>('CORE_BASE_URL', 'http://localhost:8080');
    this.coreClient = axios.create({
      baseURL: coreBaseUrl,
      timeout: 5000,
    });

    const options = {
      timeout: 6000,
      errorThresholdPercentage: 50,
      resetTimeout: 10000,
      volumeThreshold: 5,
      errorFilter: (error: unknown) =>
        axios.isAxiosError(error) &&
        error.response !== undefined &&
        error.response.status >= 400 &&
        error.response.status < 500,
    };

    this.breaker = new CircuitBreaker<
      [Method, string, unknown, AxiosRequestConfig['headers']],
      AxiosResponse<unknown>
    >(async (method, url, data, headers) => {
      return this.coreClient.request({ method, url, data, headers });
    }, options);
  }

  private rethrowCoreError(error: unknown): never {
    if (error instanceof Error && CircuitBreaker.isOurError(error)) {
    throw new HttpException(
      'El Core Bancario no se encuentra disponible (Circuit Breaker Abierto)',
      HttpStatus.SERVICE_UNAVAILABLE,
    );
    }

    if (axios.isAxiosError(error)) {
    if (error.response) {
      throw new HttpException(error.response.data, error.response.status);
    }
    throw new HttpException('El Core Bancario no se encuentra disponible', HttpStatus.SERVICE_UNAVAILABLE);
    }

    throw error;
  }

  async ejecutarTransferencia(dto: TransferenciaBffDto, correlationId: string, authHeader: string) {
    try {
      const response = await this.breaker.fire(
        'POST',
        '/api/v1/banking/transferencias',
        dto,
        {
          'X-Correlation-ID': correlationId,
          'Authorization': authHeader,
        }
      );
      return response.data;
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`Error ejecutando transferencia en core: ${message}`);
      this.rethrowCoreError(error);
    }
  }

  async obtenerCuentas(clienteId: number, correlationId: string, authHeader: string) {
    const cacheKey = `banking:cliente:${clienteId}:cuentas`;
    const cached = await this.redisService.get(cacheKey);
    if (cached) {
      this.logger.debug(`Cache hit para cuentas de cliente ${clienteId}`);
      return JSON.parse(cached);
    }

    try {
      const response = await this.breaker.fire(
        'GET',
        `/api/v1/banking/clientes/${clienteId}/cuentas`,
        null,
        {
          'X-Correlation-ID': correlationId,
          'Authorization': authHeader,
        }
      );
      await this.redisService.set(cacheKey, JSON.stringify(response.data), 30);
      return response.data;
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`Error obteniendo cuentas: ${message}`);
      this.rethrowCoreError(error);
    }
  }

  async obtenerMovimientos(numeroCuenta: string, correlationId: string, authHeader: string) {
    const cacheKey = `banking:cuenta:${numeroCuenta}:movimientos`;
    const cached = await this.redisService.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    try {
      const response = await this.breaker.fire(
        'GET',
        `/api/v1/banking/cuentas/${numeroCuenta}/movimientos`,
        null,
        {
          'X-Correlation-ID': correlationId,
          'Authorization': authHeader,
        }
      );
      await this.redisService.set(cacheKey, JSON.stringify(response.data), 15);
      return response.data;
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`Error obteniendo movimientos: ${message}`);
      this.rethrowCoreError(error);
    }
  }
}
