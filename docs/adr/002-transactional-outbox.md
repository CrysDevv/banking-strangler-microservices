# ADR 002: Transaccional Outbox y Consistencia Eventual con RabbitMQ

## Estado
Aprobado

## Contexto
Las transferencias bancarias requieren atomicidad estricta en base de datos (MS SQL Server) y, simultáneamente, la publicación confiable de eventos hacia el bus de mensajes (RabbitMQ) para la auditoría y notificaciones. El patrón de doble escritura (Dual Write) directo provoca inconsistencias si el broker falla tras el commit local.

## Decisión
Implementar el patrón **Transactional Outbox**. Los eventos de negocio se escriben en la tabla `OutboxEventos` dentro de la misma transacción ACID de MS SQL Server. Un proceso dedicado (`OutboxPoller`) con bloqueos `UPDLOCK, READPAST` lee y publica de forma idempotente los eventos hacia RabbitMQ.

## Consecuencias
- Garantía absoluta de entrega de eventos (At-least-once delivery).
- Resiliencia ante caídas del Message Broker.
