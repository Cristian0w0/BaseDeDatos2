-- ============================================================================
-- Archivo: sql/simulacro_incidente.sql
-- Proyecto: Food Store - UTN Base de Datos II
-- Unidad 5 · TP7 - Parte C: Simulación Controlada de Incidente de Seguridad
-- ============================================================================

SET search_path TO public;

\echo '=== PASO 1: Intentos fallidos de autenticación (Simulando ataque de fuerza bruta) ==='
SELECT * FROM fn_autenticar('admin@foodstore.com', '123456');
SELECT * FROM fn_autenticar('admin@foodstore.com', 'admin');
SELECT * FROM fn_autenticar('admin@foodstore.com', 'password2026');
SELECT * FROM fn_autenticar('admin@foodstore.com', 'FoodStore2026');
SELECT * FROM fn_autenticar('admin@foodstore.com', 'qwerty');

\echo '=== PASO 2: Inicio de sesión exitoso (Credencial comprometida) ==='
SELECT id, rol FROM fn_autenticar('admin@foodstore.com', 'Admin2026!Segura');

\echo '=== PASO 3: Exfiltración masiva de datos (Lectura completa de la tabla usuario) ==='
SELECT id, nombre, apellido, mail, celular, rol, eliminado, created_at
FROM usuario;

\echo '=== PASO 4: Intento de escalamiento vertical de privilegios ==='
DO $$
BEGIN
    EXECUTE 'GRANT admin_datos TO app_web';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'DEFENSA EXITOSA: El motor bloqueó el intento de otorgar admin_datos (insufficient_privilege).';
END $$;

DO $$
BEGIN
    EXECUTE 'ALTER ROLE app_web SUPERUSER';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'DEFENSA EXITOSA: El motor bloqueó el intento de modificar atributos administrativos (insufficient_privilege).';
END $$;

\echo '=== PASO 5: Verificación de estado de seguridad tras el incidente ==='
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb
FROM pg_roles
WHERE rolname = 'app_web';
