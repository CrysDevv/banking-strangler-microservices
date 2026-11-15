import { Controller, Get, Post, Body, Param, Headers, Req } from '@nestjs/common';
import { BankingBffService } from './banking.service';
import { TransferenciaBffDto } from './dto/transferencias.dto';
import { Request } from 'express';

@Controller('api/v1/bff')
export class BankingBffController {
  constructor(private readonly bankingBffService: BankingBffService) {}

  @Post('transferencias')
  async ejecutarTransferencia(
    @Body() dto: TransferenciaBffDto,
    @Headers('x-correlation-id') correlationId: string,
    @Headers('authorization') authHeader: string,
  ) {
    return await this.bankingBffService.ejecutarTransferencia(dto, correlationId, authHeader);
  }

  @Get('clientes/:clienteId/cuentas')
  async listarCuentas(
    @Param('clienteId') clienteId: number,
    @Headers('x-correlation-id') correlationId: string,
    @Headers('authorization') authHeader: string,
  ) {
    return await this.bankingBffService.obtenerCuentas(clienteId, correlationId, authHeader);
  }

  @Get('cuentas/:numeroCuenta/movimientos')
  async listarMovimientos(
    @Param('numeroCuenta') numeroCuenta: string,
    @Headers('x-correlation-id') correlationId: string,
    @Headers('authorization') authHeader: string,
  ) {
    return await this.bankingBffService.obtenerMovimientos(numeroCuenta, correlationId, authHeader);
  }
}
