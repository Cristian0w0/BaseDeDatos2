# Parte 1 — Laboratorio de consultas analíticas

## 1.1 Consultas seleccionadas

El repositorio no contiene un archivo `queries.sql` con las consultas indicadas por la consigna. Por ese motivo se seleccionaron dos consultas propias sobre la base masiva `bd2_tp4`, ambas con múltiples JOIN y agregación:

1. **Gasto total por cliente**
2. **Ventas por mes**

Las mediciones se realizaron mediante `EXPLAIN (ANALYZE, BUFFERS)`.

### Consulta 1 — Gasto total por cliente

```sql
SELECT
    c.id_cliente,
    c.nombre,
    c.apellido,
    SUM(dp.cantidad * dp.precio_unitario) AS gasto_total,
    COUNT(DISTINCT p.id_pedido) AS cantidad_pedidos
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
ORDER BY gasto_total DESC;
```

### Plan inicial

El plan inicial tuvo un tiempo de ejecución de **363.367 ms**.

Se observaron tres `Hash Join`:

* `detalle_pedido` con `producto`, mediante `dp.producto_id = pr.id_producto`.
* `detalle_pedido` con `pedido`, mediante `dp.pedido_id = p.id_pedido`.
* `pedido` con `cliente`, mediante `p.cliente_id = c.id_cliente`.

El plan también presentó un `Sort` intermedio por `c.id_cliente, p.id_pedido` que utilizó `external merge` y escribió aproximadamente 11 MB en disco. El `Hash` correspondiente a `pedido` utilizó dos batches, debido al límite de `work_mem` de 4 MB.

### Cambios evaluados

#### Eliminación del JOIN con `producto`

La consulta no utilizaba ninguna columna de `producto`, ni aplicaba filtros o agrupamientos sobre esa tabla. Se probó eliminar ese JOIN.

Tiempo obtenido: **336.497 ms**.

La propuesta fue aceptada porque redujo el tiempo respecto del plan inicial, aproximadamente un **7.4 %**.

#### Preagregación de `detalle_pedido`

Se probó agrupar previamente los detalles por pedido para reducir la cantidad de filas que atravesaban los JOIN posteriores.

Tiempo obtenido: **386.370 ms**.

La propuesta fue rechazada porque resultó más lenta que la versión anterior.

#### Aumento de `work_mem` a 32 MB

Se probó la consulta sin el JOIN redundante a `producto`, utilizando:

```sql
SET work_mem = '32MB';
```

Tiempo obtenido: **252.942 ms**.

El cambio permitió que el `Sort` intermedio utilizara `quicksort` en memoria y que el `Hash` de `pedido` utilizara un solo batch, eliminando el uso de archivos temporales observado con 4 MB.

El cambio fue aceptado para la medición de esta consulta.

### Resultado de la consulta 1

La mejor medición obtenida fue **252.942 ms**, frente a **363.367 ms** del plan inicial, lo que representa una mejora aproximada del **30.4 %**.

El algoritmo de JOIN continuó siendo `Hash Join`; la mejora provino principalmente de eliminar un JOIN que no aportaba información al resultado y de evitar el derrame a disco mediante un `work_mem` mayor.

---

## Consulta 2 — Ventas por mes

```sql
SELECT
    DATE_TRUNC('month', p.fecha_pedido) AS mes,
    COUNT(DISTINCT p.id_pedido) AS cantidad_pedidos,
    SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM pedido p
JOIN detalle_pedido dp
    ON dp.pedido_id = p.id_pedido
JOIN producto pr
    ON pr.id_producto = dp.producto_id
JOIN categoria c
    ON c.id_categoria = pr.categoria_id
GROUP BY DATE_TRUNC('month', p.fecha_pedido)
ORDER BY mes;
```

### Plan inicial

El tiempo de ejecución inicial fue de **318.813 ms**.

Se observaron:

* Un `Hash Join` entre `detalle_pedido` y `producto`.
* Un `Nested Loop` con `categoria`.
* Un `Hash Join` entre `detalle_pedido` y `pedido`.

También se observó un `Sort` intermedio que utilizó `external merge` y escribió aproximadamente 7 MB en disco.

Los JOIN con `producto` y `categoria` no aportaban columnas al resultado ni condiciones de filtrado, por lo que se evaluó su eliminación.

### Cambios evaluados

#### Eliminación de JOIN redundantes

Se eliminaron los JOIN con `producto` y `categoria`, ya que ninguna columna de esas tablas participa en la salida, filtros o agrupamiento.

Con `work_mem` de 4 MB se obtuvo:

**282.958 ms**

La mejora respecto del plan inicial fue de aproximadamente **11.2 %**.

El cambio fue aceptado.

#### Aumento de `work_mem` a 32 MB

Sobre la versión sin los JOIN redundantes se probó:

```sql
SET work_mem = '32MB';
```

Tiempo obtenido:

**203.783 ms**

El aumento de `work_mem` permitió evitar el uso de archivos temporales durante el ordenamiento y reducir el procesamiento asociado al `Hash` de `pedido`.

La mejora respecto del plan inicial fue de aproximadamente **36.1 %**.

El cambio fue aceptado para la medición.

#### Preagregación de `detalle_pedido`

También se evaluó una reescritura que preagregaba los detalles por pedido.

Con `work_mem` de 4 MB se obtuvo:

**268.162 ms**

La propuesta mostró una mejora respecto de la versión sin los JOIN redundantes y con `work_mem` de 4 MB, pero no superó la mejor medición obtenida con `work_mem` de 32 MB.

Por ese motivo no se adoptó como estrategia final de esta consulta.

---

## 1.2 Comparación antes/después

| Consulta                | Algoritmo de JOIN (antes) | Cambio aplicado                                          | Algoritmo de JOIN (después) | Mejora |
| ----------------------- | ------------------------- | -------------------------------------------------------- | --------------------------- | -----: |
| Gasto total por cliente | Hash Join                 | Eliminar JOIN `producto` + `work_mem = 32MB`             | Hash Join                   | 30.4 % |
| Ventas por mes          | Hash Join + Nested Loop   | Eliminar JOIN `producto`/`categoria` + `work_mem = 32MB` | Hash Join                   | 36.1 % |

## Conclusiones

Las mediciones muestran que el costo de estas consultas no dependía únicamente de la cantidad de tablas involucradas, sino también de la cantidad de filas que atravesaban los JOIN y de los recursos disponibles para las operaciones de ordenamiento y hashing.

La eliminación de JOIN redundantes produjo mejoras medibles porque evitó trabajo que no modificaba el resultado solicitado.

El aumento de `work_mem` fue especialmente relevante cuando los planes iniciales mostraban `external merge`, batches adicionales y utilización de archivos temporales. Con 32 MB, esas operaciones pudieron realizarse en memoria para estas consultas y mediciones.

La propuesta de preagregar `detalle_pedido` no se aceptó como optimización principal porque, aunque parecía reducir filas antes de los JOIN, en las mediciones realizadas produjo tiempos superiores a las mejores alternativas.

Todas las propuestas fueron revisadas mediante `EXPLAIN ANALYZE` antes de ser aceptadas o rechazadas.
