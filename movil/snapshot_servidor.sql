-- ============================================================================
-- BASE DE DATOS II - UTN TUP
-- UNIDAD 8 / TRABAJO PRÁCTICO N.º 8 (TP10) - FOOD STORE MÓVIL
-- Archivo: movil/snapshot_servidor.sql
-- Consigna: 2.a - Tabla receptora de Instantánea y Carga en SQLite
-- ============================================================================

PRAGMA foreign_keys = ON;

-- Tabla receptora de la instantánea exportada del servidor (servidor_snapshot.csv)
CREATE TABLE IF NOT EXISTS snapshot_servidor (
    producto_id     INTEGER PRIMARY KEY,
    nombre          TEXT NOT NULL,
    precio_centavos INTEGER NOT NULL,
    stock           INTEGER NOT NULL,
    disponible      TEXT NOT NULL, -- Recibe 't' / 'f' del CSV de PostgreSQL
    eliminado       TEXT NOT NULL, -- Recibe 't' / 'f' del CSV de PostgreSQL
    capturado_en    TEXT NOT NULL
);

-- Actualización / Carga de producto_cache a partir de snapshot_servidor:
-- Convierte los flags booleanos 't'/'f' de PostgreSQL a enteros 1/0 para SQLite.
INSERT OR REPLACE INTO producto_cache (
    producto_id,
    nombre,
    precio_centavos,
    stock_visto,
    disponible_visto,
    eliminado,
    capturado_en
)
SELECT 
    s.producto_id,
    s.nombre,
    s.precio_centavos,
    s.stock,
    CASE WHEN s.disponible IN ('t', 'true', 'TRUE', '1', 1) THEN 1 ELSE 0 END,
    CASE WHEN s.eliminado IN ('t', 'true', 'TRUE', '1', 1) THEN 1 ELSE 0 END,
    s.capturado_en
FROM snapshot_servidor s;
