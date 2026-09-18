-- =============================================================================
-- TRABAJO PRÁCTICO BASE DE DATOS 2 - PARTE 3
-- Consultas SQL para Food Store (PostgreSQL)
-- =============================================================================

-- =============================================================================
-- 1. CONSULTA A — RANKING DE CLIENTES POR GASTO
-- =============================================================================

-- A1: Versión con JOIN + GROUP BY + RANK()
SELECT 
    c.id_cliente,
    c.nombre || ' ' || c.apellido AS nombre_completo,
    SUM(dp.cantidad * dp.precio_unitario) AS gasto_total,
    RANK() OVER (ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC) AS posicion_ranking
FROM cliente c
JOIN pedido p ON c.id_cliente = p.cliente_id
JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY gasto_total DESC, c.id_cliente ASC;

-- A2: Versión con CTE de pre-agregación + JOIN + RANK()
WITH gasto_por_cliente AS (
    SELECT 
        p.cliente_id,
        SUM(dp.cantidad * dp.precio_unitario) AS gasto_total
    FROM pedido p
    JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
    GROUP BY p.cliente_id
)
SELECT 
    c.id_cliente,
    c.nombre || ' ' || c.apellido AS nombre_completo,
    gpc.gasto_total,
    RANK() OVER (ORDER BY gpc.gasto_total DESC) AS posicion_ranking
FROM cliente c
JOIN gasto_por_cliente gpc ON c.id_cliente = gpc.cliente_id
ORDER BY gpc.gasto_total DESC, c.id_cliente ASC;


-- =============================================================================
-- 2. VERIFICACIÓN DE EQUIVALENCIA — CONSULTA A
-- =============================================================================

-- A1 EXCEPT A2 (Filas en A1 que no están en A2)
(
    SELECT 
        c.id_cliente,
        c.nombre || ' ' || c.apellido AS nombre_completo,
        SUM(dp.cantidad * dp.precio_unitario) AS gasto_total,
        RANK() OVER (ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC) AS posicion_ranking
    FROM cliente c
    JOIN pedido p ON c.id_cliente = p.cliente_id
    JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
    GROUP BY c.id_cliente, c.nombre, c.apellido
)
EXCEPT
(
    WITH gasto_por_cliente AS (
        SELECT 
            p.cliente_id,
            SUM(dp.cantidad * dp.precio_unitario) AS gasto_total
        FROM pedido p
        JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
        GROUP BY p.cliente_id
    )
    SELECT 
        c.id_cliente,
        c.nombre || ' ' || c.apellido AS nombre_completo,
        gpc.gasto_total,
        RANK() OVER (ORDER BY gpc.gasto_total DESC) AS posicion_ranking
    FROM cliente c
    JOIN gasto_por_cliente gpc ON c.id_cliente = gpc.cliente_id
);

-- A2 EXCEPT A1 (Filas en A2 que no están en A1)
(
    WITH gasto_por_cliente AS (
        SELECT 
            p.cliente_id,
            SUM(dp.cantidad * dp.precio_unitario) AS gasto_total
        FROM pedido p
        JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
        GROUP BY p.cliente_id
    )
    SELECT 
        c.id_cliente,
        c.nombre || ' ' || c.apellido AS nombre_completo,
        gpc.gasto_total,
        RANK() OVER (ORDER BY gpc.gasto_total DESC) AS posicion_ranking
    FROM cliente c
    JOIN gasto_por_cliente gpc ON c.id_cliente = gpc.cliente_id
)
EXCEPT
(
    SELECT 
        c.id_cliente,
        c.nombre || ' ' || c.apellido AS nombre_completo,
        SUM(dp.cantidad * dp.precio_unitario) AS gasto_total,
        RANK() OVER (ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC) AS posicion_ranking
    FROM cliente c
    JOIN pedido p ON c.id_cliente = p.cliente_id
    JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
    GROUP BY c.id_cliente, c.nombre, c.apellido
);


