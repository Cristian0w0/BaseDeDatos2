# Especificación de Propuesta Rechazada — idx_producto_activo_id

## 1. Identificación de la propuesta

- **Nombre del índice propuesto:** `idx_producto_activo_id`
- **Tabla:** `producto`
- **Columnas:** `id_producto`
- **Tipo de índice:** B-Tree (parcial)
- **Predicado / Condición:** `WHERE activo = TRUE`
- **Origen de la propuesta:** Sugerencia generada por IA para optimizar la consulta de líneas de pedido con productos activos.

---

## 2. Consulta / workload

Consulta que relaciona la tabla de hechos `detalle_pedido` con la tabla dimensional `producto`, filtrando únicamente aquellos productos que se encuentran activos:

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

---

## 3. DDL propuesto

```sql
CREATE INDEX idx_producto_activo_id
    ON producto (id_producto)
    WHERE activo = TRUE;
```

---

## 4. Por qué podría parecer razonable inicialmente

A primera vista, la propuesta puede parecer atractiva por los siguientes motivos:
- La consulta incluye explícitamente el filtro `WHERE pr.activo = TRUE` y realiza una operación de join mediante `pr.id_producto = dp.producto_id`.
- Se podría suponer intuitivamente que un índice parcial sobre la clave de unión (`id_producto`) limitado a las filas que cumplen el predicado (`activo = TRUE`) permitiría a PostgreSQL descartar productos inactivos antes o durante el join, reduciendo el volumen de datos a procesar.

---

## 5. Criterios de aceptación

Para aceptar el índice propuesto como parte del esquema definitivo, se requerían las siguientes condiciones verificables mediante `EXPLAIN (ANALYZE, BUFFERS)`:
1. Modificación favorable del plan de ejecución (por ejemplo, reemplazo ventajoso de escaneos secuenciales o reducción significativa de operaciones de join).
2. Disminución apreciable y consistente del tiempo de ejecución global de la consulta.
3. Reducción sustancial en la cantidad de buffers leídos (acceso a disco o memoria).
4. Beneficio de rendimiento suficiente que justifique el costo adicional de almacenamiento y sobrecarga en operaciones de escritura (`INSERT`, `UPDATE`, `DELETE`).

---

## 6. Resultado de la prueba

Las mediciones se realizaron en la base de datos `bd2_tp5` con el siguiente resultado:

- **Volumen de datos:**
  - Total de filas en `producto`: 50000
  - Productos activos (`activo = TRUE`): 46667 (93,3%)
  - Productos inactivos (`activo = FALSE`): 3333 (6,7%)
  - Total de filas en `detalle_pedido`: 200000
  - Filas devueltas por la consulta: 186668
- **Medición sin el índice:**
  - Plan de ejecución: `Hash Join` con `Seq Scan` sobre `detalle_pedido` y `Seq Scan` sobre `producto`.
  - Execution Time: **62.514 ms**.
- **Medición con el índice creado:**
  - Plan de ejecución: `Hash Join` con `Seq Scan` sobre `detalle_pedido` y `Seq Scan` sobre `producto`.
  - Execution Time: **60.987 ms**.

La pequeña diferencia entre 62.514 ms y 60.987 ms **NO se atribuye al índice**, sino a la variabilidad normal inherente a mediciones consecutivas aisladas en el motor de base de datos. El plan de ejecución fue exactamente el mismo: PostgreSQL no utilizó el nuevo índice en ningún nodo del plan (mismo `Hash Join` y mismos `Seq Scan`).

---

## 7. Razones técnicas para el rechazo

1. **Baja selectividad del predicado:** La condición `WHERE activo = TRUE` tiene una selectividad muy baja, ya que abarca al 93,3% de los registros de la tabla (46667 de 50000 productos). Los índices parciales resultan ventajosos cuando el predicado aísla una fracción reducida y altamente selectiva de los datos.
2. **Redundancia con la Primary Key:** La columna `id_producto` ya se encuentra indexada como clave primaria (`PRIMARY KEY`) de la tabla `producto` mediante un índice B-Tree único existente.
3. **Índice existente en la clave foránea:** La tabla `detalle_pedido` ya dispone de un índice sobre `producto_id` (`idx_detalle_pedido_producto`).
4. **Magnitud del conjunto resultante:** La consulta recupera 186668 filas de un total de 200000. Ante semejante volumen de datos, el optimizador de PostgreSQL determina correctamente que un recorrido secuencial (`Seq Scan`) y un `Hash Join` son más eficientes que incurrir en el costo de saltos aleatorios de acceso indexado.
5. **Inexistencia de cambio en el plan de ejecución:** Al no ser utilizado por el optimizador, el índice no aporta ninguna mejora al patrón de consulta evaluado.

---

## 8. Decisión final

**Propuesta RECHAZADA.**
El índice no aporta beneficio en el plan de ejecución ni en los tiempos de respuesta. Incorporarlo implicaría un consumo innecesario de almacenamiento y un costo injustificado de mantenimiento en las operaciones de escritura (`INSERT`, `UPDATE`, `DELETE`) sobre la tabla `producto`.

---

## 9. Estado del índice experimental

El índice experimental `idx_producto_activo_id` **fue eliminado** de la base de datos tras las pruebas y no forma parte del archivo `db/indices.sql` ni del esquema definitivo.
