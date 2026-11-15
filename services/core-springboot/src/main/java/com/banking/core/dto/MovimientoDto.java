package com.banking.core.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MovimientoDto {
    private Long movimientoId;
    private UUID transferenciaId;
    private String tipo;
    private BigDecimal monto;
    private BigDecimal saldoPosterior;
    private String glosa;
    private LocalDateTime fechaMovimiento;
}
