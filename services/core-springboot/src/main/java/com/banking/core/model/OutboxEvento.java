package com.banking.core.model;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Column;
import org.springframework.data.relational.core.mapping.Table;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Table("OutboxEventos")
public class OutboxEvento {
    @Id
    @Column("SecuenciaId")
    private Long secuenciaId;

    @Column("EventoId")
    private UUID eventoId;

    @Column("AggregateType")
    private String aggregateType;

    @Column("AggregateId")
    private String aggregateId;

    @Column("EventType")
    private String eventType;

    @Column("Payload")
    private String payload;

    @Column("CorrelationId")
    private String correlationId;

    @Column("Estado")
    private String estado;

    @Column("Intentos")
    private Integer intentos;

    @Column("UltimoError")
    private String ultimoError;

    @Column("FechaCreacion")
    private LocalDateTime fechaCreacion;

    @Column("FechaPublicado")
    private LocalDateTime fechaPublicado;
}
