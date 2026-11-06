-- ============================================================================
-- BDII - Unidad 7: NoSQL y nuevas formas de almacenamiento (Food Store)
-- Archivo: consultas_postgresql.sql
-- Consigna 5: Consultas equivalentes en PostgreSQL para comparación con MongoDB
-- ============================================================================
-- Nota de auditoría y verificación:
-- Las siguientes consultas son de estricta lectura (SELECT) y se ejecutan sobre
-- la base relacional canónica de Food Store poblada por la carga oficial.
-- Contrastan el subconjunto testigo de los primeros 5 pedidos (id_pedido 1 a 5)
-- migrados hacia la colección 'pedidos' de MongoDB.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Consigna 5 (Equivalente a 4b): Filtrar pedidos por estado 'ENTREGADO'
-- ----------------------------------------------------------------------------
SELECT 
    p.id_pedido,
    p.estado,
    p.fecha_pedido,
    p.forma_pago
FROM pedido p
WHERE p.estado = 'ENTREGADO'
  AND p.id_pedido BETWEEN 1 AND 5
ORDER BY p.id_pedido;

-- ----------------------------------------------------------------------------
-- Consigna 5 (Equivalente a 4c): Buscar pedidos que contengan un producto 
-- determinado (producto_id = 1 - Producto Inicial) en sus líneas
-- ----------------------------------------------------------------------------
-- Opción A: Mediante JOIN y DISTINCT (para evitar duplicados por líneas múltiples)
SELECT DISTINCT
    p.id_pedido,
    p.estado,
    dp.producto_id
FROM pedido p
JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
WHERE dp.producto_id = 1
  AND p.id_pedido BETWEEN 1 AND 5
ORDER BY p.id_pedido;

-- Opción B: Mediante subconsulta correlacionada semántica WHERE EXISTS
SELECT 
    p.id_pedido,
    p.estado
FROM pedido p
WHERE EXISTS (
    SELECT 1 
    FROM detalle_pedido dp 
    WHERE dp.pedido_id = p.id_pedido 
      AND dp.producto_id = 1
)
AND p.id_pedido BETWEEN 1 AND 5
ORDER BY p.id_pedido;
