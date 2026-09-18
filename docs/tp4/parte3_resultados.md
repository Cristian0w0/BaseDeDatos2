# Parte 3 — Resultados de verificación

## 1. Objetivo

Se verificó la equivalencia de dos pares de consultas generadas a partir de especificaciones precisas:

* **Consulta A:** ranking de clientes por gasto total utilizando una función de ventana.
* **Consulta B:** gasto total y cantidad de pedidos por cliente utilizando una subconsulta correlacionada y una versión alternativa con `JOIN + GROUP BY`.

Las consultas se ejecutaron sobre la base de trabajo `bd2_tp4`.

La verificación de equivalencia se realizó utilizando `EXCEPT` en ambas direcciones.

---

## 2. Consulta A — Ranking por gasto

### A1 — Versión con agregación y función de ventana

La primera versión utiliza `JOIN`, `GROUP BY` y `RANK()` para obtener el gasto total de cada cliente y su posición en el ranking.

**Resultado:** 20.000 filas.

### A2 — Versión con CTE

La segunda versión calcula primero el gasto por cliente mediante una CTE (`gasto_por_cliente`) y posteriormente aplica la función de ventana `RANK()`.

**Resultado:** 20.000 filas.

### Verificación de equivalencia

Se ejecutaron las dos diferencias de conjuntos:

* `A1 EXCEPT A2` → **0 filas**
* `A2 EXCEPT A1` → **0 filas**

Por lo tanto, las dos consultas producen el mismo conjunto de resultados sobre la base `bd2_tp4`.

La comprobación se realizó sobre las columnas:

* `id_cliente`
* `nombre_completo`
* `gasto_total`
* `posicion_ranking`

---

## 3. Consulta B — Subconsulta correlacionada

### B1 — Versión con subconsultas correlacionadas

La primera versión utiliza subconsultas correlacionadas para calcular:

* cantidad de pedidos por cliente;
* gasto total del cliente.

Además, utiliza `EXISTS` para considerar únicamente clientes que poseen al menos un pedido.

**Resultado:** 20.000 filas.

### B2 — Versión con JOIN y GROUP BY

La segunda versión obtiene los mismos datos mediante `JOIN` entre `cliente`, `pedido` y `detalle_pedido`, agrupando por cliente.

Se utiliza `COUNT(DISTINCT p.id_pedido)` para contar cada pedido una sola vez, independientemente de la cantidad de detalles que pueda tener.

**Resultado:** 20.000 filas.

### Verificación de equivalencia

Se ejecutaron las dos diferencias de conjuntos:

* `B1 EXCEPT B2` → **0 filas**
* `B2 EXCEPT B1` → **0 filas**

Por lo tanto, ambas consultas producen el mismo conjunto de resultados sobre la base `bd2_tp4`.

La comprobación se realizó sobre las columnas:

* `id_cliente`
* `nombre_completo`
* `cantidad_pedidos`
* `gasto_total`

---

## 4. Resumen de resultados

| Consulta | Versión      |  Filas | Verificación |
| -------- | ------------ | -----: | ------------ |
| A        | A1           | 20.000 | —            |
| A        | A2           | 20.000 | —            |
| A        | A1 EXCEPT A2 |      0 | Equivalentes |
| A        | A2 EXCEPT A1 |      0 | Equivalentes |
| B        | B1           | 20.000 | —            |
| B        | B2           | 20.000 | —            |
| B        | B1 EXCEPT B2 |      0 | Equivalentes |
| B        | B2 EXCEPT B1 |      0 | Equivalentes |

## 5. Conclusión

Las dos alternativas de la Consulta A y las dos alternativas de la Consulta B fueron verificadas mediante `EXCEPT` en ambas direcciones.

En todos los casos se obtuvieron cero filas en las diferencias de conjuntos, por lo que las consultas resultaron equivalentes respecto de los resultados obtenidos en la base `bd2_tp4`.

La verificación corresponde a los datos existentes al momento de la ejecución y no implica que las consultas sean equivalentes para cualquier modificación futura del esquema o de las condiciones de la consulta.
