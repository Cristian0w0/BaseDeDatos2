# Especificación y Plan de Mantenimiento — Unidad 6: Food Store
**Proyecto:** Food Store | **Motor:** PostgreSQL 16+ (PostgreSQL 17) | **Materia:** Base de Datos II (UTN)  
**Alcance:** Procedimiento de Respaldo, Monitoreo de Salud, Mantenimiento Preventivo y Recuperación contra Desastres.

---

## 1. Alcance y Automatización

El plan de continuidad y mantenimiento operativo de **Food Store** define cuatro tareas automatizables para garantizar la disponibilidad, consistencia y recuperabilidad del cluster:

1. **Respaldo Lógico Custom (`backup_foodstore.ps1` / `.sh`):** Extracción completa de esquemas y datos de `foodstore` en formato binario custom (`-Fc`), con compresión integrada, timestamping en el nombre de archivo y registro de ejecución en bitácora de logs.
2. **Chequeo de Salud (`health_check.sql`):** Auditoría del tamaño de la base y tablas, concurrencia de conexiones, tasa de confirmación/rollback (`xact_commit` vs `xact_rollback`), volumen de tuplas muertas (`n_dead_tup`) y detección de transacciones colgadas.
3. **Mantenimiento Periódico Seguro (`maintenance.sql`):** Inspección de umbrales de autovacuum, ejecución de `VACUUM ANALYZE` sobre tablas críticas (`pedido`, `detalle_pedido`) y actualización de estadísticas para el planificador (`pg_statistic`). **Se prohibe terminantemente el uso de `VACUUM FULL`** en rutinas periódicas por adquirir bloqueo exclusivo (`AccessExclusiveLock`).
4. **Simulacro de Restauración y Validación (`restore_test.ps1` / `.sh`):** Recuperación cronometrada sobre la base descartable `foodstore_restore_test`, validación de integridad referencial y de dominio, y cálculo de RTO/RPO observados.

---

## 2. Matriz de Planificación y Criterios de Éxito

| Tarea mínima | Frecuencia propuesta | Ventana operativa | Evidencia auditable | Condición de éxito (Criterio de Aprobación) |
|---|---|---|---|---|
| **Respaldo de `foodstore`** | Diaria | 02:00 AM (bajo tráfico) | Archivo `backups/foodstore_YYYYMMDD_HHMMSS.dump` y log en `logs/`. | `pg_dump` retorna código de salida `0`, archivo `.dump` > 0 bytes y log sin errores de lectura. |
| **Chequeo de salud** | Diaria | 06:00 AM (pre-operativa) | Salida formateada de `health_check.sql` en bitácora de monitoreo. | Conexiones activas < 80% del pool, transacciones abortadas < 1%, y 0 consultas bloqueadas > 30s. |
| **Revisión de mantenimiento** | Semanal | Domingos 03:00 AM | Salida de `maintenance.sql` con estado de autovacuum y tuplas muertas. | Relación `n_dead_tup / (n_live_tup + n_dead_tup) < 10%`, páginas reutilizables y estadísticas al día. |
| **Restauración de prueba** | Semanal | Domingos 04:00 AM | Registro de ejecución de `restore_test.ps1` en `logs/` con RTO/RPO medidos. | `foodstore_restore_test` restaurada; 0 productos inválidos, 0 detalles inválidos y conteo de filas idéntico al origen. |

---

## 3. Políticas de Seguridad y Reglas Operativas

1. **Gestión de Credenciales:** Prohibido escribir contraseñas en scripts o repositorios. La autenticación se canaliza mediante variables seguras de entorno (`PGPASSWORD` efímero) o archivo protegido `~/.pgpass` con permisos restrictivos (`0600`).
2. **Principio de Aislamiento e Inalterabilidad:** La base principal de producción (`foodstore`) nunca se borra, reemplaza ni trunca durante las pruebas. Todas las operaciones destructivas y ensayos de recuperación se restringen a la base descartable `foodstore_restore_test`.
3. **Formato Custom (`-Fc`):** Se adopta exclusivamente el formato custom de `pg_dump`, garantizando portabilidad multiplataforma, compresión eficiente, verificación de cabeceras y compatibilidad con `pg_restore` (restauración granular y concurrente).
4. **Mantenimiento No Bloqueante:** Toda acción de saneamiento se limita a `VACUUM (VERBOSE, ANALYZE)` para evitar la degradación de servicio que provocaría `VACUUM FULL`.
5. **Supervisión Humana de OpenCode / IA:** Los scripts generados o ajustados por herramientas de IA deben someterse a inspección de sintaxis, verificación de parámetros de seguridad y prueba en entorno aislado antes de su autorización.
