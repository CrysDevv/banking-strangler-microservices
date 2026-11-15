package com.banking.core.service;

import com.banking.core.dto.CuentaDto;
import com.banking.core.dto.MovimientoDto;
import com.banking.core.dto.TransferenciaRequest;
import com.banking.core.dto.TransferenciaResponse;
import com.banking.core.exception.BankingDomainException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class BankingService {

    private final JdbcTemplate jdbcTemplate;

    @Transactional
    public TransferenciaResponse ejecutarTransferencia(TransferenciaRequest request, String correlationId) {
        return jdbcTemplate.execute((java.sql.Connection conn) -> {
            try (CallableStatement stmt = conn.prepareCall("{CALL dbo.sp_EjecutarTransferencia (?, ?, ?, ?, ?, ?)}")) {
                stmt.setString(1, request.getIdempotencyKey());
                stmt.setString(2, request.getCuentaOrigen());
                stmt.setString(3, request.getCuentaDestino());
                stmt.setBigDecimal(4, request.getMonto());
                stmt.setString(5, request.getGlosa());
                stmt.setString(6, correlationId);

                boolean hasResult = stmt.execute();
                if (!hasResult) {
                    throw new RuntimeException("El procedimiento almacenado no retornó resultados.");
                }

                try (ResultSet rs = stmt.getResultSet()) {
                    if (rs.next()) {
                        UUID transferenciaId = readUniqueIdentifier(rs, "TransferenciaId");
                        String estado = rs.getString("Estado");
                        BigDecimal saldoOrigen = rs.getBigDecimal("SaldoOrigen");
                        BigDecimal saldoDestino = rs.getBigDecimal("SaldoDestino");
                        boolean replay = false;
                        try {
                            replay = rs.getBoolean("Replay");
                        } catch (SQLException ignored) {}

                        LocalDateTime fecha = LocalDateTime.now();
                        try {
                            Timestamp ts = rs.getTimestamp("FechaCreacion");
                            if (ts != null) {
                                fecha = ts.toLocalDateTime();
                            }
                        } catch (SQLException ignored) {}

                        log.info("Transferencia ejecutada con éxito. ID: {}, Estado: {}, CorrelationId: {}", transferenciaId, estado, correlationId);
                        return TransferenciaResponse.builder()
                                .transferenciaId(transferenciaId)
                                .estado(estado)
                                .saldoOrigen(saldoOrigen)
                                .saldoDestino(saldoDestino)
                                .replay(replay)
                                .fechaCreacion(fecha)
                                .build();
                    } else {
                        throw new RuntimeException("No se encontró resultado en el ResultSet del procedimiento.");
                    }
                }
            }
        });
    }

    @Transactional(readOnly = true)
    public List<CuentaDto> obtenerCuentasPorCliente(Long clienteId) {
        String sql = "SELECT NumeroCuenta, Tipo, Moneda, Saldo, Estado FROM dbo.Cuentas WHERE ClienteId = ?";
        return jdbcTemplate.query(sql, (rs, rowNum) -> CuentaDto.builder()
                .numeroCuenta(rs.getString("NumeroCuenta"))
                .tipo(rs.getString("Tipo"))
                .moneda(rs.getString("Moneda"))
                .saldo(rs.getBigDecimal("Saldo"))
                .estado(rs.getString("Estado"))
                .build(), clienteId);
    }

    @Transactional(readOnly = true)
    public List<MovimientoDto> obtenerMovimientosCuenta(String numeroCuenta) {
        String sql = "SELECT m.MovimientoId, m.TransferenciaId, m.Tipo, m.Monto, m.SaldoPosterior, m.Glosa, m.FechaMovimiento " +
                     "FROM dbo.Movimientos m " +
                     "JOIN dbo.Cuentas c ON m.CuentaId = c.CuentaId " +
                     "WHERE c.NumeroCuenta = ? " +
                     "ORDER BY m.FechaMovimiento DESC";
        return jdbcTemplate.query(sql, (rs, rowNum) -> MovimientoDto.builder()
                .movimientoId(rs.getLong("MovimientoId"))
                .transferenciaId(readUniqueIdentifier(rs, "TransferenciaId"))
                .tipo(rs.getString("Tipo"))
                .monto(rs.getBigDecimal("Monto"))
                .saldoPosterior(rs.getBigDecimal("SaldoPosterior"))
                .glosa(rs.getString("Glosa"))
                .fechaMovimiento(rs.getTimestamp("FechaMovimiento").toLocalDateTime())
                .build(), numeroCuenta);
    }

    static UUID readUniqueIdentifier(ResultSet resultSet, String columnName) throws SQLException {
        return UUID.fromString(resultSet.getString(columnName));
    }
}
