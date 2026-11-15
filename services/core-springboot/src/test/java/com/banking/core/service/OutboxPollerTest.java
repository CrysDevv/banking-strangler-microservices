package com.banking.core.service;

import com.banking.core.config.RabbitMQConfig;
import com.banking.core.model.OutboxEvento;
import com.banking.core.repository.OutboxRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.amqp.core.MessagePostProcessor;
import org.springframework.amqp.rabbit.core.RabbitTemplate;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class OutboxPollerTest {

    @Test
    void publishesOutboxPayloadAsJsonObject() throws Exception {
        OutboxRepository repository = mock(OutboxRepository.class);
        RabbitTemplate rabbitTemplate = mock(RabbitTemplate.class);
        OutboxEvento event = new OutboxEvento();
        event.setPayload("{\"transferenciaId\":\"transfer-123\"}");
        event.setIntentos(0);

        when(repository.findPendingEventsForProcessing(50)).thenReturn(List.of(event));

        OutboxPoller poller = new OutboxPoller(repository, rabbitTemplate, new ObjectMapper());
        poller.pollAndPublishOutboxEvents();

        org.mockito.ArgumentCaptor<Object> payload = org.mockito.ArgumentCaptor.forClass(Object.class);
        verify(rabbitTemplate).convertAndSend(
                eq(RabbitMQConfig.BANKING_EXCHANGE),
                eq("banking.transferencia.realizada"),
                payload.capture(),
                any(MessagePostProcessor.class)
        );
        assertTrue(payload.getValue() instanceof JsonNode);
        assertEquals("transfer-123", ((JsonNode) payload.getValue()).path("transferenciaId").asText());
        assertEquals("PUBLICADO", event.getEstado());
    }
}
