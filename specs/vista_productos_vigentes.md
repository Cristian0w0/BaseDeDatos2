# Especificación de Vista — v_productos_vigentes

## 1. Identificación de la vista

- **Nombre de la vista:** `v_productos_vigentes`
- **Tipo de objeto:** Vista estándar (`VIEW`)
- **Tablas involucradas:** `producto`, `categoria`
- **Propósito:** Proporcionar un acceso estandarizado a los productos comerciales activos junto con el nombre descriptivo de su categoría, encapsulando la lógica de filtrado de vigencia y la relación entre tablas.

---

## 2. Requerimientos y columnas a exponer

La vista debe exponer exactamente las siguientes columnas:
- `id_producto`: Identificador único del producto (`producto.id_producto`).
- `nombre`: Nombre del producto (`producto.nombre`).
- `precio`: Precio unitario actual (`producto.precio`).
- `stock`: Unidades en existencia (`producto.stock`).
- `categoria_id`: Identificador de la categoría foránea (`producto.categoria_id`).
- `nombre_categoria`: Nombre textual de la categoría (`categoria.nombre`), renombrado con alias para evitar ambigüedades.

---

## 3. Definición DDL

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
INNER JOIN categoria c ON c.id_categoria = p.categoria_id
WHERE p.activo = TRUE;
```

---

## 4. Reglas de diseño y negocio

1. **Filtro de vigencia:** Debe filtrar estrictamente `p.activo = TRUE` para excluir productos discontinuados o dados de baja.
2. **Unión de tablas:** Debe utilizar un `INNER JOIN` entre `producto` y `categoria` a través de la clave foránea `p.categoria_id = c.id_categoria`.
3. **Resolución de nombres:** Para evitar colisión con `producto.nombre`, el atributo `categoria.nombre` debe proyectarse explícitamente como `nombre_categoria`.
4. **Sin efectos colaterales:** Al tratarse de una vista estándar relacional, las consultas sobre ella leen directamente el estado actual de las tablas base sin almacenar datos duplicados.

---

## 5. Criterios de verificación y validación

1. **Verificación de resultados:**
   - Sobre la base de pruebas `bd2_tp5` (50000 productos totales), la vista debe devolver exactamente **46667 filas**, habiendo descartado los 3333 productos inactivos.
2. **Validación de equivalencia funcional:**
   - Se debe verificar la equivalencia exacta respecto a la consulta SQL manual utilizando el operador `EXCEPT` en ambos sentidos:

   ```sql
   -- Sentido 1: Vista menos consulta manual
   (
       SELECT id_producto, nombre, precio, stock, categoria_id, nombre_categoria
       FROM v_productos_vigentes
   )
   EXCEPT
   (
       SELECT p.id_producto, p.nombre, p.precio, p.stock, p.categoria_id, c.nombre AS nombre_categoria
       FROM producto p
       INNER JOIN categoria c ON c.id_categoria = p.categoria_id
       WHERE p.activo = TRUE
   );

   -- Sentido 2: Consulta manual menos vista
   (
       SELECT p.id_producto, p.nombre, p.precio, p.stock, p.categoria_id, c.nombre AS nombre_categoria
       FROM producto p
       INNER JOIN categoria c ON c.id_categoria = p.categoria_id
       WHERE p.activo = TRUE
   )
   EXCEPT
   (
       SELECT id_producto, nombre, precio, stock, categoria_id, nombre_categoria
       FROM v_productos_vigentes
   );
   ```
3. Ambas consultas de verificación deben arrojar exactamente **0 filas de diferencia**.
