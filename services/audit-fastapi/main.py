import os
import json
import threading
import time
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy import create_engine, Column, String, DateTime, Text, BigInteger
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
import pika
from datetime import datetime

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://audit_user:Audit#Pg2026@postgres:5432/audit_db")
RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://banking:Rabbit#Bus2026@rabbitmq:5672/")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class ComprobanteAuditoria(Base):
    __tablename__ = "comprobantes_auditoria"
    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    transferencia_id = Column(String(36), unique=True, index=True, nullable=False)
    cuenta_origen = Column(String(20), nullable=False)
    cuenta_destino = Column(String(20), nullable=False)
    monto = Column(String(50), nullable=False)
    moneda = Column(String(3), nullable=False)
    glosa = Column(String(200), nullable=True)
    saldo_origen = Column(String(50), nullable=False)
    saldo_destino = Column(String(50), nullable=False)
    correlation_id = Column(String(64), nullable=True)
    fecha_evento = Column(DateTime, default=datetime.utcnow)

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Audit FastAPI Service", version="1.0.0")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def rabbitmq_consumer():
    while True:
        try:
            params = pika.URLParameters(RABBITMQ_URL)
            connection = pika.BlockingConnection(params)
            channel = connection.channel()
            channel.exchange_declare(exchange='banking.exchange', exchange_type='topic', durable=True)
            result = channel.queue_declare(queue='audit_queue', durable=True)
            queue_name = result.method.queue
            channel.queue_bind(exchange='banking.exchange', queue=queue_name, routing_key='banking.transferencia.realizada')

            def callback(ch, method, properties, body):
                try:
                    data = json.loads(body.decode('utf-8'))
                    db = SessionLocal()
                    trans_id = data.get("transferenciaId")
                    existing = db.query(ComprobanteAuditoria).filter_by(transferencia_id=trans_id).first()
                    if not existing:
                        audit = ComprobanteAuditoria(
                            transferencia_id=trans_id,
                            cuenta_origen=data.get("cuentaOrigen"),
                            cuenta_destino=data.get("cuentaDestino"),
                            monto=str(data.get("monto")),
                            moneda=data.get("moneda"),
                            glosa=data.get("glosa"),
                            saldo_origen=str(data.get("saldoOrigen")),
                            saldo_destino=str(data.get("saldoDestino")),
                            correlation_id=properties.headers.get("X-Correlation-ID") if properties.headers else None
                        )
                        db.add(audit)
                        db.commit()
                    db.close()
                    ch.basic_ack(delivery_tag=method.delivery_tag)
                except Exception as e:
                    print(f"Error procesando mensaje de auditoría: {e}")
                    ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)

            channel.basic_consume(queue=queue_name, on_message_callback=callback)
            channel.start_consuming()
        except Exception as e:
            print(f"Conexión RabbitMQ caída en Audit, reintentando en 5s: {e}")
            time.sleep(5)

@app.on_event("startup")
def startup_event():
    t = threading.Thread(target=rabbitmq_consumer, daemon=True)
    t.start()

@app.get("/api/v1/audit/comprobantes/{transferencia_id}")
def obtener_comprobante(transferencia_id: str, db: Session = Depends(get_db)):
    comp = db.query(ComprobanteAuditoria).filter_by(transferencia_id=transferencia_id).first()
    if not comp:
        raise HTTPException(status_code=404, detail="Comprobante no encontrado en auditoría")
    return {
        "transferenciaId": comp.transferencia_id,
        "cuentaOrigen": comp.cuenta_origen,
        "cuentaDestino": comp.cuenta_destino,
        "monto": comp.monto,
        "moneda": comp.moneda,
        "glosa": comp.glosa,
        "saldoOrigen": comp.saldo_origen,
        "saldoDestino": comp.saldo_destino,
        "correlationId": comp.correlation_id,
        "fechaEvento": comp.fecha_evento.isoformat()
    }

@app.get("/health")
def health_check():
    return {"status": "UP"}
