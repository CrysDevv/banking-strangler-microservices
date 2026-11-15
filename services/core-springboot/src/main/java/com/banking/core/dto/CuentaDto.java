package com.banking.core.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CuentaDto {
    private String numeroCuenta;
    private String tipo;
    private String moneda;
    private BigDecimal saldo;
    private String estado;
}
