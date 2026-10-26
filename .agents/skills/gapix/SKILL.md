---
name: gapix
description: >
  Construye APIs REST escalables y mantenibles en Go usando Clean Architecture + DDD
  sin frameworks HTTP. Usa exclusivamente net/http (ServeMux 1.26+), context, slog,
  sync.Pool, sqlc y patrones de concurrencia seguros. Actívala cuando el usuario pida
  crear, revisar o refactorizar una API REST en Go, definir su estructura de carpetas,
  implementar handlers, repositorios, middlewares, inyección de dependencias,
  graceful shutdown, observabilidad o pruebas sin depender de Gin/Echo/Fiber/Chi.
license: MIT
compatibility: Go 1.26+
metadata:
  stack: go, net/http, stdlib, clean-architecture, ddd, concurrency, memory-efficiency
---

# Go Clean API · Standard Library Only

## 1. Principios irrenunciables

- Regla de Dependencia: el dominio nunca importa net/http, database/sql ni librerías de infraestructura.
- Sin frameworks HTTP: usa net/http + http.ServeMux (Go 1.26+ con method matching y path wildcards como GET /users/{id}). No Gin, Echo, Fiber ni Chi salvo que el usuario lo pida explícitamente.
- Inyección explícita por constructores. Prohibidos globales y singletons ocultos.
- Cada goroutine debe tener un context.Context con vía de cancelación.
- Mide con benchmarks y pprof antes de optimizar memoria.

## 2. Arquitectura: Clean Architecture + DDD ligero

Tabla de capas:
| Capa | Contenido | Puede importar |
|---|---|---|
| Dominio (internal/domain) | Entidades, value objects, errores de negocio, interfaces de repositorio (puertos). | Solo stdlib. |
| Aplicación (internal/application) | Casos de uso (servicios). Orquesta el dominio y define puertos de salida. | Dominio. |
| Infraestructura (internal/infrastructure) | Implementaciones concretas: PostgreSQL con sqlc, caché, clientes externos. | Interfaces de dominio/aplicación + librerías externas. |
| Transporte (internal/transport/http) | Handlers net/http, middlewares, DTOs. | Aplicación. |

La capa de transporte no contiene lógica de negocio. El handler solo decodifica, llama al caso de uso, codifica la respuesta y gestiona el error HTTP.

Estructura de proyecto recomendada:
```text
.
├── cmd/api/main.go
├── internal/
│   ├── domain/
│   ├── application/
│   ├── infrastructure/postgres/
│   └── transport/http/{handler,middleware,dto}/
├── db/{migrations,queries}/
├── pkg/
├── configs/
├── go.mod
└── Makefile
```

## 3. Implementación con net/http (Go 1.26+)

- Registra rutas con mux.Handle("GET /api/v1/users/{id}", handler).
- Usa r.PathValue("id") para extraer wildcards.
- Patrón de handler: funciones que devuelven http.Handler, con dependencias inyectadas.
- Middlewares como func(http.Handler) http.Handler encadenados.
- Graceful shutdown obligatorio con signal.NotifyContext + srv.Shutdown.
- Timeouts explícitos en http.Server: ReadHeaderTimeout, ReadTimeout, WriteTimeout, IdleTimeout.

## 4. Concurrencia segura

- context.Context como primer parámetro en funciones que puedan bloquearse.
- Para tareas paralelas, usa errgroup o canales con select sobre ctx.Done().
- Nunca lances goroutines sin plan de salida.
- Reutiliza un solo http.Client y un solo \*sql.DB. Ajusta MaxIdleConnsPerHost.

## 5. Manejo eficiente de memoria

- sync.Pool para buffers temporales solo si el perfil muestra presión de GC.
- Evita escapes innecesarios; verifica con go build -gcflags="-m".
- Streaming con json.Encoder directamente sobre http.ResponseWriter para respuestas grandes.
- No toques GOGC ni GOMEMLIMIT sin benchmark reproducible.

## 6. Patrones de API

- Respuesta envolvente: {"data": ..., "error": null, "meta": {...}}.
- Errores estructurados (RFC 9457 o envelope con code/message/details).
- Versionado por ruta: /api/v1/...
- Paginación por cursor, no por offset.
- Idempotency-Key en cabecera para POST críticos.
- http.MaxBytesReader para limitar cuerpos.

## 7. Observabilidad

- slog estructurado en JSON con request_id.
- Métricas Prometheus: errores, latencia p50/p95/p99, peticiones en vuelo.
- OpenTelemetry para trazas distribuidas (se integra con net/http, no lo sustituye).

## 8. Base de datos con sqlc

- sqlc para código type-safe a partir de SQL. Sin ORM en runtime.
- Interfaces de repositorio en dominio; implementación sqlc en infrastructure/postgres.

## 9. Testing sin frameworks HTTP

- Handlers con httptest.NewRequest + httptest.NewRecorder.
- Casos de uso con dobles de repositorio (interfaces).
- Integración con httptest.NewServer sobre el ServeMux.
- Benchmarks con go test -bench=. -benchmem.

## 10. Anti-patrones a rechazar

- Lógica de negocio en handlers.
- http.Client creado por petición.
- go func() sin context.
- Globales para db o logger.
- sync.Pool sin perfil previo.
- Timeouts en cero en http.Server.
- Frameworks HTTP innecesarios.

## 11. Checklist de salida

- net/http + ServeMux, sin frameworks de routing.
- Dominio sin imports de infraestructura.
- Inyección por constructores.
- context.Context propagado en todas las capas.
- http.Server con timeouts y graceful shutdown.
- Middlewares de request ID, recovery, logging y timeout.
- Respuestas y errores consistentes.
- slog con request_id.
- Benchmarks de allocations antes de sync.Pool.
- Tests de handlers con httptest.
