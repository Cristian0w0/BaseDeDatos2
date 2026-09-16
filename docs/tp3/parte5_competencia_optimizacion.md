# Parte 5 — Competencia de optimización

## 1. Aclaración sobre la consulta utilizada

Se aclara explícitamente que la consulta evaluada en esta sección corresponde a una variante propia elaborada para el desarrollo de la práctica, ya que no se contó con el enunciado o archivo de la consulta oficial provista por la cátedra para la competencia.

Las pruebas, diagnósticos y propuestas de optimización se realizaron íntegramente sobre esta consulta experimental y los datos de la base `bd2_tp3`, aplicando la metodología de análisis basada en los planes de ejecución de PostgreSQL.

## 2. Consulta de competencia

La consulta sobre la cual se realizaron las mediciones y propuestas de optimización es la siguiente:

```sql
SELECT
    p.id_producto,
    p.nombre,
    p.precio,
    SUM(dp.cantidad) AS unidades_vendidas,
    COUNT(DISTINCT dp.pedido_id) AS cantidad_pedidos
FROM producto p
JOIN detalle_pedido dp ON dp.producto_id = p.id_producto
WHERE p.categoria_id = 3
  AND p.activo = TRUE
  AND p.precio >= 500
GROUP BY p.id_producto, p.nombre, p.precio
ORDER BY unidades_vendidas DESC, p.nombre ASC
LIMIT 20;
```

## 3. Metodología

Para garantizar el rigor técnico y la reproducibilidad de los resultados, se aplicó la siguiente metodología:

- Base de datos: `bd2_tp3` (PostgreSQL).
- Herramienta de medición: inspección y contraste de planes de ejecución mediante `EXPLAIN (ANALYZE, BUFFERS)`.
- Condición de medición (caché caliente): las comparaciones se realizaron en condiciones de caché caliente, utilizando como referencia la ejecución que no presentó lecturas (`read=0`) en `shared buffers`.
- Aislamiento de pruebas DDL: las creaciones de índices experimentales se realizaron dentro de bloques de transacción (`BEGIN`), seguidas de un `ROLLBACK` inmediato tras obtener el plan de ejecución. El esquema de la base de datos no fue modificado de forma permanente.
- Verificación de equivalencia semántica: cada variante o reescritura de consulta fue validada aplicando operaciones de conjunto `EXCEPT` en ambos sentidos contra la consulta original, garantizando que el conjunto de resultados fuera idéntico.

## 4. Baseline y medición inicial

### Medición inicial

- Execution Time: **1159.192 ms**
- Buffers: `shared hit=199123 read=2018`

Esta medición inicial no se utilizó como baseline comparativo, ya que la diferencia posterior mostró una fuerte influencia del estado de caché sobre el tiempo de ejecución.

### Baseline de referencia (caché caliente)

- Execution Time: **126.422 ms**
- Buffers: `shared hit=201141 read=0`

Este valor representa el tiempo de referencia en condiciones de caché caliente contra el cual se contrastaron las propuestas.

## 5. Propuestas evaluadas

### Propuesta 1 — Índice cubriente sobre `detalle_pedido`

Definición:

```sql
CREATE INDEX idx_detalle_pedido_prod_ped_cant
ON detalle_pedido(producto_id, pedido_id, cantidad);
```

Resultado:

- Execution Time: **137.099 ms**
- PostgreSQL no utilizó el nuevo índice.
- El planificador mantuvo el uso del índice preexistente `idx_detalle_pedido_producto`.
- Se ejecutó `ROLLBACK`.

**Decisión:** propuesta rechazada.

No se afirma una causa específica para que PostgreSQL no eligiera el nuevo índice, ya que el plan observado no permite determinarla.

### Propuesta 2 — Índice parcial sobre `producto`

Definición:

```sql
CREATE INDEX idx_producto_cat3_activo_precio
ON producto(id_producto)
INCLUDE(nombre, precio)
WHERE categoria_id = 3
  AND activo = TRUE
  AND precio >= 500;
```

Resultado:

- Execution Time: **128.353 ms**
- El plan incorporó el índice mediante un `Index Only Scan`.
- `Heap Fetches: 0`.
- El tiempo total fue aproximadamente **1.9 ms mayor** que el baseline de 126.422 ms.
- Se ejecutó `ROLLBACK`.

**Decisión:** propuesta rechazada por no mejorar el tiempo total de ejecución.

