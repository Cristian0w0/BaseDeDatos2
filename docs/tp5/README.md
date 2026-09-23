# Base de Datos 2 — Food Store

Repositorio de trabajos prácticos de la materia **Base de Datos 2**.

Este README documenta específicamente la reproducción de las pruebas realizadas en el **TP5 — Índices y Vistas**, trabajando sobre PostgreSQL.

---

## TP5 — Índices, vistas y vista materializada

El objetivo del TP5 es analizar el comportamiento de índices sobre consultas frecuentes, evaluar propuestas de indexación, construir vistas para reportes habituales y utilizar una vista materializada para acelerar un reporte agregado costoso.

Las pruebas se realizaron sobre una copia de la base utilizada en TP4:

```text
bd2_tp5
```

La base original de TP4 (`bd2_tp4`) no fue modificada.

Antes de comenzar el TP5 se realizó un respaldo:

```text
db/backups/bd2_tp4_antes_tp5.dump
```

---

## Estructura relevante

```text
food-store/
├── db/
│   ├── schema.sql
│   ├── consultas_tp4_parte3.sql
│   ├── generador_datos_tp3.sql
│   ├── generador_datos_tp3_carga.sql
│   ├── indices.sql
│   ├── views.sql
│   └── backups/
├── docs/
│   └── tp5/
│       ├── duia.md
│       └── informe_mediciones.md
├── specs/
│   ├── indice_pedido_tarjeta_fecha.md
│   ├── indice_producto_activo_id_rechazado.md
│   ├── indice_producto_activo_precio.md
│   ├── vista_detalle_pedido_con_producto.md
│   ├── vista_materializada_gasto_cliente.md
│   ├── vista_pedidos_con_cliente.md
│   └── vista_productos_vigentes.md
└── README.md
```

---

## Requisitos

* PostgreSQL.
* DBeaver u otro cliente SQL.
* Git.
* Una base de datos `bd2_tp5` preparada a partir de la base utilizada en TP4.

Las consultas de medición utilizan sintaxis específica de PostgreSQL, principalmente:

```sql
EXPLAIN (ANALYZE, BUFFERS)
```

---

# Reproducción del TP5

## 1. Preparar la base de datos

Las pruebas se realizaron sobre:

```text
bd2_tp5
```

La base contiene aproximadamente:

* `pedido`: 200000 filas.
* `detalle_pedido`: 200000 filas.
* `producto`: 50000 filas.
* `cliente`: 20000 filas.
* `categoria`: 1 fila.

La preparación de los datos se realizó utilizando los scripts y respaldos correspondientes a los trabajos anteriores.

No se modificó la base original `bd2_tp4`.

---

# Parte A — Índices

Los índices aceptados se encuentran en:

```text
db/indices.sql
```

Los índices finalmente aceptados fueron:

```sql
CREATE INDEX idx_pedido_tarjeta_fecha
    ON pedido (fecha_pedido DESC)
    WHERE forma_pago = 'TARJETA';

CREATE INDEX idx_producto_activo_precio
    ON producto (precio DESC)
    WHERE activo = TRUE;
```

Antes de ejecutar `db/indices.sql`, las consultas de medición pueden utilizarse para obtener el plan y tiempo de ejecución sin los nuevos índices.

Después de crear los índices, se vuelven a ejecutar las mismas consultas para comparar los planes.

---

## 2. Medición del índice sobre `pedido`

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

Sin el nuevo índice se obtuvo un `Seq Scan` sobre `pedido` y posteriormente un `Sort`.

Con:

```sql
idx_pedido_tarjeta_fecha
```

el plan pasó a utilizar un `Bitmap Index Scan` y un `Bitmap Heap Scan`.

