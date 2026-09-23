# Declaración de Uso de Inteligencia Artificial — TP5

**Materia:** Base de Datos 2
**Proyecto:** Food Store
**Motor:** PostgreSQL
**Base de datos utilizada:** `bd2_tp5`

## Declaración general

Durante el desarrollo del Trabajo Práctico 5 se utilizaron herramientas de Inteligencia Artificial como apoyo para la especificación, generación y revisión de índices, vistas y una vista materializada.

La IA se utilizó como herramienta de asistencia técnica. Las propuestas generadas fueron analizadas y verificadas mediante consultas SQL, `EXPLAIN (ANALYZE, BUFFERS)`, comparación de resultados y revisión de los archivos generados.

Las decisiones finales sobre qué propuestas aceptar, modificar o descartar fueron tomadas por el estudiante.

---

# Parte A — Índices

## A.1 — Índice `idx_pedido_tarjeta_fecha`

### Herramienta utilizada

**Kiro**, para especificar el índice a partir de la consulta y del patrón de uso.

### Especificación

Se buscó optimizar una consulta frecuente sobre `pedido` que:

* filtra por `forma_pago = 'TARJETA'`;
* filtra por una fecha mínima;
* ordena por `fecha_pedido DESC`;
* trabaja sobre una tabla de 200000 filas.

El prompt original no se conserva literalmente, por lo que la especificación documentada en `specs/indice_pedido_tarjeta_fecha.md` se considera la referencia utilizada para la generación.

### Propuesta de IA

La propuesta fue crear un índice parcial B-tree:

```sql
CREATE INDEX idx_pedido_tarjeta_fecha
    ON pedido (fecha_pedido DESC)
    WHERE forma_pago = 'TARJETA';
```

### Decisión

**Aceptado.**

La propuesta fue aceptada porque el predicado parcial limita el índice a los pedidos con forma de pago `TARJETA` y el orden sobre `fecha_pedido DESC` coincide con el patrón de consulta.

### Verificación

Consulta utilizada:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.id_pedido,
    p.cliente_id,
    p.fecha_pedido,
    p.forma_pago
FROM pedido p
WHERE p.fecha_pedido >= TIMESTAMPTZ '2026-01-01'
  AND p.forma_pago = 'TARJETA'
ORDER BY p.fecha_pedido DESC;
```

Antes del índice:

* Plan principal: `Seq Scan` sobre `pedido`.
* Filas devueltas: 46863.
* Filas descartadas: 153137.
* Execution Time: **18.877 ms**.

Después del índice:

* Plan principal: `Bitmap Heap Scan` utilizando `idx_pedido_tarjeta_fecha`.
* Filas devueltas: 46863.
* Execution Time: **17.588 ms**.

La diferencia fue de **1.289 ms**, aproximadamente un **6.8 %** de reducción en esta medición.

También se verificó una variante con `LIMIT 100`, donde el índice permitió resolver directamente el orden:

* Plan: `Index Scan`.
* Execution Time: **0.129 ms**.
* No se realizó un `Sort`.

Esta última medición corresponde a una consulta diferente porque incorpora `LIMIT 100`, por lo que no se utiliza como comparación directa con los 18.877 ms de la consulta original.

---

## A.2 — Índice `idx_producto_activo_precio`

### Herramienta utilizada

**Kiro**, para especificar el índice a partir de la consulta y su patrón de uso.

### Especificación

Se buscó optimizar una consulta que:

* filtra productos activos;
* ordena por `precio DESC`;
* utiliza `LIMIT 100`;
* trabaja sobre una tabla de 50000 productos.

El prompt original no se conserva literalmente, por lo que la especificación documentada en `specs/indice_producto_activo_precio.md` se considera la referencia utilizada.

### Propuesta de IA

```sql
CREATE INDEX idx_producto_activo_precio
    ON producto (precio DESC)
    WHERE activo = TRUE;
```

### Decisión

**Aceptado.**

El índice parcial evita incorporar al índice los productos inactivos y permite utilizar el orden de `precio DESC` para obtener los primeros resultados sin realizar un ordenamiento completo.

### Verificación

Consulta utilizada:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    p.id_producto,
    p.nombre,
    p.precio,
    p.stock
FROM producto p
WHERE p.activo = TRUE
ORDER BY p.precio DESC
LIMIT 100;
```

