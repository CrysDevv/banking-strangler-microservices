package com.banking.core.repository;

import com.banking.core.model.OutboxEvento;
import org.springframework.data.jdbc.repository.query.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface OutboxRepository extends CrudRepository<OutboxEvento, Long> {

    @Query("SELECT TOP (:batchSize) SecuenciaId, EventoId, AggregateType, AggregateId, EventType, Payload, CorrelationId, Estado, Intentos, UltimoError, FechaCreacion, FechaPublicado " +
           "FROM dbo.OutboxEventos WITH (UPDLOCK, READPAST) " +
           "WHERE Estado = 'PENDIENTE' " +
           "ORDER BY SecuenciaId ASC")
    List<OutboxEvento> findPendingEventsForProcessing(@Param("batchSize") int batchSize);
}