### Propuesta 3 — Preagregación mediante subconsulta / CTE

Consulta reescrita:

```sql
WITH productos_filtrados AS (
    SELECT id_producto, nombre, precio
    FROM producto
    WHERE categoria_id = 3
      AND activo = TRUE
      AND precio >= 500
),
ventas_agregadas AS (
    SELECT
        dp.producto_id,
        SUM(dp.cantidad) AS unidades_vendidas,
        COUNT(DISTINCT dp.pedido_id) AS cantidad_pedidos
    FROM detalle_pedido dp
    JOIN productos_filtrados pf
        ON pf.id_producto = dp.producto_id
    GROUP BY dp.producto_id
)
SELECT
    pf.id_producto,
    pf.nombre,
    pf.precio,
    va.unidades_vendidas,
    va.cantidad_pedidos
FROM productos_filtrados pf
JOIN ventas_agregadas va
    ON va.producto_id = pf.id_producto
ORDER BY va.unidades_vendidas DESC, pf.nombre ASC
LIMIT 20;
```

Resultado:

- Execution Time: **154.218 ms**
- La reescritura fue aproximadamente **21.9 % más lenta** que el baseline.
- El plan mantuvo el procesamiento masivo de filas y utilizó, entre otros nodos, `Hash Join`, `GroupAggregate` e `Incremental Sort`.
- La equivalencia de resultados fue verificada.

**Decisión:** propuesta rechazada por degradación del rendimiento.

### Propuesta 4 — Diferir `COUNT(DISTINCT)` tras obtener el TOP 20

La estrategia separa el proceso en dos etapas dentro de la misma consulta SQL:

1. Filtrar los productos y obtener únicamente `SUM(dp.cantidad)` para ordenar y aplicar `LIMIT 20`.
2. Realizar la combinación secundaria y calcular `COUNT(DISTINCT dp.pedido_id)` exclusivamente sobre los 20 productos seleccionados.

Consulta reescrita:

```sql
WITH top_productos AS (
    SELECT
        p.id_producto,
        p.nombre,
        p.precio,
        SUM(dp.cantidad) AS unidades_vendidas
    FROM producto p
    JOIN detalle_pedido dp
        ON dp.producto_id = p.id_producto
    WHERE p.categoria_id = 3
      AND p.activo = TRUE
      AND p.precio >= 500
    GROUP BY p.id_producto, p.nombre, p.precio
    ORDER BY unidades_vendidas DESC, p.nombre ASC
    LIMIT 20
)
SELECT
    tp.id_producto,
    tp.nombre,
    tp.precio,
    tp.unidades_vendidas,
    COUNT(DISTINCT dp.pedido_id) AS cantidad_pedidos
FROM top_productos tp
JOIN detalle_pedido dp
    ON dp.producto_id = tp.id_producto
GROUP BY
    tp.id_producto,
    tp.nombre,
    tp.precio,
    tp.unidades_vendidas
ORDER BY tp.unidades_vendidas DESC, tp.nombre ASC;
```

Plan de ejecución medido:

```text
GroupAggregate (cost=8381.53..8753.56 rows=20 width=55) (actual time=105.051..105.130 rows=20 loops=1)
  Group Key: (sum(dp_1.cantidad)), p.nombre, p.id_producto, p.precio
  Buffers: shared hit=2198 read=1
  -> Incremental Sort (cost=8381.53..8752.34 rows=82 width=55) (actual time=105.045..105.106 rows=80 loops=1)
       Sort Key: (sum(dp_1.cantidad)) DESC, p.nombre, p.id_producto, p.precio, dp.pedido_id
       Presorted Key: (sum(dp_1.cantidad)), p.nombre
       Full-sort Groups: 3
       -> Nested Loop (cost=8362.09..8750.08 rows=82 width=55) (actual time=104.988..105.058 rows=80 loops=1)
            -> Limit (cost=8361.67..8361.72 rows=20 width=47) (actual time=93.585..93.591 rows=20 loops=1)
                 -> Sort (actual 93.585..93.589 rows=20 loops=1)
                      Sort Method: top-N heapsort
                      -> HashAggregate (cost=6757.84..7195.93 rows=43809 width=47) (actual time=81.018..87.023 rows=43851 loops=1)
                           Group Key: p.id_producto
                           Batches: 1 Memory Usage: 5905kB
                           -> Hash Join (actual time=11.697..55.055 rows=175404 loops=1)
                                -> Seq Scan detalle_pedido dp_1 (actual time=0.011..7.566 rows=200000 loops=1)
                                -> Hash
                                     -> Seq Scan producto p (actual time=0.007..6.455 rows=43851 loops=1)
            -> Index Scan using idx_detalle_pedido_producto on detalle_pedido dp
                 (actual time=0.571..0.572 rows=4 loops=20)
                 Index Cond: (producto_id = p.id_producto)

Planning Time: 0.336 ms
Execution Time: 106.063 ms
```

