# DUIA — TP4 Parte 4: Competencia de optimización

## Herramienta utilizada

**OpenCode / Gemini 3.6**

## Uso de IA

Se proporcionó a la IA el plan real obtenido mediante `EXPLAIN (ANALYZE, BUFFERS)` de la consulta de competencia.

Se solicitó que:

* identificara los algoritmos de `JOIN`;
* explicara las relaciones Build/Probe de los `Hash Join`;
* identificara los principales costos del plan;
* analizara los `Batches` y el uso de archivos temporales;
* propusiera reescrituras SQL, índices y cambios de configuración;
* justificara cada propuesta a partir de nodos concretos del plan;
* indicara qué métricas debían medirse después de cada cambio.

La IA recibió el plan real con un tiempo inicial de **347.167 ms**.

## Propuestas generadas por la IA

### 1. Aumentar `work_mem` a 32 MB

La IA observó:

* `Batches: 2` en el hash de `pedido`;
* `external merge` en el sort intermedio;
* `Disk: 10584kB`;
* `temp read=2301`;
* `temp written=2305`.

Propuso utilizar:

```sql id="2m3m5t"
SET work_mem = '32MB';
```

**Decisión:** rechazada.

**Resultado medido:** 372.108 ms.

Aunque la modificación eliminó los archivos temporales, cambió el hash de `pedido` a `Batches: 1` y el sort a `quicksort`, el tiempo total aumentó aproximadamente un **7,18 %** respecto del baseline.

Se priorizó el tiempo real de ejecución sobre la apariencia del plan.

### 2. Eliminar el `JOIN` con `producto`

La IA detectó que ninguna columna de `producto` se utilizaba en la salida, filtros o agrupamiento y propuso eliminar:

```sql id="zq3r3r"
JOIN producto pr
    ON pr.id_producto = dp.producto_id
```

**Decisión:** rechazada.

**Resultado medido:** 386.447 ms.

Aunque desapareció un `Hash Join` y el `Seq Scan` de `producto`, el tiempo aumentó aproximadamente un **11,32 %** respecto del baseline.

### 3. Preagregar `detalle_pedido`

La IA propuso agrupar previamente los detalles por `pedido_id`, calculando el total de cada pedido antes de unirlos con `pedido` y `cliente`.

**Decisión:** no adoptada.

**Resultado medido:** 347.811 ms.

La reescritura generó un plan diferente, con `GroupAggregate`, `Merge Join` y `HashAggregate`, y eliminó el sort intermedio de la consulta original. Sin embargo, el tiempo fue aproximadamente **0,19 % mayor** que el baseline.

Al no existir una mejora medible, se decidió conservar la consulta original.

### 4. Índice compuesto `(cliente_id, id_pedido)`

La IA propuso crear:

```sql id="qkqpy8"
CREATE INDEX idx_pedido_cliente_id_pedido
ON pedido (cliente_id, id_pedido);
```

La hipótesis era que el índice podría ayudar con el orden requerido por la agregación.

**Decisión:** rechazada.

**Resultado medido:** 381.807 ms.

El optimizador no utilizó el índice. El plan continuó utilizando `Seq Scan` sobre `pedido`, tres `Hash Join`, `Batches: 2` y `external merge`.

El tiempo aumentó aproximadamente un **9,98 %** respecto del baseline.

## Validación crítica de las propuestas

Las propuestas de IA no fueron aceptadas automáticamente.

Cada una fue ejecutada de forma independiente y medida mediante:

```sql
EXPLAIN (ANALYZE, BUFFERS)
```

La comparación se realizó contra el baseline de **347.167 ms**.

Los resultados demostraron que:

* eliminar I/O temporal no implicó una reducción del tiempo total;
* eliminar un `JOIN` no garantizó una mejora;
* una reescritura con un plan estructuralmente diferente no produjo una mejora medible;
* crear un índice no garantiza que el optimizador lo utilice ni que la consulta resulte más rápida.

Por lo tanto, las decisiones finales se basaron en las mediciones reales y no solamente en las predicciones de la IA.

## Registro de propuestas descartadas

| Propuesta                        | Resultado   | Motivo                                  |
| -------------------------------- | ----------- | --------------------------------------- |
| `work_mem = 32MB`                | Rechazada   | 372.108 ms, mayor que el baseline       |
| Eliminar `JOIN producto`         | Rechazada   | 386.447 ms, mayor que el baseline       |
| Preagregación                    | No adoptada | 347.811 ms, sin mejora                  |
| Índice `(cliente_id, id_pedido)` | Rechazada   | 381.807 ms y el índice no fue utilizado |

## Conclusión

La IA fue utilizada como asistente para analizar el plan y generar hipótesis de optimización. Las propuestas fueron revisadas antes de aplicarse y se validaron mediante mediciones reales.

Ninguna propuesta produjo una mejora respecto del baseline de **347.167 ms**. Por ese motivo, no se forzó una optimización artificial y se conservó el baseline como mejor tiempo medido.

La experiencia permitió comprobar que una modificación que mejora una característica aislada del plan —por ejemplo, eliminar `Batches` o evitar un `external merge`— no necesariamente mejora el tiempo total de ejecución.
