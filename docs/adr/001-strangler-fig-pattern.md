# ADR 001: Implementación del Patrón Strangler Fig para Modernización Bancaria

## Estado
Aprobado

## Contexto
El sistema bancario heredado monolítico presenta limitaciones en escalabilidad, despliegues y mantenimiento. Se requiere una migración gradual hacia microservicios modernos (Spring Boot, NestJS, FastAPI) sin interrumpir la operación transaccional continua.

## Decisión
Adoptar el patrón **Strangler Fig** utilizando NGINX como API Gateway para enrutar tráfico de manera gradual e incremental desde el exterior hacia los nuevos servicios de aplicación, aislando progresivamente el monolito hasta su reemplazo total.

## Consecuencias
- Migración de riesgo controlado sin downtime.
- Capacidad de operar arquitecturas híbridas temporalmente.
