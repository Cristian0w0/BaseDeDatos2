-- ============================================================================
-- BASE DE DATOS II - UTN TUP
-- UNIDAD 8 / TRABAJO PRÁCTICO N.º 8 (TP10) - FOOD STORE MÓVIL
-- Archivo: movil/servidor_casos_c2_c4.sql
-- Consigna: 2.c - Cambios en la copia del servidor (PostgreSQL) y reexportación
-- ============================================================================
-- Regla de Oro: "El móvil propone, el servidor dispone".
-- Este script documenta las operaciones ejecutadas en la base central PostgreSQL
-- para los escenarios de sincronización C2 (suba de precio) y C4 (baja lógica).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CASO C2: CAMBIO DE PRECIO EN EL SERVIDOR
-- La tablet armó un borrador con Pizza Muzzarella (ID 1) a $9.000 (900000 centavos).
-- En la oficina central (PostgreSQL), el precio sube a $10.500 ($105.00).
-- ----------------------------------------------------------------------------
BEGIN;

UPDATE producto
SET precio = 105.00
WHERE id_producto = 1;

-- El servidor genera y exporta una nueva instantánea actualizada:
-- \copy (SELECT * FROM v_snapshot_movil) TO 'movil/servidor_snapshot.csv' CSV HEADER;

COMMIT;

-- ----------------------------------------------------------------------------
-- 2. CASO C4: BAJA LÓGICA DE PRODUCTO EN EL SERVIDOR (LÁPIDA)
-- La tablet armó un borrador con Empanada de Jamón y Queso (ID 7).
-- Minutos después, el servidor da de baja el producto (activo = FALSE).
-- ----------------------------------------------------------------------------
BEGIN;

UPDATE producto
SET activo = FALSE
WHERE id_producto = 7;

-- El servidor genera y exporta una nueva instantánea donde el producto 7
-- viaja con disponible = 'f' y eliminado = 't' (lápida):
-- \copy (SELECT * FROM v_snapshot_movil) TO 'movil/servidor_snapshot.csv' CSV HEADER;

COMMIT;

-- ----------------------------------------------------------------------------
-- 3. COMPROBACIÓN FINAL EN POSTGRESQL (CONSIGNA 2.c)
-- Comprobar que ninguna prueba, borrador ni semáforo de la tablet alteró los
-- pedidos confirmados ni el stock en la base central de datos.
-- ----------------------------------------------------------------------------
SELECT 
    (SELECT COUNT(*) FROM pedido) AS total_pedidos_servidor,
    (SELECT SUM(stock) FROM producto) AS stock_total_consolidado;
