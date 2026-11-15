# Banking Strangler Microservices

> Arquitectura de referencia orientada a eventos para modernizar un core bancario monolítico mediante el patrón **Strangler Fig** —sin detener la operación ni perder trazabilidad transaccional.

- [Contexto y Problemática](#-contexto-y-problemática)
- [Arquitectura de la Solución](#-arquitectura-de-la-solución)
- [Componentes del Sistema](#-componentes-del-sistema)
- [Patrones de Diseño Aplicados](#-patrones-de-diseño-aplicados)
- [Tecnologías y Stack](#-tecnologías-y-stack)
- [Puesta en Marcha (Quick Start)](#-puesta-en-marcha-quick-start)
- [Estrategia de Migración y Rollback](#-estrategia-de-migración-y-rollback)

---

## 🎯 Contexto y Problemática

Los sistemas bancarios tradicionales (*legacy*) suelen crecer como monolitos rígidos: tocar un módulo implica riesgo operativo y desplegar funcionalidades nuevas tarda meses.

Este repositorio implementa una transición gradual mediante **estrangulamiento (Strangler Fig)** bajo tres principios:

* **Zero Downtime:** la plataforma sigue operando mientras se migran capacidades de negocio.
* **Aislamiento por dominio:** cuentas, transacciones y clientes se desacoplan uno a uno hacia servicios independientes.
* **Reversibilidad inmediata:** cada ruta migrada puede volver al monolito si aparecen anomalías en producción.

---

## 🏗️ Arquitectura de la Solución

Una fachada inteligente actúa como punto único de entrada y oculta a los clientes dónde se procesa cada petición:

```text
                       ┌─────────────────────────────┐
                       │     Clientes / Frontend     │
                       └──────────────┬──────────────┘
                                      │ HTTP / REST (JWT)
                                      ▼
                       ┌─────────────────────────────┐
                       │  API Façade / NGINX (:8088) │
                       └───┬─────────────────────┬───┘
          Tráfico Legacy   │                     │   Tráfico Migrado
        ┌──────────────────┘                     └──────────────────┐
        ▼                                                           ▼
┌───────────────┐                                      ┌─────────────────────────┐
│   Monolito    │                                      │  BFF (NestJS)           │
│    Legacy     │                                      │  Core (Spring Boot)     │
│ (MS SQL Srv)  │                                      │  Auditoría (FastAPI)    │
└───────────────┘                                      └────────────┬────────────┘
                                                                    │ Outbox / Eventos
                                                                    ▼
                                                       ┌─────────────────────────┐
                                                       │ RabbitMQ / Kafka        │
                                                       │ + PostgreSQL (per-svc)  │
                                                       └─────────────────────────┘
```

1. **API Façade / Gateway (NGINX):** intercepta el tráfico entrante y decide de forma dinámica qué rutas van al monolito y cuáles al ecosistema nuevo.
2. **Dominios desacoplados:** los nuevos servicios siguen *Domain-Driven Design (DDD)* con almacenamiento independiente (*Database-per-service*).
3. **Mensajería asíncrona:** los eventos financieros críticos viajan por un broker (RabbitMQ / Kafka) para evitar acoplamiento temporal entre servicios.

---

## 📦 Componentes del Sistema

| Componente | Responsabilidad | Acceso / Estado |
| :--- | :--- | :--- |
| **API Gateway (NGINX)** | Enrutamiento dinámico, fachada única y borde de seguridad. | `http://localhost:8088` |
| **BFF (NestJS)** | Orquestación de respuestas y adaptación para clientes. | Servicio activo |
| **Core Bancario (Spring Boot)** | Lógica de negocio principal y persistencia transaccional. | Servicio activo |
| **Auditoría (FastAPI)** | Registro y trazabilidad de operaciones críticas. | Servicio activo |
| **RabbitMQ Management** | Gestión de colas, intercambios y mensajería asíncrona. | `http://localhost:15672` |
| **Grafana** | Paneles de observabilidad, métricas y salud del clúster. | `http://localhost:3001` |

---

## 🧩 Patrones de Diseño Aplicados

| Patrón | Propósito en el sistema |
| :--- | :--- |
| **Strangler Fig** | Sustitución progresiva de rutas del monolito sin reescrituras masivas. |
| **API Façade / Gateway Routing** | Desacopla la interfaz pública de la topología interna de servicios. |
| **Transactional Outbox** | Asegura consistencia atómica entre el guardado en base de datos y la publicación del evento. |
| **Idempotency** | Evita cargos o abonos duplicados ante reintentos de red en operaciones financieras. |

---

## 🛠️ Tecnologías y Stack

* **Backend y Microservicios:** Java 17 (Spring Boot), TypeScript (NestJS), Python 3.12 (FastAPI).
* **Mensajería y Streaming:** RabbitMQ, Apache Kafka.
* **Bases de Datos:** MS SQL Server, PostgreSQL.
* **Infraestructura:** Docker, Docker Compose, NGINX, Grafana.

---

## 🚀 Puesta en Marcha (Quick Start)

### Prerrequisitos
* **Docker** y **Docker Compose** activos en el equipo.
* **PowerShell** (entorno recomendado en Windows para los scripts de automatización).

### Ejecución local

1. **Clonar el repositorio y entrar al directorio:**

```bash
git clone [https://github.com/CrysDevv/banking-strangler-microservices.git](https://github.com/CrysDevv/banking-strangler-microservices.git)
cd banking-strangler-microservices
```

2. **Levantar los contenedores e inicializar el entorno:**

```powershell
.\start.ps1
```

3. **Cargar el token JWT local para probar endpoints protegidos:**

```powershell
$jwt = (Get-Content .\.dev-jwt -Raw).Trim()
```

---

## 🔄 Estrategia de Migración y Rollback

* **Conmutación progresiva:** el Gateway controla mediante reglas de enrutamiento qué porcentaje o tipo de peticiones pasan a los microservicios.
* **Reversión instantánea:** si la tasa de error o latencia supera el umbral esperado, NGINX redirige el tráfico de vuelta al monolito sin pérdida de datos gracias a la sincronización transitoria.