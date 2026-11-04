-- ============================================================================
-- BASE DE DATOS II - UTN TUP
-- UNIDAD 8 / TRABAJO PRÁCTICO N.º 8 (TP10) - FOOD STORE MÓVIL
-- Archivo: movil/postgresql_snapshot.sql
-- Consigna: 2.a - Vista de Instantánea y Exportación en PostgreSQL (Servidor)
-- ============================================================================

-- Vista oficial que genera la instantánea del catálogo para los dispositivos móviles.
-- Convierte el precio decimal a centavos enteros (INTEGER) para evitar imprecisiones de redondeo.
-- Aplica la lógica de bajas lógicas (lápidas): si la categoría o el producto están inactivos, viaja como eliminado.
CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT 
    p.id_producto                       AS producto_id,
    p.nombre                            AS nombre,
    (p.precio * 100)::INTEGER           AS precio_centavos,
    p.stock                             AS stock,
    (p.activo AND c.activa)             AS disponible,
    (NOT p.activo OR NOT c.activa)      AS eliminado,
    now()                               AS capturado_en
FROM producto p
JOIN categoria c ON c.id_categoria = p.categoria_id;

-- Comando de exportación para ejecutar desde psql (PostgreSQL):
-- \copy (SELECT * FROM v_snapshot_movil) TO 'movil/servidor_snapshot.csv' CSV HEADER