Antes del índice:

* `Seq Scan` sobre 50000 productos.
* 46667 productos activos.
* 3333 productos descartados.
* Se realizó `top-N heapsort`.
* Execution Time: **10.446 ms**.

Después del índice:

* `Index Scan` utilizando `idx_producto_activo_precio`.
* No se realizó `Sort`.
* Se obtuvieron directamente las primeras 100 filas.
* Execution Time: **0.150 ms**.

La reducción medida fue de aproximadamente **98.6 %**.

---

## A.3 — Propuesta rechazada: `idx_producto_activo_id`

### Herramienta utilizada

**Kiro**, para analizar una consulta que une `detalle_pedido` con `producto` y filtra por productos activos.

### Consulta analizada

```sql
SELECT
    dp.pedido_id,
    dp.producto_id,
    dp.cantidad,
    dp.precio_unitario,
    pr.nombre,
    pr.precio
FROM detalle_pedido dp
JOIN producto pr
    ON pr.id_producto = dp.producto_id
WHERE pr.activo = TRUE;
```

### Propuesta de IA

```sql
CREATE INDEX idx_producto_activo_id
    ON producto (id_producto)
    WHERE activo = TRUE;
```

### Decisión

**Rechazado.**

La propuesta fue descartada por razones de sobreindexación y falta de beneficio demostrado:

* `id_producto` ya posee un índice debido a la clave primaria de `producto`.
* La condición `activo = TRUE` tiene baja selectividad en este conjunto de datos: 46667 de 50000 productos están activos, aproximadamente el **93.3 %**.
* La consulta devuelve una cantidad muy grande de filas y no utiliza `LIMIT`.
* El plan elegido por PostgreSQL fue un `Hash Join` con recorridos secuenciales, apropiado para procesar una gran parte de las tablas.

Medición sin el índice:

* Execution Time: **62.514 ms**.

Se realizó además una prueba experimental creando temporalmente el índice propuesto.

Con el índice:

* Execution Time: **60.987 ms**.
* El plan no cambió.

La diferencia no se consideró una mejora significativa atribuible al índice, debido a que el plan permaneció igual y la variación observada puede corresponder a variabilidad normal entre ejecuciones.

El índice experimental fue eliminado después de la prueba.

Esta decisión constituye el caso de **sobreindexación rechazado** solicitado por la consigna.

---

## A.4 — Medición de escrituras

También se realizó una prueba sobre inserciones en `detalle_pedido` para observar el comportamiento de escritura.

Se utilizaron inserciones de prueba dentro de una transacción que posteriormente fue revertida mediante `ROLLBACK`.

### Antes

* 500 filas.
* Execution Time: **58.269 ms**.

### Después

* 500 filas.
* Execution Time: **54.031 ms**.

La diferencia fue de aproximadamente **7.3 %**, pero no se atribuyó a los índices aceptados.

Los índices agregados en TP5 se encuentran sobre `pedido` y `producto`, mientras que la operación de inserción se realiza sobre `detalle_pedido`. Además, el plan de ejecución permaneció igual.

Por lo tanto, la diferencia observada se considera variabilidad de ejecución y no evidencia de un costo o beneficio directo producido por los nuevos índices.

---

# Parte B — Vistas

## B.1 — `v_productos_vigentes`

### Herramienta utilizada

**Kiro**, para especificar una vista que represente el reporte de productos vigentes.

### Propuesta

La vista debía:

* incluir únicamente productos activos;
* incluir información de la categoría;
* exponer explícitamente las columnas necesarias;
* evitar exponer columnas innecesarias.

La propuesta implementada fue:

```sql
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT
    p.id_producto,
    p.nombre,
    p.precio,
    p.stock,
    p.categoria_id,
    c.nombre AS nombre_categoria
FROM producto p
INNER JOIN categoria c
    ON c.id_categoria = p.categoria_id
WHERE p.activo = TRUE;
```

### Decisión

**Aceptado.**

### Verificación de equivalencia

La vista produjo **46667 filas**.

Se comparó la consulta de referencia contra la vista mediante `EXCEPT` en ambas direcciones.

Resultado:

* Diferencias consulta → vista: **0**
* Diferencias vista → consulta: **0**

Por lo tanto, se verificó equivalencia de resultados para el conjunto de datos utilizado.

---

## B.2 — `v_pedidos_con_cliente`

