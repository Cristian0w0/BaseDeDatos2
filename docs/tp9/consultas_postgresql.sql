-- ============================================================================
-- BDII - Unidad 7: NoSQL y nuevas formas de almacenamiento (Food Store)
-- Archivo: consultas_postgresql.sql
-- Consigna 5: Consultas equivalentes en PostgreSQL para comparación con MongoDB
-- ============================================================================

-- Asegurar columna 'estado' en la tabla pedido si la instancia base no la poseía
ALTER TABLE pedido ADD COLUMN IF NOT EXISTS estado VARCHAR(30) DEFAULT 'ENTREGADO';

-- Actualizar estados de los pedidos de muestra para coincidir con el lote de MongoDB
UPDATE pedido SET estado = 'ENTREGADO' WHERE id_pedido IN (1, 3, 4);
UPDATE pedido SET estado = 'PENDIENTE' WHERE id_pedido = 2;
UPDATE pedido SET estado = 'CONFIRMADO' WHERE id_pedido = 5;

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
-- determinado (producto_id = 1 - Hamburguesa Clásica) en sus líneas
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
