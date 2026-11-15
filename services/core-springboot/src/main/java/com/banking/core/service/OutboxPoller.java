package com.banking.core.service;

import com.banking.core.config.RabbitMQConfig;
import com.banking.core.model.OutboxEvento;
import com.banking.core.repository.OutboxRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class OutboxPoller {

    private final OutboxRepository outboxRepository;
    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper;

    @Scheduled(fixedRateString = "${banking.outbox.fixed-rate-ms:3000}")
    @Transactional
    public void pollAndPublishOutboxEvents() {
        List<OutboxEvento> pendientes = outboxRepository.findPendingEventsForProcessing(50);
        if (pendientes.isEmpty()) {
            return;
        }

        log.debug("OutboxPoller: procesando {} eventos pendientes", pendientes.size());

        for (OutboxEvento evento : pendientes) {
            try {
                rabbitTemplate.convertAndSend(
                        RabbitMQConfig.BANKING_EXCHANGE,
                        "banking.transferencia.realizada",
                        objectMapper.readTree(evento.getPayload()),
                        message -> {
                            if (evento.getCorrelationId() != null) {
                                message.getMessageProperties().setHeader("X-Correlation-ID", evento.getCorrelationId());
                            }
                            return message;
                        }
                );

                evento.setEstado("PUBLICADO");
                evento.setFechaPublicado(LocalDateTime.now());
                evento.setUltimoError(null);
                outboxRepository.save(evento);

                log.info("Evento Outbox {} publicado exitosamente en RabbitMQ", evento.getEventoId());
            } catch (Exception e) {
                log.error("Error publicando evento Outbox {}: {}", evento.getEventoId(), e.getMessage());
                evento.setIntentos(evento.getIntentos() + 1);
                evento.setUltimoError(e.getMessage());
                if (evento.getIntentos() >= 5) {
                    evento.setEstado("FALLIDO");
                }
                outboxRepository.save(evento);
            }
        }
    }
}
