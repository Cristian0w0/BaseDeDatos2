-- ============================================================================
-- BASE DE DATOS II - UTN TUP
-- UNIDAD 8 / TRABAJO PRÁCTICO N.º 8 (TP10) - FOOD STORE MÓVIL
-- Archivo: movil/schema_sqlite.sql
-- Consigna: 1.b - Esquema SQLite de la tablet (STRICT tables, PRAGMA foreign_keys)
-- ============================================================================

-- SQLite requiere activar explícitamente el soporte de claves foráneas en cada conexión.
PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- Tabla: producto_cache
-- Copia local del catálogo traída desde PostgreSQL para permitir consulta offline.
-- Los precios se almacenan en centavos enteros para evitar errores de coma flotante.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS producto_cache (
    producto_id      INTEGER PRIMARY KEY,
    nombre           TEXT    NOT NULL,
    precio_centavos  INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto      INTEGER NOT NULL CHECK (stock_visto >= 0),
    disponible_visto INTEGER NOT NULL CHECK (disponible_visto IN (0, 1)),
    eliminado        INTEGER NOT NULL DEFAULT 0 CHECK (eliminado IN (0, 1)),
    capturado_en     TEXT    NOT NULL
) STRICT;

-- ----------------------------------------------------------------------------
-- Tabla: pedido_borrador
-- Borradores de pedidos tomados en el food truck sin señal. No son ventas aún.
-- El id_local es un UUID generado en el dispositivo móvil.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pedido_borrador (
    id_local            TEXT    PRIMARY KEY,
    usuario_id_servidor INTEGER NOT NULL,
    forma_pago          TEXT    NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    creado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
) STRICT;

-- ----------------------------------------------------------------------------
-- Tabla: item_borrador
-- Renglones de productos del borrador con el precio congelado visto por el cliente.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS item_borrador (
    id_local              TEXT    NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    producto_id           INTEGER NOT NULL REFERENCES producto_cache(producto_id),
    cantidad              INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id)
) STRICT;

-- ----------------------------------------------------------------------------
-- Tabla: cola_sync
-- Registro de cada intento de sincronización / envío con el servidor y su semáforo.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cola_sync (
    solicitud_uuid TEXT PRIMARY KEY,
    id_local       TEXT NOT NULL REFERENCES pedido_borrador(id_local),
    estado         TEXT NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo         TEXT,
    creada_en      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
) STRICT;

-- Regla de integridad: un borrador no puede tener más de una solicitud PENDIENTE activa a la vez.
CREATE UNIQUE INDEX IF NOT EXISTS ux_cola_una_pendiente 
    ON cola_sync (id_local) 
    WHERE estado = 'PENDIENTE';

-- ----------------------------------------------------------------------------
-- Vista: v_catalogo_disponible
-- Interfaz de consulta para la pantalla del vendedor: productos no eliminados y disponibles.
-- Convierte centavos a precio legible (decimal) para presentación.
-- ----------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS v_catalogo_disponible AS
SELECT 
    producto_id,
    nombre,
    precio_centavos / 100.0 AS precio,
    stock_visto
FROM producto_cache
WHERE eliminado = 0 AND disponible_visto = 1;
