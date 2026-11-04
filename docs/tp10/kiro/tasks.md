# Tareas de Implementación - Food Store Móvil (Unidad 8 / TP8)
## Plan de Ejecución Derivado de la Especificación Kiro

- [x] **TASK-01 · Inicialización y Esquema DDL en SQLite**
  - Crear script `movil/schema_sqlite.sql` con activación obligatoria de `PRAGMA foreign_keys = ON;`.
  - Definir tablas en modo `STRICT`: `producto_cache`, `pedido_borrador`, `item_borrador` y `cola_sync`.
  - Crear índice parcial condicional `ux_cola_una_pendiente` sobre solicitudes pendientes.
  - Crear vista `v_catalogo_disponible` para consulta en mostrador.
  - *Cumple con: REQ-01, REQ-05.*

- [x] **TASK-02 · Validación Transaccional y Pruebas Unitarias SQLite**
  - Crear script `movil/pruebas_sqlite.sql`.
  - Implementar prueba de atomicidad transaccional con `BEGIN ... COMMIT` y cancelación con `ROLLBACK`.
  - Probar Caso C1 (catálogo offline).
  - Probar Caso C7 (rechazo por `CHECK cantidad > 0` y `FOREIGN KEY producto_id`).
  - Generar base binaria `movil/foodstore_movil.db`.
  - *Cumple con: REQ-01, REQ-05.*

- [x] **TASK-03 · Vista e Intercambio de Instantánea Servidor-Tablet**
  - Crear vista `v_snapshot_movil` en PostgreSQL con cálculo de centavos y lápidas lógicas (`movil/postgresql_snapshot.sql`).
  - Generar archivo de intercambio `movil/servidor_snapshot.csv`.
  - Crear tabla receptora `snapshot_servidor` en SQLite y procedimiento de upsert a `producto_cache` (`movil/snapshot_servidor.sql`).
  - *Cumple con: REQ-01, REQ-03.*

- [x] **TASK-04 · Lógica del Semáforo de Sincronización**
  - Implementar script `movil/semaforo.sql` mediante Common Table Expression (CTE) y actualización sobre `cola_sync`.
  - Programar la lógica de prioridad (Rojo > Amarillo > Verde) y asignación de motivos descriptivos.
  - Garantizar idempotencia filtrando únicamente solicitudes `PENDIENTE`.
  - *Cumple con: REQ-02, REQ-03, REQ-04.*

- [x] **TASK-05 · Simulación Automatizada de Casos de Sincronización**
  - Crear runner ejecutable `movil/simulador_casos.py`.
  - Simular y verificar Caso C5 (caso base verde).
  - Simular y verificar Caso C2 (conflicto de precio $\rightarrow$ resolución $\rightarrow$ verde).
  - Simular y verificar Caso C3 (quiebre de stock $\rightarrow$ rojo).
  - Simular y verificar Caso C4 (producto dado de baja con lápida $\rightarrow$ rojo).
  - Simular y verificar Caso C6 (reintento con mismo UUID $\rightarrow$ rechazo por PK e invariabilidad del semáforo).
  - *Cumple con: REQ-02, REQ-03, REQ-04.*

- [x] **TASK-06 · Documentación, Bitácora de IA e Informe Final**
  - Redactar bitácora de IA con tres decisiones justificadas (`docs/bitacora_ia.md`).
  - Redactar Declaración de Uso de IA (`docs/DUIA.md`).
  - Actualizar `README.md` con guía de ejecución desde cero y pautas para el ensayo de defensa.
  - Consolidar informe técnico de hasta 6 páginas en formato PDF (`docs/informe.pdf`).