Para comprobar específicamente el beneficio del índice en una consulta Top-N se puede ejecutar:

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
ORDER BY p.fecha_pedido DESC
LIMIT 100;
```

En este caso el índice permite realizar un `Index Scan` y evitar el `Sort`.

---

## 3. Medición del índice sobre `producto`

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

Sin el índice se obtuvo un `Seq Scan` seguido de un `top-N heapsort`.

Con:

```sql
idx_producto_activo_precio
```

el plan pasó a utilizar un `Index Scan`, eliminando el `Sort`.

En la medición realizada, el tiempo pasó aproximadamente de:

```text
10.446 ms
```

a:

```text
0.150 ms
```

La reducción observada fue aproximadamente del:

```text
98.6 %
```

---

## 4. Propuesta de índice rechazada

También se evaluó la siguiente propuesta:

```sql
CREATE INDEX idx_producto_activo_id
    ON producto (id_producto)
    WHERE activo = TRUE;
```

La propuesta fue descartada después de realizar una prueba experimental.

Las principales razones fueron:

* `id_producto` ya es clave primaria y posee un índice.
* El filtro `activo = TRUE` tiene baja selectividad: aproximadamente el 93.3 % de los productos están activos.
* La consulta genera un conjunto grande de resultados.
* El plan continuó utilizando `Hash Join` y recorridos secuenciales.
* No se observó una mejora suficiente que justificara mantener otro índice.

El índice experimental fue eliminado y no forma parte de `db/indices.sql`.

La especificación y la justificación del rechazo se encuentran en:

```text
specs/indice_producto_activo_id_rechazado.md
```

---

## 5. Medición de escritura

También se comparó una operación de inserción de varios cientos de filas en `detalle_pedido`, utilizando una transacción con `ROLLBACK` para evitar modificar permanentemente los datos.

El objetivo fue observar si los índices aceptados introducían un costo apreciable en una operación de escritura.

El plan utilizado y las mediciones completas se encuentran en:

```text
docs/tp5/informe_mediciones.md
```

La comparación mostró planes equivalentes y no se observó un costo directo apreciable atribuible a los índices aceptados en esta operación.

---

# Parte B — Vistas

Las vistas se encuentran en:

```text
db/views.sql
```

Se crearon tres vistas:

```text
v_productos_vigentes
v_pedidos_con_cliente
v_detalle_pedido_con_producto
```

## 6. Vista de productos vigentes

La vista:

```text
v_productos_vigentes
```

expone los productos activos junto con el nombre de su categoría.

Para verificarla:

```sql
SELECT COUNT(*)
FROM v_productos_vigentes;
```

También se puede comparar con la consulta original mediante `EXCEPT` en ambas direcciones.

El resultado de la verificación realizada fue:

```text
46667 filas
0 diferencias en ambas direcciones
```

---

## 7. Vista de pedidos con cliente

La vista:

```text
v_pedidos_con_cliente
```

combina los pedidos con los datos necesarios del cliente:

* id del pedido.
* cliente.
* fecha.
* forma de pago.
* nombre.
* apellido.
* email.

Para verificarla:

```sql
SELECT COUNT(*)
FROM v_pedidos_con_cliente;
```

Resultado de la verificación:

```text
200000 filas
0 diferencias en ambas direcciones
```

El esquema actual de `cliente` no almacena contraseñas ni tokens de autenticación. Por ese motivo, la vista no puede demostrar una exclusión de contraseña que no existe en la tabla base. La vista aplica igualmente el principio de exponer únicamente las columnas necesarias para el reporte.

---

## 8. Vista de detalle de pedido con producto

La vista:

```text
v_detalle_pedido_con_producto
```

combina las líneas de pedido con el nombre del producto.

Para verificarla:

```sql
SELECT COUNT(*)
FROM v_detalle_pedido_con_producto;
```

Resultado:

```text
200000 filas
0 diferencias en ambas direcciones
```

No se filtran productos inactivos para conservar la información histórica de las ventas.

---

# Parte C — Vista materializada

La vista materializada se encuentra también en:

```text
db/views.sql
```

Se creó:

```text
v_resumen_gasto_cliente
```

Esta vista almacena previamente el gasto total acumulado de cada cliente.

La definición utiliza:

```sql
WITH DATA
```

por lo que queda cargada inmediatamente al momento de su creación.

La vista contiene:

```text
20000 filas
```

También se creó el índice único:

```text
idx_v_resumen_gasto_cliente_cliente
```

sobre:

```text
id_cliente
```

Este índice permite utilizar:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY
```

