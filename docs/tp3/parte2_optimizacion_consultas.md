# Parte 2 — Laboratorio: consultas lentas, EXPLAIN y optimización medida

## 2.1 Metodología

Para esta parte se trabajó sobre la copia de la base de datos destinada al TP3 (`bd2_tp3`), que contiene datos masivos:

* 20.000 clientes.
* 50.000 productos.
* 200.000 pedidos.
* 200.000 detalles de pedidos.

Se seleccionaron tres consultas propias sobre el modelo, ya que el repositorio no contiene un archivo `queries.sql`. Las consultas fueron elegidas buscando operaciones que presentaran un costo apreciable sobre la base masiva.

Para cada consulta se siguió el flujo indicado por la cátedra:

1. Ejecutar `EXPLAIN (ANALYZE, BUFFERS)` antes de realizar modificaciones.
2. Analizar el plan real obtenido.
3. Solicitar a la IA propuestas de optimización.
4. Revisar cada propuesta antes de aplicarla.
5. Probar los cambios dentro de una transacción.
6. Ejecutar nuevamente `EXPLAIN (ANALYZE, BUFFERS)`.
7. Comparar los resultados y decidir si la propuesta se acepta o se rechaza según la medición obtenida.

La decisión final no se tomó únicamente a partir de la recomendación de la IA, sino de la comparación entre los planes y tiempos reales obtenidos.

---

# 2.2 Tabla comparativa

| Consulta                                                       | Plan / tiempo antes                                                                     | Optimización propuesta                                                                                   | Plan / tiempo después                                                                                                                    | Resultado                         |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| **1. Pedidos de los últimos 30 días con cliente y detalle**    | `Seq Scan` sobre `pedido` y `detalle_pedido`, seguido de `Hash Join`. **54.368 ms**     | Crear `idx_pedido_fecha` sobre `pedido(fecha_pedido)`                                                    | `Bitmap Index Scan` + `Bitmap Heap Scan` sobre `pedido`. Se mantuvieron los `Seq Scan` sobre `detalle_pedido` y `cliente`. **32.677 ms** | **Aceptada. Mejora ≈39,9 %.**     |
| **2. Productos activos de una categoría ordenados por nombre** | `Seq Scan` sobre `producto` y posteriormente `Sort`. **350.253 ms**                     | Crear `idx_producto_categoria_activo_nombre` sobre `(categoria_id, activo, nombre)`                      | `Index Scan` utilizando el nuevo índice. Desaparece el `Sort`. **9.490 ms**                                                              | **Aceptada. Mejora ≈97,3 %.**     |
| **3. Detalles de pedidos de los últimos 7 días**               | `Seq Scan` sobre los 200.000 registros de `detalle_pedido` + `Hash Join`. **19.589 ms** | Crear índice covering sobre `detalle_pedido(pedido_id) INCLUDE (producto_id, cantidad, precio_unitario)` | El plan continuó utilizando `Seq Scan` sobre `detalle_pedido` y `Hash Join`. **19.827 ms**                                               | **Rechazada. No produjo mejora.** |

---

# 2.3 Consulta 1 — Pedidos de los últimos 30 días

## Consulta utilizada

```sql
SELECT
    p.id_pedido,
    p.fecha_pedido,
    c.nombre,
    c.apellido,
    dp.producto_id,
    dp.cantidad,
    dp.precio_unitario
FROM pedido p
JOIN cliente c ON c.id_cliente = p.cliente_id
JOIN detalle_pedido dp ON dp.pedido_id = p.id_pedido
WHERE p.fecha_pedido >= now() - INTERVAL '30 days';
```

## Medición inicial

El plan inicial mostró un `Seq Scan on pedido`, recorriendo los 200.000 pedidos y descartando aproximadamente 183.570 registros:

```text
Seq Scan on pedido p
actual ... rows=16430
Rows Removed by Filter: 183570
```

También se realizó un `Seq Scan` sobre los 200.000 registros de `detalle_pedido`.

El tiempo total de ejecución fue:

```text
Execution Time: 54.368 ms
```

El principal punto de interés era el filtrado de `pedido` por `fecha_pedido`.

