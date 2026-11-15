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
public class TransferenciaResponse {
    private UUID transferenciaId;
    private String estado;
    private BigDecimal saldoOrigen;
    private BigDecimal saldoDestino;
    private boolean replay;
    private LocalDateTime fechaCreacion;
}