---

## 9. Reproducir la medición del reporte original

El reporte seleccionado corresponde al ranking de clientes por gasto total utilizado en TP4.

Para medirlo:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    c.id_cliente,
    c.nombre || ' ' || c.apellido AS nombre_completo,
    SUM(dp.cantidad * dp.precio_unitario) AS gasto_total,
    RANK() OVER (
        ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC
    ) AS posicion_ranking
FROM cliente c
JOIN pedido p
    ON c.id_cliente = p.cliente_id
JOIN detalle_pedido dp
    ON p.id_pedido = dp.pedido_id
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY gasto_total DESC, c.id_cliente ASC;
```

En la medición realizada:

```text
Execution Time: 207.512 ms
```

---

## 10. Reproducir la medición utilizando la vista materializada

Ejecutar:

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

En la medición realizada:

```text
Execution Time: 20.341 ms
```

La reducción observada fue aproximadamente del:

```text
90.2 %
```

La diferencia absoluta fue de aproximadamente:

```text
187.171 ms
```

La mejora se debe a que la vista materializada ya contiene el resultado agregado por cliente y la consulta no necesita repetir los `JOIN` ni calcular nuevamente el `SUM`.

---

## 11. Refrescar la vista materializada

Para actualizar la información almacenada:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY v_resumen_gasto_cliente;
```

Esta operación fue probada correctamente.

El uso de `CONCURRENTLY` permite que el contenido de la vista continúe disponible para consultas durante el proceso de actualización y requiere un índice único apropiado.

El refresh propuesto para este reporte es de aproximadamente:

```text
una vez por hora
```

Por tratarse de un reporte analítico, se acepta que los datos puedan tener una antigüedad de hasta aproximadamente una hora.

Si se necesitara información en tiempo real, sería necesario aumentar la frecuencia de actualización o consultar directamente las tablas originales.

---

# Documentación y resultados

Las mediciones completas de `EXPLAIN (ANALYZE, BUFFERS)`, la comparación de planes y las pruebas de lectura y escritura se encuentran en:

```text
docs/tp5/informe_mediciones.md
```

Las especificaciones utilizadas para índices, vistas y vista materializada se encuentran en:

```text
specs/
```

La bitácora de uso de Kiro y OpenCode, incluyendo propuestas aceptadas y rechazadas y las decisiones técnicas tomadas, se encuentra en:

```text
docs/tp5/duia.md
```

---

# Flujo de trabajo con IA

El TP5 siguió el flujo establecido por la consigna:

1. Se especificó cada necesidad mediante un spec preciso.
2. Se utilizaron las especificaciones para generar las implementaciones SQL.
3. Las propuestas fueron revisadas antes de ejecutarse.
4. Las consultas y cambios se probaron sobre `bd2_tp5`.
5. Se analizaron los planes mediante `EXPLAIN (ANALYZE, BUFFERS)`.
6. Las propuestas fueron aceptadas, modificadas o rechazadas según los resultados obtenidos.
7. Los cambios fueron registrados mediante commits Git.

La decisión final sobre los cambios realizados no fue delegada a la IA.

---

# Historial Git

El historial de commits forma parte de la entrega y documenta la evolución del TP5.

Para consultar los commits:

```powershell
git log --oneline --decorate
```

Para consultar los cambios de un commit:

```powershell
git show <commit>
```

El repositorio mantiene los cambios del TP5 versionados en Git para permitir revisar tanto el estado final como el proceso de desarrollo.
