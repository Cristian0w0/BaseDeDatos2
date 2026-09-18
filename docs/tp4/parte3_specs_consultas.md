# Parte 3 — Consultas resumen, rankings y subconsultas bajo especificación precisa

## Consideraciones sobre el esquema

El esquema Food Store utilizado en esta práctica no posee columnas de borrado lógico (`deleted`, `eliminado`, `deleted_at`, etc.) en las tablas involucradas.

Por lo tanto, para estas consultas se considera que todas las filas existentes son vigentes y **no se aplica ningún filtro de borrado lógico**.

Las consultas se ejecutan sobre la base `bd2_tp4`.

---

## Consulta A — Ranking de clientes por gasto

### Especificación

Generar una consulta SQL sobre el esquema Food Store que devuelva, para cada cliente que tenga al menos un pedido:

* `id_cliente`
* nombre completo, formado a partir de `nombre` y `apellido`
* gasto total del cliente
* posición en un ranking de clientes según su gasto total

### Reglas

1. Deben incluirse únicamente clientes que tengan al menos un pedido.
2. No se aplica filtro de borrado lógico porque el esquema no posee columnas de borrado lógico en las tablas involucradas.
3. El gasto total debe calcularse como:

   `SUM(detalle_pedido.cantidad * detalle_pedido.precio_unitario)`

   considerando todos los detalles correspondientes a los pedidos del cliente.
4. El ranking debe utilizar una **función de ventana**.
5. El criterio del ranking debe ser el gasto total, de mayor a menor.
6. Los clientes con el mismo gasto total deben compartir la misma posición del ranking.
7. El ranking es **global**: no existe ninguna partición por categoría, forma de pago, período u otro atributo.
8. El criterio utilizado por la función de ventana para determinar la posición debe ser únicamente el gasto total descendente. No debe utilizarse `id_cliente` como segundo criterio dentro de `RANK()`, porque eso impediría que los empates compartan posición.
9. Para que el orden final de las filas sea determinista, se puede ordenar el resultado por gasto total descendente y, en caso de empate, por `id_cliente` ascendente.
10. Debe devolverse una sola fila por cliente.
11. No utilizar `SELECT *`.
12. La IA deberá generar una primera versión del SQL a partir de esta especificación.
13. Luego deberá generar una segunda versión que responda exactamente a la misma especificación, pero utilizando una estructura SQL diferente.
14. Ambas versiones deberán producir exactamente el mismo conjunto de filas y valores.
15. La equivalencia se verificará ejecutando ambas diferencias:

```sql
(consulta_ranking_v1)
EXCEPT
(consulta_ranking_v2);

(consulta_ranking_v2)
EXCEPT
(consulta_ranking_v1);
```

Ambas consultas de verificación deben devolver cero filas.

---

## Consulta B — Gasto por cliente mediante subconsulta correlacionada

### Especificación

Generar una consulta SQL sobre el esquema Food Store que devuelva, para cada cliente que tenga al menos un pedido:

* `id_cliente`
* nombre completo, formado a partir de `nombre` y `apellido`
* cantidad de pedidos
* gasto total

### Reglas

1. Deben incluirse únicamente clientes que tengan al menos un pedido.
2. No se aplica filtro de borrado lógico porque el esquema no posee columnas de borrado lógico en las tablas involucradas.
3. La cantidad de pedidos debe representar la cantidad de **pedidos distintos** asociados al cliente.
4. El gasto total debe calcularse como:

   `SUM(detalle_pedido.cantidad * detalle_pedido.precio_unitario)`

   considerando todos los detalles correspondientes a los pedidos del cliente.
5. La primera versión debe utilizar una **subconsulta correlacionada**, relacionada con la fila del cliente que se está procesando, para calcular el gasto total.
6. La consulta debe devolver una sola fila por cliente.
7. No utilizar `SELECT *`.
8. La primera versión debe respetar la especificación sin depender de que cada pedido tenga una única fila en `detalle_pedido`.
9. Luego deberá generarse una segunda versión que responda exactamente a la misma especificación utilizando `JOIN` y agregación (`GROUP BY`), sin utilizar una subconsulta correlacionada para calcular el gasto.
10. Ambas versiones deben devolver exactamente las mismas columnas, filas y valores.
11. La equivalencia se verificará ejecutando ambas diferencias:

```sql
(consulta_subconsulta_v1)
EXCEPT
(consulta_join_v2);

(consulta_join_v2)
EXCEPT
(consulta_subconsulta_v1);
```

Ambas consultas de verificación deben devolver cero filas.

---

## Criterio de verificación

La equivalencia no se considerará demostrada únicamente porque ambas consultas produzcan resultados visualmente similares.

Se verificará mediante:

1. `EXCEPT` en ambas direcciones.
2. Comparación de cantidad de filas.
3. Revisión de una muestra de resultados.

La ausencia de filas en ambos `EXCEPT` será la evidencia principal de equivalencia entre las dos versiones de cada consulta.
