-- Ejecutado automaticamente por la imagen postgres:16 en el primer arranque
-- (base POSTGRES_DB ya creada). Esquema consumido por services/audit-fastapi (Fase 4).

CREATE SEQUENCE IF NOT EXISTS seq_comprobante START 1;

-- Bitacora de eventos recibidos. UNIQUE(event_id) = deduplicacion de mensajes at-least-once.
CREATE TABLE IF NOT EXISTS auditoria_eventos (
    id              BIGSERIAL    PRIMARY KEY,
    event_id        UUID         NOT NULL UNIQUE,
    event_type      VARCHAR(100) NOT NULL,
    aggregate_id    VARCHAR(64)  NOT NULL,
    correlation_id  VARCHAR(64),
    payload         JSONB        NOT NULL,
    recibido_en     TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_auditoria_aggregate   ON auditoria_eventos (aggregate_id);
CREATE INDEX IF NOT EXISTS ix_auditoria_recibido_en ON auditoria_eventos (recibido_en DESC);

-- Comprobantes de transferencia (uno por transferencia).
CREATE TABLE IF NOT EXISTS comprobantes (
    comprobante_id   UUID        PRIMARY KEY,
    transferencia_id UUID        NOT NULL UNIQUE,
    numero           VARCHAR(20) NOT NULL UNIQUE,
    hash_sha256      CHAR(64)    NOT NULL,
    contenido        JSONB       NOT NULL,
    emitido_en       TIMESTAMPTZ NOT NULL DEFAULT now()
);
