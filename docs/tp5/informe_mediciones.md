# Informe de mediciones — TP5

## 1. Objetivo

El objetivo de esta etapa es evaluar propuestas de índices sobre consultas representativas del sistema Food Store, verificando su comportamiento mediante `EXPLAIN (ANALYZE, BUFFERS)` antes y después de su creación.

También se evalúa el costo de las estructuras agregadas sobre una operación de escritura y se documenta al menos una propuesta de índice generada por IA que fue rechazada por no aportar un beneficio suficiente.

Las mediciones se realizaron sobre la base de datos `bd2_tp5`, generada a partir de una copia de `bd2_tp4`.

---

## 2. Índice para consultas de pedidos con forma de pago TARJETA

### Consulta evaluada

```sql
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

### Situación inicial

Antes de agregar el índice, la consulta utilizaba un `Seq Scan` sobre `pedido`, recorriendo las 200000 filas de la tabla y posteriormente realizando un `Sort`.

* Filas devueltas: 46863
* Filas descartadas por el filtro: 153137
* Buffers: 1472
* Execution Time: **18.877 ms**

### Propuesta

Se evaluó un índice parcial sobre `fecha_pedido`, limitado a las filas cuya forma de pago es `TARJETA`:

```sql
CREATE INDEX idx_pedido_tarjeta_fecha
    ON pedido (fecha_pedido DESC)
    WHERE forma_pago = 'TARJETA';
```

La condición parcial reduce el conjunto de entradas del índice y lo orienta específicamente al patrón de consulta analizado.

### Situación posterior

Después de crear el índice, el plan pasó a utilizar:

* `Bitmap Index Scan`
* `Bitmap Heap Scan`

La consulta completa continuó necesitando un `Sort`, porque devuelve una cantidad importante de filas.

* Filas devueltas: 46863
* Buffers: 1470 hit + 130 read
* Execution Time: **17.588 ms**

La diferencia fue de:

**18.877 ms → 17.588 ms**

Es decir, una reducción aproximada del **6,8 %** en esta ejecución.

### Consulta complementaria con LIMIT

Para evaluar el caso frecuente de obtener solamente los pedidos más recientes, se utilizó:

```sql
SELECT
    p.id_pedido,
    p.cliente_id,
    p.fecha_pedido,
    p.forma_pago
FROM pedido p
WHERE p.fecha_pedido >= TIMESTAMPTZ '2026-01-01'
  AND p.forma_pago = 'TARJETA'
ORDER BY p.fecha_pedido DESC
LIMIT 100;
```

En este caso el índice permitió realizar directamente un `Index Scan` en el orden requerido, eliminando el `Sort`.

* Execution Time: **0.129 ms**
* Buffers: 102
* Filas obtenidas: 100

Este resultado muestra especialmente el beneficio del índice para consultas de tipo top-N. No se compara directamente el valor de 0.129 ms con los 18.877 ms de la consulta completa, porque las consultas no tienen el mismo `LIMIT`.

---

## 3. Índice para productos activos ordenados por precio

### Consulta evaluada

```sql
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

### Situación inicial

Antes de crear el índice, PostgreSQL utilizaba un `Seq Scan` sobre `producto` y luego un `Sort` de tipo top-N.

* Filas de `producto`: 50000
* Productos activos: 46667
* Productos descartados: 3333
* Execution Time: **10.446 ms**

### Propuesta

Se aceptó un índice parcial sobre el precio de los productos activos:

```sql
CREATE INDEX idx_producto_activo_precio
    ON producto (precio DESC)
    WHERE activo = TRUE;
```

El índice permite excluir los productos inactivos y, al mismo tiempo, entregar las filas en el orden solicitado.

### Situación posterior

Después de crear el índice, el plan pasó a utilizar directamente un `Index Scan`, sin necesidad de realizar un `Sort`.

* Filas obtenidas: 100
* Buffers: 100 hit + 2 read
* Execution Time: **0.150 ms**

La diferencia fue:

**10.446 ms → 0.150 ms**

