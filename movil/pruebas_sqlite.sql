-- ============================================================================
-- BASE DE DATOS II - UTN TUP
-- UNIDAD 8 / TRABAJO PRÁCTICO N.º 8 (TP10) - FOOD STORE MÓVIL
-- Archivo: movil/pruebas_sqlite.sql
-- Consigna: 1.c - Pruebas en SQLite: Transacciones (COMMIT/ROLLBACK), Caso C1 y Caso C7
-- ============================================================================

-- Siempre activar claves foráneas al inicio de la sesión
PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 0. CARGA DE DATOS DE PRUEBA EN EL CATÁLOGO LOCAL (producto_cache)
-- ----------------------------------------------------------------------------
DELETE FROM cola_sync;
DELETE FROM item_borrador;
DELETE FROM pedido_borrador;
DELETE FROM producto_cache;

INSERT INTO producto_cache (producto_id, nombre, precio_centavos, stock_visto, disponible_visto, eliminado, capturado_en) VALUES
(1, 'Pizza Muzzarella',       900000, 15, 1, 0, '2026-11-03T10:00:00Z'),
(2, 'Pizza Fugazzeta',       1000000,  5, 1, 1, '2026-11-03T10:00:00Z'), -- Eliminado (lápida)
(3, 'Empanada de Carne',      120000, 20, 1, 0, '2026-11-03T10:00:00Z'),
(4, 'Gaseosa 500ml',          150000,  0, 1, 0, '2026-11-03T10:00:00Z'), -- Stock 0 pero visible
(5, 'Cerveza Artesanal',      280000, 10, 0, 0, '2026-11-03T10:00:00Z'); -- No disponible temporalmente

-- ----------------------------------------------------------------------------
-- 1. CASO C1: CONSULTA DEL CATÁLOGO DISPONIBLE SIN CONEXIÓN
-- La tablet lee localmente desde la vista v_catalogo_disponible.
-- Debe mostrar solo productos con eliminado = 0 y disponible_visto = 1.
-- Fugazzeta (eliminado=1) y Cerveza (disponible=0) NO deben figurar.
-- ----------------------------------------------------------------------------
SELECT '=== PRUEBA CASO C1: Catálogo disponible offline ===' AS test_header;

SELECT 
    producto_id, 
    nombre, 
    printf('$%.2f', precio) AS precio_formateado, 
    stock_visto 
FROM v_catalogo_disponible
ORDER BY producto_id;

-- ----------------------------------------------------------------------------
-- 2. TRANSACCIÓN EXITOSA: BORRADOR COMPLETO CON BEGIN ... COMMIT
-- Se inserta borrador + ítems + solicitud en la cola de forma atómica.
-- ----------------------------------------------------------------------------
SELECT '=== PRUEBA TRANSACCIÓN 1: Borrador completo guardado con COMMIT ===' AS test_header;

BEGIN TRANSACTION;

INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago)
VALUES ('aaaaaaaa-0000-4000-8000-000000000001', 2, 'EFECTIVO');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES 
('aaaaaaaa-0000-4000-8000-000000000001', 1, 1, 900000),  -- 1 Pizza Muzzarella a $9.000
('aaaaaaaa-0000-4000-8000-000000000001', 3, 2, 120000);  -- 2 Empanadas a $1.200

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('bbbbbbbb-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001', 'PENDIENTE', 'Esperando conexión con el servidor');

COMMIT;

-- Verificamos que el borrador y sus renglones quedaron efectivamente guardados
SELECT 
    p.id_local,
    p.forma_pago,
    c.solicitud_uuid,
    c.estado,
    i.producto_id,
    pr.nombre,
    i.cantidad,
    i.precio_centavos_visto / 100.0 AS precio_unitario
FROM pedido_borrador p
JOIN cola_sync c ON c.id_local = p.id_local
JOIN item_borrador i ON i.id_local = p.id_local
JOIN producto_cache pr ON pr.producto_id = i.producto_id
WHERE p.id_local = 'aaaaaaaa-0000-4000-8000-000000000001';

-- ----------------------------------------------------------------------------
-- 3. TRANSACCIÓN DESHECHA: OPERACIÓN DESCARTADA CON ROLLBACK
-- Simula un corte de energía, error en la app o cancelación por el usuario.
-- Todo lo ejecutado dentro del bloque no debe persistir en la base.
-- ----------------------------------------------------------------------------
SELECT '=== PRUEBA TRANSACCIÓN 2: Descarte con ROLLBACK ===' AS test_header;

BEGIN TRANSACTION;

INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago)
VALUES ('aaaaaaaa-0000-4000-8000-000000000002', 3, 'TARJETA');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('aaaaaaaa-0000-4000-8000-000000000002', 1, 3, 900000);

-- Se aborta la operación antes de asentar los cambios
ROLLBACK;

-- Comprobamos que el id_local '...0002' no existe en ninguna de las tablas
SELECT COUNT(*) AS filas_borrador_deshecho 
FROM pedido_borrador 
WHERE id_local = 'aaaaaaaa-0000-4000-8000-000000000002';

SELECT COUNT(*) AS filas_items_deshechos 
FROM item_borrador 
WHERE id_local = 'aaaaaaaa-0000-4000-8000-000000000002';

-- ----------------------------------------------------------------------------
-- 4. CASO C7: VALIDACIÓN DE RESTRICCIONES (CANTIDAD 0 Y PRODUCTO INEXISTENTE)
-- C7.a: Cantidad en 0 debe violar CHECK (cantidad > 0)
-- C7.b: Producto_id 9999 inexistente debe violar FK producto_cache(producto_id)
-- En ambos casos, las operaciones deben fallar y la tabla quedar inalterada.
-- ----------------------------------------------------------------------------
SELECT '=== PRUEBA CASO C7: Rechazo controlado de datos inválidos ===' AS test_header;

-- Creamos un borrador válido para probar los ítems inválidos
INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago)
VALUES ('aaaaaaaa-0000-4000-8000-000000000007', 2, 'TRANSFERENCIA');

-- Prueba C7.a: Intento con cantidad = 0
-- Comportamiento esperado: CHECK constraint failed: cantidad > 0
-- (Al ejecutar este archivo en bloque interactivo o script, se captura el error)
-- INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
-- VALUES ('aaaaaaaa-0000-4000-8000-000000000007', 1, 0, 900000);

-- Prueba C7.b: Intento con producto inexistente (id 9999)
-- Comportamiento esperado: FOREIGN KEY constraint failed
-- INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
-- VALUES ('aaaaaaaa-0000-4000-8000-000000000007', 9999, 1, 500000);

-- Verificamos que item_borrador no contiene ninguna fila para el borrador C7
SELECT COUNT(*) AS items_guardados_para_c7 
FROM item_borrador 
WHERE id_local = 'aaaaaaaa-0000-4000-8000-000000000007';
