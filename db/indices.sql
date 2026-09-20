-- TP5 - Índices
-- Índices aceptados luego de analizar el workload y validar
-- su comportamiento mediante EXPLAIN (ANALYZE, BUFFERS).

-- 1. Consultas de pedidos con forma de pago TARJETA,
--    filtradas por fecha y ordenadas de forma descendente.
--    Índice parcial: solo mantiene las filas relevantes para
--    este patrón de consulta.
CREATE INDEX idx_pedido_tarjeta_fecha
    ON pedido (fecha_pedido DESC)
    WHERE forma_pago = 'TARJETA';


-- 2. Consulta de productos activos ordenados por precio DESC
--    con LIMIT para obtener los productos de mayor precio.
--    Índice parcial: excluye productos inactivos y permite
--    resolver el ORDER BY directamente mediante el índice.
CREATE INDEX idx_producto_activo_precio
    ON producto (precio DESC)
    WHERE activo = TRUE;