Esto representa una reducción aproximada del **98,6 %** del tiempo de ejecución en esta medición.

El cambio de plan es significativo: se pasó de recorrer toda la tabla y ordenar resultados a utilizar directamente un índice que ya contiene únicamente las filas relevantes y en el orden requerido.

---

## 4. Propuesta de índice rechazada

### Consulta evaluada

Se analizó la siguiente consulta:

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

### Situación inicial

El plan utilizó un `Hash Join`, acompañado de `Seq Scan` sobre ambas tablas.

* `detalle_pedido`: 200000 filas
* `producto`: 50000 filas, de las cuales 46667 son activas
* Filas resultantes: 186668
* Execution Time: **62.514 ms**

### Propuesta generada

Se propuso experimentalmente:

```sql
CREATE INDEX idx_producto_activo_id
    ON producto (id_producto)
    WHERE activo = TRUE;
```

### Motivos del rechazo

La propuesta fue rechazada por las siguientes razones:

1. La condición `activo = TRUE` tiene baja selectividad: aproximadamente el **93,3 %** de los productos son activos.
2. `id_producto` ya dispone de un índice mediante la clave primaria de `producto`.
3. La tabla `detalle_pedido` ya posee un índice sobre `producto_id`.
4. La consulta devuelve una cantidad muy grande de filas, por lo que un `Hash Join` con recorridos secuenciales resulta adecuado para este volumen de datos.
5. La prueba experimental del índice no produjo un cambio en el plan de ejecución: PostgreSQL continuó utilizando `Hash Join` y `Seq Scan`.

El índice experimental fue eliminado y no forma parte de los índices aceptados del TP5.

---

## 5. Evaluación del costo de los índices sobre escrituras

Para evaluar el impacto de los índices agregados sobre una operación de escritura se utilizó una carga controlada de **500 filas** sobre `detalle_pedido`.

La operación fue ejecutada dentro de una transacción y finalizada con `ROLLBACK`, por lo que las mediciones no modificaron permanentemente los datos.

La consulta utilizada fue la misma en ambas mediciones:

```sql
INSERT INTO detalle_pedido (
    pedido_id,
    producto_id,
    cantidad,
    precio_unitario
)
SELECT
    p.id_pedido,
    pr.id_producto,
    1,
    pr.precio
FROM pedido p
CROSS JOIN producto pr
WHERE NOT EXISTS (
    SELECT 1
    FROM detalle_pedido dp
    WHERE dp.pedido_id = p.id_pedido
      AND dp.producto_id = pr.id_producto
)
LIMIT 500;
```

### Medición antes de los índices nuevos

Los índices `idx_pedido_tarjeta_fecha` y `idx_producto_activo_precio` fueron eliminados temporalmente dentro de una transacción.

Resultado:

* Filas insertadas: 500
* Execution Time: **58.269 ms**
* Planning Time: **1.853 ms**

El plan utilizó un `Hash Anti Join` para comprobar la existencia previa de las combinaciones de pedido y producto.

### Medición después de los índices nuevos

Con los dos índices aceptados nuevamente presentes se ejecutó exactamente la misma carga.

Resultado:

* Filas insertadas: 500
* Execution Time: **54.031 ms**
* Planning Time: **2.406 ms**

La diferencia entre las dos ejecuciones fue:

**58.269 ms → 54.031 ms**

Una reducción aproximada del **7,3 %** en esta medición.

Sin embargo, esta diferencia no se interpreta como una mejora causada por los índices. Los dos índices evaluados pertenecen a las tablas `pedido` y `producto`, mientras que la operación de escritura se realiza sobre `detalle_pedido`. Por lo tanto, esos índices no necesitan ser actualizados cuando se insertan filas en `detalle_pedido`.

Además, el plan de ejecución se mantuvo esencialmente igual en ambas pruebas. La diferencia temporal observada se considera compatible con la variabilidad normal de una ejecución aislada.

Por lo tanto, la conclusión es que **no se observó un costo directo apreciable sobre esta operación de escritura debido a los dos índices nuevos**.

