# Parte 4 — Competencia de optimización

## 1. Consulta utilizada

Dado que en el repositorio no se encontró un archivo `queries.sql` ni una consulta común provista para la competencia, se definió una consulta analítica propia sobre la base masiva de TP4.

La consulta calcula, para cada cliente, la cantidad de pedidos y la facturación total, utilizando varias tablas y agregación.

```sql
SELECT
    c.id_cliente,
    c.nombre,
    c.apellido,
    COUNT(DISTINCT p.id_pedido) AS cantidad_pedidos,
    SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM cliente c
JOIN pedido p
    ON p.cliente_id = c.id_cliente
JOIN detalle_pedido dp
    ON dp.pedido_id = p.id_pedido
JOIN producto pr
    ON pr.id_producto = dp.producto_id
GROUP BY
    c.id_cliente,
    c.nombre,
    c.apellido
ORDER BY facturacion_total DESC;
```

La consulta involucra cuatro tablas, tres operaciones de `JOIN` y agregaciones mediante `COUNT(DISTINCT ...)` y `SUM(...)`.

La medición se realizó sobre `bd2_tp4`, con:

* 20.000 clientes.
* 50.000 productos.
* 200.000 pedidos.
* 200.000 detalles de pedido.

## 2. Línea base

El plan inicial utilizó tres `Hash Join`:

1. `detalle_pedido` con `producto`, mediante `dp.producto_id = pr.id_producto`.
2. El resultado anterior con `pedido`, mediante `dp.pedido_id = p.id_pedido`.
3. El resultado anterior con `cliente`, mediante `p.cliente_id = c.id_cliente`.

El plan también presentó dos situaciones relevantes:

* El hash de `pedido` utilizó `Batches: 2`, con `Memory Usage: 6736kB`.
* El ordenamiento intermedio utilizó `external merge`, con `Disk: 10584kB`.
* Se registraron `temp read=2301` y `temp written=2305`.

El tiempo de ejecución de referencia fue:

**347.167 ms**

Este valor se utilizó como baseline para comparar las alternativas.

## 3. Propuestas analizadas y resultados

### 3.1. Aumento de `work_mem`

Se probó:

```sql
SET work_mem = '32MB';
```

El cambio produjo modificaciones claras en el plan:

* El hash de `pedido` pasó de `Batches: 2` a `Batches: 1`.
* El sort intermedio pasó de `external merge` a `quicksort`.
* Desaparecieron las lecturas y escrituras temporales.
* El sort utilizó aproximadamente 19035 kB de memoria.

Sin embargo, el tiempo total aumentó:

| Situación         | Execution Time |
| ----------------- | -------------: |
| Baseline          |     347.167 ms |
| `work_mem = 32MB` |     372.108 ms |

La diferencia fue de aproximadamente **+7,18 %**.

Por este motivo, la propuesta fue **rechazada** como optimización de esta consulta.

### 3.2. Eliminación del `JOIN` con `producto`

Se eliminó:

```sql
JOIN producto pr
    ON pr.id_producto = dp.producto_id
```

La eliminación es semánticamente justificable porque ninguna columna de `producto` participa en la salida, los filtros o el agrupamiento, y `detalle_pedido.producto_id` posee una clave foránea hacia `producto.id_producto`.

El plan pasó a tener dos `Hash Join` en lugar de tres y desapareció el `Seq Scan` sobre `producto`.

Sin embargo, el tiempo aumentó:

| Situación           | Execution Time |
| ------------------- | -------------: |
| Baseline            |     347.167 ms |
| Sin `JOIN producto` |     386.447 ms |

La diferencia fue de aproximadamente **+11,32 %**.

Por este motivo, la propuesta fue **rechazada**.

### 3.3. Preagregación de `detalle_pedido`

Se probó una reescritura que primero agrupó `detalle_pedido` por `pedido_id` y calculó el total de cada pedido.

La reescritura produjo un plan diferente, con:

* `GroupAggregate` sobre `detalle_pedido`.
* `Merge Join` entre los pedidos y los detalles preagregados.
* `Hash Join` con `cliente`.
* `HashAggregate` para la agregación final.

También desapareció el sort intermedio utilizado por la consulta original.

Sin embargo, el nuevo plan presentó un `HashAggregate` final con `Batches: 5` y `Disk Usage: 1720kB`.

El tiempo obtenido fue:

| Situación     | Execution Time |
| ------------- | -------------: |
| Baseline      |     347.167 ms |
| Preagregación |     347.811 ms |

La diferencia fue de aproximadamente **+0,19 %**, por lo que no se consideró una mejora medible respecto del baseline y no se adoptó como optimización.

### 3.4. Índice `(cliente_id, id_pedido)`

Se creó experimentalmente:

```sql
CREATE INDEX idx_pedido_cliente_id_pedido
ON pedido (cliente_id, id_pedido);
```

Luego se ejecutó nuevamente la consulta original con `work_mem = 4MB`.

El optimizador no utilizó el nuevo índice. El plan continuó utilizando `Seq Scan` sobre `pedido` y mantuvo:

* tres `Hash Join`;
* `Batches: 2` para el hash de `pedido`;
* `external merge`;
* `10584 kB` de disco temporal.

El tiempo obtenido fue:

| Situación  | Execution Time |
| ---------- | -------------: |
| Baseline   |     347.167 ms |
| Con índice |     381.807 ms |

La diferencia fue de aproximadamente **+9,98 %**.

Por este motivo, la propuesta fue **rechazada**.

## 4. Registro de la competencia

| Equipo      | Estrategia aplicada                  | Tiempo antes (ms) | Tiempo después (ms) | Mejora |
| ----------- | ------------------------------------ | ----------------: | ------------------: | -----: |
| Este equipo | Baseline / sin optimización adoptada |           347.167 |             347.167 |    0 % |

No se informa una posición respecto de otros equipos porque no se dispone de sus mediciones reales.

El mejor tiempo obtenido en las pruebas realizadas fue el baseline de **347.167 ms**.

## 5. Conclusión

Las propuestas generadas por IA fueron evaluadas mediante planes reales de `EXPLAIN (ANALYZE, BUFFERS)`.

Ninguna de las cuatro estrategias probadas produjo una mejora respecto del baseline. En particular, el aumento de `work_mem` eliminó los accesos temporales a disco y modificó favorablemente algunos nodos del plan, pero aumentó el tiempo total de ejecución. Esto permitió comprobar que una modificación del plan que aparenta ser favorable no necesariamente representa una mejora de rendimiento.

La eliminación del `JOIN` con `producto` también redujo la cantidad de operaciones del plan, pero aumentó el tiempo total. La preagregación produjo un plan diferente y un tiempo prácticamente igual al baseline, por lo que no se consideró una mejora significativa. Finalmente, el índice compuesto propuesto no fue utilizado por el optimizador y también produjo un tiempo mayor.

En consecuencia, se decidió conservar el baseline como referencia de mejor tiempo medido y no adoptar ninguna de las propuestas como optimización de esta consulta.

La decisión se tomó a partir de mediciones reales y no únicamente de las predicciones de la IA.