Resultado:

- Execution Time: **106.063 ms**
- Buffers: `shared hit=2198 read=1`
- Diferencia respecto del baseline: **20.359 ms menos**
- Mejora medida: **aproximadamente 16.1 %**

**Decisión:** propuesta aceptada.

## 6. Verificación de equivalencia

Se realizaron dos comparaciones mediante `EXCEPT`:

```text
Original EXCEPT Propuesta 4 = 0 filas
Propuesta 4 EXCEPT Original = 0 filas
```

Ambas consultas retornaron el mismo conjunto de 20 tuplas en la base `bd2_tp3`.

Esta verificación demuestra la equivalencia sobre los datos actuales utilizados en la práctica.

## 7. Lectura crítica

### Hechos demostrados directamente por `EXPLAIN ANALYZE`

1. El tiempo total medido pasó de **126.422 ms** en el baseline a **106.063 ms** en la Propuesta 4.
2. La Propuesta 4 presenta `shared hit=2198 read=1`, frente a `shared hit=201141 read=0` en el baseline.
3. La primera etapa utiliza un `Hash Join` sobre dos `Seq Scan` y procesa **175404 filas**.
4. El `HashAggregate` agrupa esas filas por producto y produce **43851 grupos**, utilizando un solo batch y aproximadamente **5905 kB** de memoria.
5. El nodo `Sort` utiliza el método `top-N heapsort` y produce 20 filas; el nodo completo presenta `actual time=93.585..93.589 ms`.
6. El `Nested Loop` posterior realiza **20 loops** mediante `idx_detalle_pedido_producto` y obtiene **80 filas en total**.
7. El `Incremental Sort` final opera sobre esas 80 filas.

### Interpretaciones razonables

1. La Propuesta 4 cambia el patrón de acceso de la primera etapa respecto del plan original y reduce notablemente la cantidad de buffers registrados en el plan.
2. La estrategia desplaza el cálculo de `COUNT(DISTINCT)` hacia una segunda etapa que recibe únicamente las filas correspondientes a los 20 productos seleccionados.
3. La reducción del conjunto procesado en la segunda etapa es consistente con la mejora observada en el tiempo total.

### Límites de lo que el plan permite afirmar

1. **No prueba comportamiento en caché fría:** las mediciones comparativas se realizaron en condiciones de caché caliente. No permiten predecir con certeza el comportamiento ante lecturas físicas en disco.
2. **No prueba una generalización universal:** los resultados corresponden a la distribución de datos y selectividad actuales de `bd2_tp3`. No puede afirmarse que la Propuesta 4 sea superior para cualquier volumen de datos o cualquier combinación de filtros.
3. **No permite atribuir tiempos individuales mediante simples restas entre nodos:** los tiempos de nodos hijo forman parte del procesamiento acumulado de sus nodos padre, por lo que no es técnicamente riguroso asignar costos absolutos mediante una simple resta de tiempos heterogéneos.
4. La diferencia de `shared hit` muestra una diferencia en accesos a buffers, pero por sí sola no permite atribuir toda la mejora de 20.359 ms a una única causa.

## 8. Decisión final

Para esta consulta de competencia experimental, se seleccionó la **Propuesta 4 — Diferir `COUNT(DISTINCT)`** porque:

1. Mantiene equivalencia semántica verificada en ambos sentidos mediante `EXCEPT`.
2. Reduce el tiempo de ejecución medido de **126.422 ms a 106.063 ms**, una mejora aproximada del **16.1 %**.
3. Logra la optimización mediante la reestructuración de la consulta SQL, sin requerir la creación de nuevos índices permanentes en la base de datos.

La selección corresponde exclusivamente a esta **variante experimental propia** y no debe interpretarse como resultado de una competencia oficial de la cátedra.
