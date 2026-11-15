```markdown
# Banking Strangler Microservices

> Una arquitectura de referencia orientada a eventos y basada en microservicios para la modernización de sistemas bancarios core mediante el patrón **Strangler Fig (Estrangulamiento)**.

---

## 📋 Tabla de Contenidos
- [Contexto y Problemática](#-contexto-y-problemática)
- [Arquitectura de la Solución](#-arquitectura-de-la-solución)
- [Patrones de Diseño Aplicados](#-patrones-de-diseño-aplicados)
- [Componentes del Sistema](#-componentes-del-sistema)
- [Tecnologías y Stack](#-tecnologías-y-stack)
- [Puesta en Marcha (Quick Start)](#-puesta-en-marcha-quick-start)
- [Estrategia de Migración y Rollback](#-estrategia-de-migración-y-rollback)

---

## 🎯 Contexto y Problemática

Los sistemas core bancarios tradicionales (*legacies*) suelen ser monolitos rígidos, acoplados y difíciles de escalar. Realizar cambios o lanzar nuevos productos financieros toma meses debido al alto riesgo de interrupción. 

Este proyecto demuestra cómo desacoplar un monolito financiero de forma incremental utilizando el **Patrón Strangler Fig**, asegurando:
* **Cero tiempo de inactividad (Zero Downtime):** La plataforma permanece disponible continuamente durante la migración.
* **Mitigación de riesgos:** Los módulos se reemplazan por dominio de negocio (cuentas, transacciones, clientes) uno por uno.
* **Reversibilidad:** Cada etapa de migración cuenta con mecanismos para redirigir el tráfico al sistema heredado en caso de anomalías.

---

## 🏗️ Arquitectura de la Solución

El sistema se compone de una fachada inteligente que actúa como punto de entrada único, aislando a los clientes de los cambios internos en el backend:

1. **API Façade / Gateway (NGINX):** Intercepta todas las peticiones entrantes. Decide de manera dinámica si la petición debe dirigirse al Monolito Legacy o al nuevo ecosistema de microservicios.
2. **Dominio Desacoplado:** Los nuevos servicios se construyen bajo los principios de *Domain-Driven Design (DDD)*, utilizando bases de datos independientes por servicio (*Database-per-service pattern*).
3. **Comunicación Asíncrona (Event-Driven):** Los eventos de negocio críticos se propagan mediante un broker de mensajes (RabbitMQ) para desacoplar las operaciones financieras.

---

## 🧩 Patrones de Diseño Aplicados

* **Strangler Fig Pattern:** Interceptación gradual de funcionalidades del monolito hacia microservicios independientes.
* **API Façade / Gateway Routing:** Enrutamiento transparente para los clientes externos.
* **Transactional Outbox Pattern:** Garantiza la consistencia de datos entre la base de datos transaccional y el envío de eventos al message broker.
* **Idempotency:** Clave para asegurar que reintentos de peticiones financieras no dupliquen cargos o abonos.

---

## 📦 Componentes del Sistema

| Componente | Descripción | Estado / Rol |
| :--- | :--- | :--- |
| **API Gateway / NGINX** | Enrutador de peticiones y punto de terminación de seguridad. | `http://localhost:8088` |
| **Grafana / Observabilidad** | Monitoreo y métricas del sistema. | `http://localhost:3001` |
| **RabbitMQ Management** | Gestión y monitoreo de colas y mensajería asíncrona. | `http://localhost:15672` |
| **BFF (NestJS) & Core (Spring Boot)** | Orquestación y lógica de negocio principal. | Microservicios Activos |

---

## 🛠️ Tecnologías y Stack

* **Backend / Microservicios:** Java 17 (Spring Boot), TypeScript (NestJS - BFF), Python 3.12 (FastAPI - Auditoría).
* **Mensajería & Streaming:** RabbitMQ / Apache Kafka.
* **Contenedores y Orquestación:** Docker / Docker Compose.
* **Bases de Datos:** MS SQL Server, PostgreSQL.

---

## 🚀 Puesta en Marcha (Quick Start)

### Prerrequisitos
* Docker y Docker Compose ejecutándose en tu máquina.
* PowerShell (recomendado para entorno Windows).

### Pasos de ejecución
1. **Clonar el repositorio:**
   ```bash
   git clone [https://github.com/CrysDevv/banking-strangler-microservices.git](https://github.com/CrysDevv/banking-strangler-microservices.git)
   cd banking-strangler-microservices

```

2. **Ejecutar el script de inicio en PowerShell:**
```powershell
.\start.ps1

```


3. **Cargar el token JWT para pruebas locales:**
```powershell
$jwt = (Get-Content .\.dev-jwt -Raw).Trim()

```



---

## 🔄 Estrategia de Migración y Rollback

1. **Feature Flags de Enrutamiento:** El Gateway conmuta de forma controlada porcentajes de tráfico hacia los microservicios modernos.
2. **Plan de Reversión:** Si la tasa de errores supera los umbrales definidos, el enrutamiento se reconfigura instantáneamente hacia el monolito sin pérdida de datos gracias a la sincronización transitoria.

```

```