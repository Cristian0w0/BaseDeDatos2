-- ============================================================================
-- Archivo: db/auditoria_test.sql
-- Proyecto: Food Store - UTN Base de Datos II
-- Unidad 5 · TP7 - Parte B: Secuencia de Prueba de Auditoría Nativa
-- ============================================================================
-- Esta secuencia ejecuta las 4 operaciones requeridas para verificar el registro
-- de auditoría en el log del servidor:
-- 1. Lectura de catálogo
-- 2. Inserción de prueba
-- 3. Modificación (actualización)
-- 4. Intento fallido de autenticación
-- ============================================================================

SET search_path TO public;

-- Operación 1: Lectura rutinaria del catálogo (no genera registro bajo log_statement='mod')
SELECT id_producto, nombre, precio, stock
FROM v_productos_vigentes
LIMIT 2;

-- Operación 2: Inserción de prueba (genera registro en el log por ser DML de escritura)
INSERT INTO pedido (cliente_id, fecha_pedido, forma_pago)
VALUES (1, now(), 'EFECTIVO'::forma_pago);

-- Operación 3: Actualización de prueba (genera registro en el log)
UPDATE producto
SET stock = stock + 5
WHERE id_producto = 1;

-- Operación 4: Intento de inicio de sesión fallido contra fn_autenticar
-- (Devuelve 0 filas y queda registrado en el log del servidor)
SELECT *
FROM fn_autenticar('admin@foodstore.com', 'ClaveTotalmenteErronea_12345');