---

## 6. Índices aceptados

Los índices que forman parte de la solución final de esta etapa son:

```sql
CREATE INDEX idx_pedido_tarjeta_fecha
    ON pedido (fecha_pedido DESC)
    WHERE forma_pago = 'TARJETA';

CREATE INDEX idx_producto_activo_precio
    ON producto (precio DESC)
    WHERE activo = TRUE;
```

Ambos índices fueron creados y validados mediante `EXPLAIN (ANALYZE, BUFFERS)`.

---

## 7. Conclusiones

El análisis permitió seleccionar dos índices orientados a patrones concretos de consulta en lugar de agregar índices de manera general.

El índice parcial sobre `pedido` mejoró el acceso a consultas que filtran por `forma_pago = 'TARJETA'` y fecha, y resulta especialmente útil cuando la consulta solicita una cantidad limitada de pedidos recientes.

El índice parcial sobre `producto` produjo un cambio más significativo en la consulta de productos activos ordenados por precio, eliminando el recorrido secuencial y la operación de ordenamiento.

También se rechazó una propuesta de índice sobre `producto(id_producto) WHERE activo = TRUE` debido a su baja selectividad, la existencia previa de un índice por la clave primaria y la ausencia de cambios favorables en el plan de ejecución.

Finalmente, la medición de escritura sobre `detalle_pedido` mostró que los índices agregados no introducen un costo directo relevante en dicha operación, dado que se encuentran sobre otras tablas. Las pequeñas diferencias temporales observadas entre ejecuciones no se consideran suficientes para atribuir una mejora o empeoramiento al uso de estos índices.

---

# 8. Parte B — Vistas para los reportes del sistema

Se definieron tres vistas para simplificar consultas habituales del sistema Food Store. Las vistas fueron generadas a partir de una especificación previa realizada en Kiro y luego implementadas con OpenCode.

## 8.1. Vista de productos vigentes

**Vista:** `v_productos_vigentes`

La vista combina `producto` con `categoria` mediante un `INNER JOIN` y filtra únicamente los productos con `activo = TRUE`.

Se comparó el resultado de la vista con la consulta manual equivalente.

* Filas devueltas por la vista: **46667**
* Filas devueltas por la consulta manual: **46667**
* `EXCEPT` vista → consulta manual: **0 diferencias**
* `EXCEPT` consulta manual → vista: **0 diferencias**

Por lo tanto, ambas consultas son equivalentes.

## 8.2. Vista de pedidos con datos del cliente

**Vista:** `v_pedidos_con_cliente`

La vista combina `pedido` con `cliente` mediante un `INNER JOIN` y expone los datos necesarios del pedido junto con nombre, apellido y email del cliente.

Se comparó el resultado de la vista con la consulta manual equivalente.

* Filas devueltas por la vista: **200000**
* Filas devueltas por la consulta manual: **200000**
* `EXCEPT` vista → consulta manual: **0 diferencias**
* `EXCEPT` consulta manual → vista: **0 diferencias**

Por lo tanto, ambas consultas son equivalentes.

### Consideración de seguridad

La vista no expone `id_cliente` ni `created_at`, ya que no son necesarios para este reporte.

El esquema actual de `cliente` fue revisado y no contiene una columna `contraseña`, token ni otro campo de autenticación. Por lo tanto, no existe actualmente una columna de contraseña que pueda ser excluida mediante esta vista. No se modificó el esquema para agregar una credencial inexistente.

La vista expone únicamente los datos del cliente necesarios para el reporte: `nombre`, `apellido` y `email`.

## 8.3. Vista de detalle de pedido con nombre del producto

**Vista:** `v_detalle_pedido_con_producto`

La vista combina `detalle_pedido` con `producto` mediante un `INNER JOIN` y agrega el nombre del producto al detalle de cada pedido.

No se filtra por `producto.activo`, ya que un producto puede haber sido dado de baja posteriormente y el detalle histórico de una venta debe conservarse.

Se comparó el resultado de la vista con la consulta manual equivalente.

