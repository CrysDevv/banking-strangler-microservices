package com.banking.core.controller;

import com.banking.core.config.CorrelationIdFilter;
import com.banking.core.dto.CuentaDto;
import com.banking.core.dto.MovimientoDto;
import com.banking.core.dto.TransferenciaRequest;
import com.banking.core.dto.TransferenciaResponse;
import com.banking.core.service.BankingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/banking")
@RequiredArgsConstructor
public class BankingController {

    private final BankingService bankingService;

    @PostMapping("/transferencias")
    public ResponseEntity<TransferenciaResponse> ejecutarTransferencia(
            @Valid @RequestBody TransferenciaRequest request,
            @RequestHeader(value = CorrelationIdFilter.CORRELATION_ID_HEADER, required = false) String correlationId) {
        TransferenciaResponse response = bankingService.ejecutarTransferencia(request, correlationId);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/clientes/{clienteId}/cuentas")
    public ResponseEntity<List<CuentaDto>> listarCuentas(@PathVariable Long clienteId) {
        List<CuentaDto> cuentas = bankingService.obtenerCuentasPorCliente(clienteId);
        return ResponseEntity.ok(cuentas);
    }

    @GetMapping("/cuentas/{numeroCuenta}/movimientos")
    public ResponseEntity<List<MovimientoDto>> listarMovimientos(@PathVariable String numeroCuenta) {
        List<MovimientoDto> movimientos = bankingService.obtenerMovimientosCuenta(numeroCuenta);
        return ResponseEntity.ok(movimientos);
    }
}
