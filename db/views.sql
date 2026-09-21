-- views.sql
-- Food Store - PostgreSQL
-- Definición de vistas del sistema

-- ============================================================
-- 1. Vista de productos vigentes
-- ============================================================
-- Vista que expone únicamente los productos activos (vigentes) junto con el nombre de su categoría.
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

-- ============================================================
-- 2. Vista de pedidos con cliente
-- ============================================================
-- Vista que combina la información de los pedidos con los datos del cliente correspondiente.
-- Nota: La exclusión de contraseña no puede demostrarse explícitamente en la consulta porque el esquema actual de la tabla 'cliente' no almacena contraseñas ni credenciales.
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
INNER JOIN cliente c ON c.id_cliente = p.cliente_id;

-- ============================================================
-- 3. Vista de detalle de pedido con producto
-- ============================================================
-- Vista que detalla las líneas de pedido incorporando el nombre del producto correspondiente.
-- No se filtra por pr.activo para preservar el registro histórico de las ventas realizadas.
CREATE OR REPLACE VIEW v_detalle_pedido_con_producto AS
SELECT
    dp.pedido_id,
    dp.producto_id,
    dp.cantidad,
    dp.precio_unitario,
    pr.nombre AS nombre_producto
FROM detalle_pedido dp
INNER JOIN producto pr ON pr.id_producto = dp.producto_id;

-- ============================================================
-- 4. Vista materializada de resumen de gasto por cliente
-- ============================================================
-- Vista materializada que calcula el gasto total acumulado por cliente
-- a partir de la información de cliente, pedido y detalle_pedido.
CREATE MATERIALIZED VIEW v_resumen_gasto_cliente AS
SELECT
    c.id_cliente,
    c.nombre || ' ' || c.apellido AS nombre_completo,
    SUM(dp.cantidad * dp.precio_unitario) AS gasto_total
FROM cliente c
INNER JOIN pedido p ON p.cliente_id = c.id_cliente
INNER JOIN detalle_pedido dp ON dp.pedido_id = p.id_pedido
GROUP BY c.id_cliente, c.nombre, c.apellido
WITH DATA;

-- Índice único sobre id_cliente necesario para permitir refrescar
-- la vista materializada en forma concurrente (REFRESH MATERIALIZED VIEW CONCURRENTLY).
CREATE UNIQUE INDEX idx_v_resumen_gasto_cliente_cliente
    ON v_resumen_gasto_cliente (id_cliente);
