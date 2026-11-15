# ADR 003: API Gateway con NGINX para Seguridad y Rate Limiting

## Estado
Aprobado

## Contexto
Los microservicios expuestos necesitan una capa unificada de entrada que proteja contra ataques de denegación de servicio (DoS), aplique límites de tasa (rate limiting), inyecte cabeceras de seguridad HTTP y centralice el enrutamiento.

## Decisión
Utilizar **NGINX** como API Gateway perimetral con directivas nativas de `limit_req`, cabeceras de seguridad estrictas (X-Frame-Options, X-Content-Type-Options) y proxy reverso hacia el BFF de NestJS y el servicio de auditoría FastAPI.

## Consecuencias
- Reducción de la superficie de ataque expuesta directamente a los microservicios.
- Control centralizado del tráfico transaccional entrante.