## Propuesta de la IA

Se propuso crear un índice sobre la columna utilizada en el filtro:

```sql
CREATE INDEX idx_pedido_fecha
    ON pedido (fecha_pedido);
```

La propuesta fue revisada antes de aplicarla. Su objetivo era permitir que PostgreSQL localizara directamente los pedidos correspondientes al rango temporal, evitando recorrer toda la tabla de `pedido`.

## Prueba controlada

El índice fue probado dentro de una transacción y posteriormente se comparó el nuevo plan.

El nuevo plan utilizó:

```text
Bitmap Index Scan on idx_pedido_fecha
Bitmap Heap Scan on pedido
```

El `Seq Scan` sobre `detalle_pedido` continuó existiendo, pero el acceso a `pedido` fue más selectivo.

Tiempo obtenido:

```text
Execution Time: 31.248 ms
```

La mejora fue suficiente para aceptar la propuesta.

Posteriormente, el índice se aplicó de forma permanente y se volvió a medir:

```text
Execution Time: 32.677 ms
```

Comparando con el valor inicial:

```text
54.368 ms → 32.677 ms
```

La reducción fue aproximadamente del **39,9 %**.

## Decisión

**Propuesta aceptada.**

El índice `idx_pedido_fecha` se incorporó al esquema porque modificó el acceso a la tabla `pedido` y produjo una mejora significativa en la medición real.

---

# 2.4 Consulta 2 — Productos activos de una categoría

## Consulta utilizada

```sql
SELECT
    p.id_producto,
    p.nombre,
    p.precio,
    p.stock
FROM producto p
WHERE p.categoria_id = 3
  AND p.activo = TRUE
ORDER BY p.nombre;
```

## Medición inicial

El plan inicial mostró:

```text
Seq Scan on producto
Sort
```

La consulta encontraba 46.667 productos de los 50.000 existentes y luego debía ordenar todos esos resultados por `nombre`.

El nodo `Sort` representaba la principal carga de la consulta.

Tiempo total:

```text
Execution Time: 350.253 ms
```

## Propuesta de la IA

Se propuso crear un índice compuesto que incluyera tanto las columnas utilizadas para filtrar como la utilizada para ordenar:

```sql
CREATE INDEX idx_producto_categoria_activo_nombre
    ON producto (categoria_id, activo, nombre);
```

La propuesta fue revisada antes de aplicarla.

La razón de la elección es que las primeras columnas permiten resolver las condiciones del `WHERE` y `nombre`, como tercera columna del índice, permite entregar los registros en el orden requerido.

## Prueba controlada

Con el nuevo índice, el plan cambió a:

```text
Index Scan using idx_producto_categoria_activo_nombre on producto
```

El nodo `Sort` desapareció completamente.

Tiempo obtenido en la prueba:

```text
Execution Time: 9.859 ms
```

La mejora fue muy significativa, por lo que se decidió conservar el índice.

También se evaluó el índice anterior:

```text
idx_producto_categoria_activo
```

Como el nuevo índice comienza con las mismas columnas `(categoria_id, activo)`, el índice anterior resultaba redundante para el patrón de consulta utilizado. Por ello se eliminó el índice anterior y se conservó el nuevo.

## Medición final

Luego de aplicar permanentemente el cambio se volvió a ejecutar `EXPLAIN (ANALYZE, BUFFERS)`.

Resultado:

```text
Index Scan using idx_producto_categoria_activo_nombre on producto
Execution Time: 9.490 ms
```

Comparación:

```text
350.253 ms → 9.490 ms
```

La reducción del tiempo fue aproximadamente del **97,3 %**, equivalente a una ejecución aproximadamente **35 veces más rápida**.

## Decisión

**Propuesta aceptada.**

El nuevo índice permite resolver el filtrado y entregar los resultados ordenados, eliminando el costoso `Sort`.

---

# 2.5 Consulta 3 — Detalles de pedidos de los últimos 7 días

## Consulta utilizada

```sql
SELECT
    dp.pedido_id,
    dp.producto_id,
    dp.cantidad,
    dp.precio_unitario
FROM detalle_pedido dp
JOIN pedido p
    ON p.id_pedido = dp.pedido_id
WHERE p.fecha_pedido >= now() - INTERVAL '7 days';
```

