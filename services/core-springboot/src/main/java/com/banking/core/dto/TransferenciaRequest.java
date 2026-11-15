package com.banking.core.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class TransferenciaRequest {
    @NotBlank(message = "La clave de idempotencia es obligatoria")
    @Size(max = 64, message = "La clave de idempotencia no puede superar 64 caracteres")
    private String idempotencyKey;

    @NotBlank(message = "La cuenta de origen es obligatoria")
    @Size(max = 20)
    private String cuentaOrigen;

    @NotBlank(message = "La cuenta de destino es obligatoria")
    @Size(max = 20)
    private String cuentaDestino;

    @NotNull(message = "El monto es obligatorio")
    @DecimalMin(value = "0.01", message = "El monto debe ser mayor que cero")
    private BigDecimal monto;

    @Size(max = 200, message = "La glosa no puede superar 200 caracteres")
    private String glosa;
}