* Filas devueltas por la vista: **200000**
* Filas devueltas por la consulta manual: **200000**
* `EXCEPT` vista → consulta manual: **0 diferencias**
* `EXCEPT` consulta manual → vista: **0 diferencias**

Por lo tanto, ambas consultas son equivalentes.

## 8.4. Resultado de la verificación

Las tres vistas fueron verificadas comparando sus resultados con consultas SQL equivalentes escritas manualmente.

En todos los casos se obtuvo la misma cantidad de filas y cero diferencias mediante `EXCEPT` en ambos sentidos.

| Vista                           |  Filas | Diferencias en ambos sentidos |
| ------------------------------- | -----: | ----------------------------: |
| `v_productos_vigentes`          |  46667 |                             0 |
| `v_pedidos_con_cliente`         | 200000 |                             0 |
| `v_detalle_pedido_con_producto` | 200000 |                             0 |

Las tres vistas se consideran validadas para los reportes especificados.

---

## 9. Parte C — Vista materializada

Se creó la vista materializada `v_resumen_gasto_cliente`, que almacena el gasto total acumulado por cliente a partir de las tablas `cliente`, `pedido` y `detalle_pedido`.

La vista fue creada utilizando `WITH DATA`, por lo que quedó cargada inmediatamente con los datos actuales. Contiene 20000 filas.

Se creó además el índice único:

`idx_v_resumen_gasto_cliente_cliente` sobre `id_cliente`.

El índice único es necesario para permitir el uso de `REFRESH MATERIALIZED VIEW CONCURRENTLY`. Esta operación fue probada correctamente sobre `v_resumen_gasto_cliente`.

### Medición del reporte original

La consulta original del ranking de clientes por gasto fue ejecutada mediante `EXPLAIN (ANALYZE, BUFFERS)`.

- Execution Time: **207.512 ms**.
- El plan realiza joins entre `cliente`, `pedido` y `detalle_pedido`.
- Se realizan agregaciones por cliente mediante `HashAggregate`.
- Se utilizan `Parallel Seq Scan` sobre `pedido` y `detalle_pedido`.
- Luego se realizan los ordenamientos necesarios para calcular `RANK()` y presentar el resultado.
- El `HashAggregate` utilizó espacio temporal en disco.

### Medición utilizando la vista materializada

El mismo reporte fue ejecutado utilizando `v_resumen_gasto_cliente` como fuente:

- Execution Time: **20.341 ms**.
- La consulta lee las 20000 filas ya agregadas de la vista.
- Luego realiza el ordenamiento y calcula `RANK()`.
- No necesita repetir los joins ni el cálculo de `SUM(cantidad * precio_unitario)` sobre las tablas originales.

### Comparación

La consulta original tardó **207.512 ms**, mientras que la consulta sobre la vista materializada tardó **20.341 ms**.

La diferencia absoluta fue de **187.171 ms**, lo que representa una reducción aproximada del **90.2%** en el tiempo de ejecución en esta medición.

La mejora se debe a que la vista materializada almacena previamente el resultado costoso del agregado por cliente.

### Frecuencia de refresco

Se propone ejecutar `REFRESH MATERIALIZED VIEW CONCURRENTLY v_resumen_gasto_cliente` **cada una hora**.

La frecuencia se justifica porque se trata de un reporte analítico y no de una operación transaccional que requiera información en tiempo real. Con esta frecuencia, los usuarios podrían consultar información con una antigüedad de hasta aproximadamente una hora.

El costo de esta decisión es que los cambios realizados en pedidos posteriores al último refresh no aparecerán inmediatamente en el reporte materializado. Si se necesitara información más actualizada, podría aumentarse la frecuencia del refresh o consultarse directamente la información de las tablas originales, asumiendo el mayor costo de procesamiento.

El uso de `REFRESH MATERIALIZED VIEW CONCURRENTLY` permite actualizar la vista manteniendo disponible su contenido para las consultas durante el proceso de actualización, y es posible gracias al índice único sobre `id_cliente`.