## Medición inicial

El plan mostró como principal operación:

```text
Seq Scan on detalle_pedido dp
```

La tabla completa de `detalle_pedido` fue recorrida:

```text
actual ... rows=200000
```

mientras que la consulta finalmente devolvió aproximadamente 3.819 registros.

El plan utilizó además un `Hash Join`.

Tiempo inicial:

```text
Execution Time: 19.589 ms
```

En el lado de `pedido` ya se estaba utilizando correctamente el índice:

```text
Bitmap Index Scan on idx_pedido_fecha
```

Por lo tanto, el problema potencial se encontraba principalmente en el acceso a `detalle_pedido`.

## Propuesta de la IA

Se propuso probar un índice covering:

```sql
CREATE INDEX idx_detalle_pedido_covering
    ON detalle_pedido (pedido_id)
    INCLUDE (producto_id, cantidad, precio_unitario);
```

La idea era permitir que PostgreSQL pudiera obtener los datos necesarios desde el índice y, potencialmente, utilizar un `Index Only Scan`.

La propuesta se consideró plausible, pero no se aceptó automáticamente.

## Prueba controlada

El índice fue creado únicamente dentro de una transacción y se volvió a ejecutar la misma consulta.

El resultado mostró que PostgreSQL **no utilizó el nuevo índice**.

El plan continuó utilizando:

```text
Hash Join
Seq Scan on detalle_pedido
Bitmap Heap Scan on pedido
Bitmap Index Scan on idx_pedido_fecha
```

El `Seq Scan` continuó recorriendo los 200.000 registros de `detalle_pedido`.

El tiempo obtenido fue:

```text
Execution Time: 19.827 ms
```

Comparación:

```text
19.589 ms → 19.827 ms
```

La consulta no presentó una mejora. La diferencia de 0,238 ms representa una variación muy pequeña y no constituye una optimización significativa.

Además, no apareció el esperado:

```text
Index Only Scan
```

## Decisión

**Propuesta rechazada.**

El índice experimental no se dejó instalado porque no modificó el plan de ejecución ni produjo una mejora significativa en el tiempo.

La prueba fue revertida mediante `ROLLBACK`.

Este resultado es importante porque demuestra que una propuesta de optimización de la IA debe ser validada mediante mediciones reales. La existencia de un índice potencialmente útil no garantiza que PostgreSQL vaya a utilizarlo ni que su utilización resulte más eficiente.

---

# 2.6 Conclusiones

El laboratorio permitió comprobar que la optimización de consultas debe basarse en el plan de ejecución y en mediciones reales, y no solamente en recomendaciones teóricas.

En la **Consulta 1**, el índice sobre `fecha_pedido` permitió que PostgreSQL utilizara un acceso mediante índice para localizar los pedidos correspondientes al rango temporal. La ejecución final pasó de **54.368 ms a 32.677 ms**, por lo que la propuesta fue aceptada.

En la **Consulta 2**, el índice compuesto sobre `(categoria_id, activo, nombre)` produjo el cambio más significativo. El plan pasó de realizar un `Seq Scan` seguido de un `Sort` a utilizar un `Index Scan`, eliminando el ordenamiento explícito. El tiempo pasó de **350.253 ms a 9.490 ms**, una reducción aproximada del **97,3 %**.

En la **Consulta 3**, la propuesta de crear un índice covering sobre `detalle_pedido` no produjo el resultado esperado. PostgreSQL continuó utilizando un `Seq Scan` y un `Hash Join`, y el tiempo pasó de **19.589 ms a 19.827 ms**. Por este motivo, la propuesta fue rechazada y el cambio se revirtió.

Estos resultados permiten aplicar el criterio central del trabajo:

> **La IA propone, pero el estudiante verifica.**

Las decisiones de optimización se tomaron únicamente después de observar los planes reales obtenidos mediante `EXPLAIN (ANALYZE, BUFFERS)`. Las propuestas que demostraron una mejora medible fueron incorporadas al esquema, mientras que la propuesta que no produjo una mejora fue descartada.