### Herramienta utilizada

**Kiro**, para especificar una vista que combine pedidos con los datos necesarios del cliente.

### Propuesta

La vista utiliza una lista explícita de columnas:

```sql
CREATE OR REPLACE VIEW v_pedidos_con_cliente AS
SELECT
    p.id_pedido,
    p.cliente_id,
    p.fecha_pedido,
    p.forma_pago,
    c.nombre,
    c.apellido,
    c.email
FROM pedido p
INNER JOIN cliente c
    ON c.id_cliente = p.cliente_id;
```

### Decisión

**Aceptado.**

El uso de una lista explícita de columnas evita exponer automáticamente nuevas columnas que pudieran agregarse posteriormente a las tablas.

### Criterio de seguridad

La consigna solicita considerar la exposición de información mediante vistas.

En el esquema utilizado, la tabla `cliente` **no contiene contraseñas, tokens ni credenciales**. Por ese motivo no se modificó el esquema para agregar una credencial ficticia ni se afirmó que existieran permisos de roles específicos que no fueron configurados.

La vista expone únicamente los datos necesarios para el reporte.

### Verificación de equivalencia

La vista produjo **200000 filas**.

Resultado de las comparaciones mediante `EXCEPT`:

* Diferencias consulta → vista: **0**
* Diferencias vista → consulta: **0**

---

## B.3 — `v_detalle_pedido_con_producto`

### Herramienta utilizada

**Kiro**, para especificar una vista que relacione las líneas de pedido con los productos.

### Propuesta

```sql
CREATE OR REPLACE VIEW v_detalle_pedido_con_producto AS
SELECT
    dp.pedido_id,
    dp.producto_id,
    dp.cantidad,
    dp.precio_unitario,
    pr.nombre AS nombre_producto
FROM detalle_pedido dp
INNER JOIN producto pr
    ON pr.id_producto = dp.producto_id;
```

### Decisión

**Aceptado.**

No se agregó un filtro `pr.activo = TRUE`, ya que el objetivo es preservar la información histórica de las ventas realizadas, incluso si un producto deja de estar activo.

### Verificación de equivalencia

La vista produjo **200000 filas**.

Resultado:

* Diferencias consulta → vista: **0**
* Diferencias vista → consulta: **0**

Las tres vistas fueron verificadas mediante comparación bidireccional con `EXCEPT`.

---

# Parte C — Vista materializada

## C.1 — `v_resumen_gasto_cliente`

### Herramienta utilizada

**Kiro**, para especificar una vista materializada destinada a un reporte agregado costoso.

### Reporte seleccionado

Se seleccionó el ranking de clientes por gasto total utilizado previamente en las consultas de TP4.

La consulta original requiere combinar:

* `cliente`;
* `pedido`;
* `detalle_pedido`;

y calcular:

```sql
SUM(dp.cantidad * dp.precio_unitario)
```

agrupado por cliente.

### Propuesta de IA

```sql
CREATE MATERIALIZED VIEW v_resumen_gasto_cliente AS
SELECT
    c.id_cliente,
    c.nombre || ' ' || c.apellido AS nombre_completo,
    SUM(dp.cantidad * dp.precio_unitario) AS gasto_total
FROM cliente c
INNER JOIN pedido p
    ON p.cliente_id = c.id_cliente
INNER JOIN detalle_pedido dp
    ON dp.pedido_id = p.id_pedido
GROUP BY c.id_cliente, c.nombre, c.apellido
WITH DATA;

CREATE UNIQUE INDEX idx_v_resumen_gasto_cliente_cliente
    ON v_resumen_gasto_cliente (id_cliente);
```

### Decisión

**Aceptado.**

La vista fue creada con `WITH DATA`, por lo que quedó cargada inmediatamente con los datos disponibles.

Contiene **20000 filas**.