-- =============================================================================
-- 3. CONSULTA B — GASTO POR CLIENTE MEDIANTE SUBCONSULTA CORRELACIONADA
-- =============================================================================

-- B1: Versión con subconsultas correlacionadas
SELECT 
    c.id_cliente,
    c.nombre || ' ' || c.apellido AS nombre_completo,
    (
        SELECT COUNT(p.id_pedido)
        FROM pedido p
        WHERE p.cliente_id = c.id_cliente
    ) AS cantidad_pedidos,
    (
        SELECT SUM(dp.cantidad * dp.precio_unitario)
        FROM pedido p
        JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
        WHERE p.cliente_id = c.id_cliente
    ) AS gasto_total
FROM cliente c
WHERE EXISTS (
    SELECT 1
    FROM pedido p
    WHERE p.cliente_id = c.id_cliente
)
ORDER BY c.id_cliente ASC;

-- B2: Versión con JOIN + GROUP BY
SELECT 
    c.id_cliente,
    c.nombre || ' ' || c.apellido AS nombre_completo,
    COUNT(DISTINCT p.id_pedido) AS cantidad_pedidos,
    SUM(dp.cantidad * dp.precio_unitario) AS gasto_total
FROM cliente c
JOIN pedido p ON c.id_cliente = p.cliente_id
JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY c.id_cliente ASC;


-- =============================================================================
-- 4. VERIFICACIÓN DE EQUIVALENCIA — CONSULTA B
-- =============================================================================

-- B1 EXCEPT B2 (Filas en B1 que no están en B2)
(
    SELECT 
        c.id_cliente,
        c.nombre || ' ' || c.apellido AS nombre_completo,
        (
            SELECT COUNT(p.id_pedido)
            FROM pedido p
            WHERE p.cliente_id = c.id_cliente
        ) AS cantidad_pedidos,
        (
            SELECT SUM(dp.cantidad * dp.precio_unitario)
            FROM pedido p
            JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
            WHERE p.cliente_id = c.id_cliente
        ) AS gasto_total
    FROM cliente c
    WHERE EXISTS (
        SELECT 1
        FROM pedido p
        WHERE p.cliente_id = c.id_cliente
    )
)
EXCEPT
(
    SELECT 
        c.id_cliente,
        c.nombre || ' ' || c.apellido AS nombre_completo,
        COUNT(DISTINCT p.id_pedido) AS cantidad_pedidos,
        SUM(dp.cantidad * dp.precio_unitario) AS gasto_total
    FROM cliente c
    JOIN pedido p ON c.id_cliente = p.cliente_id
    JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
    GROUP BY c.id_cliente, c.nombre, c.apellido
);

-- B2 EXCEPT B1 (Filas en B2 que no están en B1)
(
    SELECT 
        c.id_cliente,
        c.nombre || ' ' || c.apellido AS nombre_completo,
        COUNT(DISTINCT p.id_pedido) AS cantidad_pedidos,
        SUM(dp.cantidad * dp.precio_unitario) AS gasto_total
    FROM cliente c
    JOIN pedido p ON c.id_cliente = p.cliente_id
    JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
    GROUP BY c.id_cliente, c.nombre, c.apellido
)
EXCEPT
(
    SELECT 
        c.id_cliente,
        c.nombre || ' ' || c.apellido AS nombre_completo,
        (
            SELECT COUNT(p.id_pedido)
            FROM pedido p
            WHERE p.cliente_id = c.id_cliente
        ) AS cantidad_pedidos,
        (
            SELECT SUM(dp.cantidad * dp.precio_unitario)
            FROM pedido p
            JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
            WHERE p.cliente_id = c.id_cliente
        ) AS gasto_total
    FROM cliente c
    WHERE EXISTS (
        SELECT 1
        FROM pedido p
        WHERE p.cliente_id = c.id_cliente
    )
);
