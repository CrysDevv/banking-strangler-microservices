import { IsString, IsNotEmpty, IsNumber, Min, MaxLength } from 'class-validator';

export class TransferenciaBffDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  readonly idempotencyKey: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  readonly cuentaOrigen: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  readonly cuentaDestino: string;

  @IsNumber()
  @Min(0.01)
  readonly monto: number;

  @IsString()
  @MaxLength(200)
  readonly glosa?: string;
}
