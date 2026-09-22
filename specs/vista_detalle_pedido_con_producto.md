# Especificación de Vista — v_detalle_pedido_con_producto

## 1. Identificación de la vista

- **Nombre de la vista:** `v_detalle_pedido_con_producto`
- **Tipo de objeto:** Vista estándar (`VIEW`)
- **Tablas involucradas:** `detalle_pedido`, `producto`
- **Propósito:** Proveer un acceso consolidado a los ítems y detalles de los pedidos incorporando la denominación descriptiva del producto correspondiente, facilitando la emisión de reportes comerciales y auditoría de ventas.

---

## 2. Requerimientos y columnas a exponer

La vista debe exponer exactamente las siguientes columnas:
- `pedido_id`: Identificador del pedido asociado (`detalle_pedido.pedido_id`).
- `producto_id`: Identificador del producto vendido (`detalle_pedido.producto_id`).
- `cantidad`: Cantidad de unidades vendidas (`detalle_pedido.cantidad`).
- `precio_unitario`: Precio pactado al momento de la venta (`detalle_pedido.precio_unitario`).
- `nombre_producto`: Nombre del producto (`producto.nombre`), renombrado con alias para mayor claridad.

---

## 3. Definición DDL

```sql
CREATE OR REPLACE VIEW v_detalle_pedido_con_producto AS
SELECT
    dp.pedido_id,
    dp.producto_id,
    dp.cantidad,
    dp.precio_unitario,
    pr.nombre AS nombre_producto
FROM detalle_pedido dp
INNER JOIN producto pr ON pr.id_producto = dp.producto_id;
```

---

## 4. Reglas de diseño y negocio

1. **Preservación del historial de ventas:** No se debe filtrar por `pr.activo = TRUE`. Los productos discontinuados o dados de baja posteriormente deben permanecer visibles en los detalles de pedidos históricos.
2. **Unión de tablas:** La asociación se realiza mediante `INNER JOIN` utilizando la clave foránea `dp.producto_id = pr.id_producto`.
3. **Resolución de nombres:** La columna `producto.nombre` se proyecta explícitamente como `nombre_producto` para evitar ambigüedades y dar contexto claro al detalle del ítem.
4. **Comportamiento relacional:** Al tratarse de una vista estándar relacional, no duplica ni materializa datos físicamente, reflejando de forma inmediata cualquier cambio en las tablas base.

---

## 5. Criterios de verificación y validación

1. **Verificación de resultados:**
   - En la base de datos de pruebas `bd2_tp5` (con 200000 detalles de pedido), la vista debe devolver exactamente **200000 filas**.
2. **Validación de equivalencia funcional:**
   - Se debe verificar la equivalencia exacta respecto a la consulta SQL manual utilizando el operador `EXCEPT` en ambos sentidos:

   ```sql
   -- Sentido 1: Vista menos consulta manual
   (
       SELECT pedido_id, producto_id, cantidad, precio_unitario, nombre_producto
       FROM v_detalle_pedido_con_producto
   )
   EXCEPT
   (
       SELECT dp.pedido_id, dp.producto_id, dp.cantidad, dp.precio_unitario, pr.nombre AS nombre_producto
       FROM detalle_pedido dp
       INNER JOIN producto pr ON pr.id_producto = dp.producto_id
   );

   -- Sentido 2: Consulta manual menos vista
   (
       SELECT dp.pedido_id, dp.producto_id, dp.cantidad, dp.precio_unitario, pr.nombre AS nombre_producto
       FROM detalle_pedido dp
       INNER JOIN producto pr ON pr.id_producto = dp.producto_id
   )
   EXCEPT
   (
       SELECT pedido_id, producto_id, cantidad, precio_unitario, nombre_producto
       FROM v_detalle_pedido_con_producto
   );
   ```
3. Ambas consultas de verificación deben arrojar exactamente **0 diferencias**.
