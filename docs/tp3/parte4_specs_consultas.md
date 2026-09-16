# Parte 4 — Especificaciones precisas de consultas

## Consulta 1 — Resumen de productos vigentes por categoría

### Especificación

Generar una consulta SQL sobre el esquema de Food Store que cumpla exactamente con las siguientes condiciones:

* **Tabla principal:** `categoria`.
* **Tabla relacionada:** `producto`.
* La consulta debe considerar únicamente **categorías vigentes**, es decir, aquellas donde `categoria.activa = TRUE`.
* También debe considerar únicamente **productos vigentes**, es decir, aquellos donde `producto.activo = TRUE`.
* Deben aparecer **todas las categorías vigentes**, incluso aquellas que no tengan ningún producto vigente.
* La consulta debe devolver exactamente estas columnas:

  * `categoria.nombre`
  * cantidad de productos vigentes de esa categoría.
* La cantidad debe ser `0` cuando una categoría vigente no tenga productos vigentes.
* No utilizar `SELECT *`.
* Ordenar el resultado por cantidad de productos vigentes de **mayor a menor**.
* En caso de empate, ordenar por `categoria.nombre` en orden alfabético ascendente.
* No aplicar `LIMIT`.
* La consulta debe utilizar agregación para obtener la cantidad de productos.

---

## Consulta 2 — Productos por encima del precio promedio

### Especificación

Generar una consulta SQL sobre el esquema de Food Store que cumpla exactamente con las siguientes condiciones:

* **Tabla principal:** `producto`.
* Para determinar el precio promedio se deben considerar únicamente **productos vigentes**, es decir, aquellos donde `producto.activo = TRUE`.
* La consulta principal también debe mostrar únicamente productos vigentes.
* La consulta debe devolver los productos cuyo precio sea **estrictamente mayor** que el precio promedio de los productos vigentes.
* El precio promedio debe calcularse sobre todos los productos vigentes, sin limitar previamente la cantidad de productos utilizados para calcularlo.
* La consulta debe utilizar una **subconsulta** para obtener el precio promedio.
* Debe devolver exactamente estas columnas:

  * `producto.id_producto`
  * `producto.nombre`
  * `producto.precio`
* No utilizar `SELECT *`.
* Ordenar por `producto.precio` de **mayor a menor**.
* En caso de empate de precio, ordenar por `producto.id_producto` de menor a mayor.
* No aplicar `LIMIT`.
* Los productos con precio exactamente igual al promedio **no deben incluirse**.