El índice único sobre `id_cliente` permite utilizar posteriormente:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY v_resumen_gasto_cliente;
```

La operación fue ejecutada y finalizó correctamente.

`REFRESH MATERIALIZED VIEW CONCURRENTLY` no constituye una actualización incremental de la vista. Es una modalidad de refresco que permite mantener disponible el contenido de la vista para las consultas durante la actualización y requiere un índice único adecuado que cubra las filas de la vista.

---

## C.2 — Medición del reporte original

La consulta original del ranking de clientes por gasto fue ejecutada mediante:

```sql
EXPLAIN (ANALYZE, BUFFERS)
```

Resultado:

* Planning Time: **5.101 ms**
* Execution Time: **207.512 ms**
* Se realizaron joins entre `cliente`, `pedido` y `detalle_pedido`.
* Se realizaron agregaciones mediante `HashAggregate`.
* Se utilizaron `Parallel Seq Scan` sobre `pedido` y `detalle_pedido`.
* Se utilizaron operaciones de ordenamiento para obtener el ranking.
* Se utilizó espacio temporal durante la ejecución.

---

## C.3 — Medición utilizando la vista materializada

El mismo reporte fue ejecutado utilizando `v_resumen_gasto_cliente`:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    id_cliente,
    nombre_completo,
    gasto_total,
    RANK() OVER (
        ORDER BY gasto_total DESC
    ) AS posicion_ranking
FROM v_resumen_gasto_cliente
ORDER BY gasto_total DESC, id_cliente ASC;
```

Resultado:

* Planning Time: **0.061 ms**
* Execution Time: **20.341 ms**
* Se leen las 20000 filas ya agregadas de la vista materializada.
* No es necesario repetir los joins ni calcular nuevamente el `SUM`.
* El costo principal restante corresponde al ordenamiento y cálculo del ranking.

### Comparación

| Consulta            | Execution Time |
| ------------------- | -------------: |
| Consulta original   |     207.512 ms |
| Vista materializada |      20.341 ms |

Diferencia absoluta:

**187.171 ms**

Reducción aproximada:

**90.2 %**

La mejora observada se debe a que el resultado costoso del agregado por cliente ya se encuentra almacenado en la vista materializada.

---

## C.4 — Frecuencia de refresco

Se propone ejecutar:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY v_resumen_gasto_cliente;
```

**cada una hora**.

La frecuencia se justifica porque se trata de un reporte analítico y no de una operación transaccional que requiera información en tiempo real.

El principal efecto de esta decisión es que los datos mostrados por la vista pueden tener una antigüedad de hasta aproximadamente una hora.

Si se necesitara información más actualizada, podrían realizarse refrescos con mayor frecuencia o consultarse directamente las tablas originales, asumiendo el mayor costo de procesamiento.

---

# Resumen de decisiones

| Elemento                        | Propuesta de IA                                           | Decisión      |
| ------------------------------- | --------------------------------------------------------- | ------------- |
| `idx_pedido_tarjeta_fecha`      | Índice parcial sobre `fecha_pedido DESC` para `TARJETA`   | **Aceptado**  |
| `idx_producto_activo_precio`    | Índice parcial sobre `precio DESC` para productos activos | **Aceptado**  |
| `idx_producto_activo_id`        | Índice parcial sobre `id_producto` para productos activos | **Rechazado** |
| `v_productos_vigentes`          | Vista de productos activos con categoría                  | **Aceptado**  |
| `v_pedidos_con_cliente`         | Vista de pedidos junto con datos del cliente              | **Aceptado**  |
| `v_detalle_pedido_con_producto` | Vista de detalles junto con nombre del producto           | **Aceptado**  |
| `v_resumen_gasto_cliente`       | Vista materializada del gasto acumulado por cliente       | **Aceptado**  |

## Conclusión

La Inteligencia Artificial fue utilizada como herramienta de asistencia para especificar, proponer y revisar soluciones SQL.

Las propuestas no fueron aplicadas automáticamente. Cada una fue revisada considerando el esquema existente, los planes de ejecución, los tiempos obtenidos, la selectividad de los filtros, la existencia de índices previos y los requisitos funcionales de cada consulta o reporte.

El caso de `idx_producto_activo_id` demuestra que una propuesta técnicamente válida en cuanto a sintaxis no necesariamente debe aceptarse: fue evaluada experimentalmente y descartada debido a la existencia de un índice sobre la clave primaria, la baja selectividad del filtro y la ausencia de un cambio favorable en el plan.

En las vistas se verificó la equivalencia de resultados mediante comparación bidireccional con `EXCEPT`.

En la vista materializada se comparó el costo del reporte original con el costo de consultar el resultado previamente agregado, obteniéndose una reducción aproximada del 90.2 % en la medición realizada.

La decisión técnica final en todos los casos correspondió al estudiante.
