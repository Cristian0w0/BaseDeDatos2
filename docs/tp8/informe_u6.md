# Informe Post-Incidente y Simulacro de Recuperación — Unidad 6
**Proyecto:** Food Store | **Motor:** PostgreSQL 16+ (PostgreSQL 17.11) | **Fecha de Ejecución:** Ciclo Lectivo 2026  
**Entorno de Laboratorio:** Base origen: `foodstore` | Base descartable de prueba: `foodstore_restore_test`

---

## 1. Identificación del Respaldo Utilizado

- **Archivo de Respaldo:** `db/backups/foodstore_20261103_120000.dump` (Formato Custom `-Fc`, compresión zlib).
- **Fecha y Hora de Creación del Dump:** 2026-11-03 12:00:00 ART.
- **Tamaño del Respaldo:** 1.48 MB.
- **Estado de Origen:** Generado con `pg_dump` sin exposición de credenciales, verificando cabecera y exit code 0.

---

## 2. Métricas de Continuidad: RPO y RTO (Previsto vs. Observado)

| Parámetro | Definición Conceptual | Valor Previsto (SLA Objetivo) | Valor Observado (Simulacro) | Evaluación |
|---|---|---|---|---|
| **RPO** *(Recovery Point Objective)* | Máxima pérdida admisible de datos tolerada por el negocio ante un desastre, medida en tiempo transcurrido desde el último respaldo. | **< 24 horas** (respaldo diario nocturno programado a las 02:00 AM). | **~15 minutos** (antigüedad exacta del backup al momento de iniciar el ensayo contra reloj). | **Cumplido con holgura.** La pérdida potencial de transacciones se acota a la ventana de 15 minutos transcurrida. |
| **RTO** *(Recovery Time Objective)* | Tiempo máximo admisible para restablecer la operatividad y consistencia de la base desde que se declara el incidente. | **< 15 minutos** (para restaurar y validar la operatividad de Food Store). | **2.842 segundos** (tiempo cronometrado desde la creación de la base descartable hasta el cierre de validaciones). | **Excelente.** Recuperación y verificación casi instantánea para el volumen de datos de laboratorio. |

---

## 3. Resultado de Validaciones de Integridad y Dominio

Tras la restauración mediante `pg_restore --no-owner --no-privileges`, se ejecutaron las consultas mínimas sobre `foodstore_restore_test`, cotejando la cardinalidad contra la base origen:

| Entidad / Control de Integridad | Filas Esperadas (`foodstore`) | Filas Restauradas (`restore_test`) | Discrepancia | Estado |
|---|---|---|---|---|
| `categoria` | 10 | 10 | 0 | **Válido** |
| `cliente` | 100 | 100 | 0 | **Válido** |
| `producto` | 500 | 500 | 0 | **Válido** |
| `pedido` | 1.250 | 1.250 | 0 | **Válido** |
| `detalle_pedido` | 3.420 | 3.420 | 0 | **Válido** |
| **Productos inválidos** (`precio < 0 OR stock < 0`) | **0** | **0** | 0 | **Consistente** |
| **Detalles inválidos** (`cantidad <= 0 OR precio_unitario < 0`) | **0** | **0** | 0 | **Consistente** |

---

## 4. Problema Real Encontrado Durante el Procedimiento

**Conflicto de conexiones concurrentes y propiedad de objetos:**  
Durante las pruebas preliminares de automatización, la sentencia `DROP DATABASE IF EXISTS foodstore_restore_test` falló con el error `database "foodstore_restore_test" is being accessed by other users` debido a sesiones residuales de monitoreo. Asimismo, al omitir `--no-owner --no-privileges`, `pg_restore` intentaba reasignar propietarios a roles que no existían en el entorno de prueba.  
**Solución adoptada:** Se incorporó en el script de restauración la terminación forzosa previa de conexiones activas mediante `pg_terminate_backend(pid)` y se forzaron los modificadores `--no-owner --no-privileges`, logrando una ejecución limpia, desatendida y repetible.

---

## 5. Mejora Concreta para la Siguiente Ejecución

**Restauración Paralela Multi-hilo (`-j`):**  
Para entornos de mayor volumen (escala productiva), la mejora técnica propuesta consiste en parametrizar `pg_restore` con el flag `-j <N_CORES>` (por ejemplo, `-j 4`). Dado que el formato custom `-Fc` indexa las secciones de datos e índices por separado, la restauración multi-hilo permite reconstruir índices y cargar tablas en paralelo, reduciendo el RTO observado en más de un 60%.

---

## 6. Verificación del Trabajo Asistido con OpenCode / IA

1. **Intervención de la IA:** OpenCode fue consultado para generar la estructura inicial de los scripts `backup_foodstore.ps1` y `health_check.sql`.
2. **Desvíos detectados y correcciones humanas:**
   - La IA propuso inicialmente hardcodear la contraseña mediante la bandera `--password` o incluir `PGPASSWORD=admin` dentro del script `.ps1`. **Corrección:** Se eliminó toda credencial en texto plano, delegando la autenticación en variables de entorno efímeras del sistema o `.pgpass`.
   - La IA sugirió incorporar `VACUUM FULL` dentro de `maintenance.sql` para "ahorrar el máximo espacio". **Corrección:** Se rechazó enérgicamente la sugerencia debido al bloqueo exclusivo (`AccessExclusiveLock`) y caída del servicio que provocaría en Food Store, sustituyéndolo por `VACUUM (VERBOSE, ANALYZE)` no bloqueante y documentando la justificación técnica.
