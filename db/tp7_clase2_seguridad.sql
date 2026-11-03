-- ============================================================================
-- Archivo: db/tp7_clase2_seguridad.sql
-- Proyecto: Food Store - UTN Base de Datos II
-- Unidad 5 · Clase 2: Mitigación de Amenazas y Protección de Datos Personales
-- ============================================================================
-- Este script implementa los mecanismos trabajados en la Clase 2:
-- 1. Función de autenticación segura anti SQL Injection (fn_autenticar).
-- 2. Función acotada SECURITY DEFINER para reseteo de contraseñas (fn_resetear_password).
-- 3. Dataset anonimizado determinista (usuario_anon) para testing y consultas de IA.
-- 4. Batería de pruebas de verificación de seguridad.
-- ============================================================================

SET search_path TO public;

-- ============================================================================
-- 1. FUNCIÓN DE AUTENTICACIÓN SEGURA (Anti SQL Injection)
-- ============================================================================
-- Principio: Los valores ingresados por el usuario viajan como parámetros tipados
-- en PL/pgSQL, eliminando cualquier vector de inyección de código.
-- Cláusula: SECURITY INVOKER (ejecuta con los permisos de la sesión conectada).

CREATE OR REPLACE FUNCTION fn_autenticar(p_mail TEXT, p_pass TEXT)
RETURNS TABLE(id BIGINT, rol rol) AS $$
BEGIN
    RETURN QUERY
    SELECT u.id, u.rol
    FROM usuario u
    WHERE u.mail = p_mail
      AND u.contrasena = crypt(p_pass, u.contrasena)
      AND u.eliminado = FALSE;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Gestión estricta de permisos de ejecución
REVOKE ALL ON FUNCTION fn_autenticar(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_autenticar(TEXT, TEXT) TO app_web, rol_app_lectura;


-- ============================================================================
-- 2. FUNCIÓN DE RESETEO DE CONTRASEÑA (SECURITY DEFINER Endurecido)
-- ============================================================================
-- Permite que rol_soporte restablezca una contraseña sin otorgarle UPDATE directo
-- sobre la tabla usuario.
-- Mitigación CVE-2018-1058: SET search_path = public, pg_temp fija de forma
-- estricta los esquemas de resolución, previniendo secuestro de funciones/tablas.

CREATE OR REPLACE FUNCTION fn_resetear_password(
    p_usuario_id BIGINT,
    p_nueva TEXT
) RETURNS VOID
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Validar existencia del usuario activo
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE id = p_usuario_id AND eliminado = FALSE) THEN
        RAISE EXCEPTION 'Usuario con ID % no encontrado o dado de baja.', p_usuario_id;
    END IF;

    -- Validación de política de contraseñas mínima
    IF length(trim(p_nueva)) < 8 THEN
        RAISE EXCEPTION 'La nueva contraseña debe tener al menos 8 caracteres.';
    END IF;

    -- Actualización protegida usando algoritmo Blowfish (bf) con sal aleatoria
    UPDATE usuario
    SET contrasena = crypt(p_nueva, gen_salt('bf'))
    WHERE id = p_usuario_id AND eliminado = FALSE;
END;
$$ LANGUAGE plpgsql;

-- Mínimo privilegio: Solo rol_soporte recibe el permiso de ejecución
REVOKE ALL ON FUNCTION fn_resetear_password(BIGINT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_resetear_password(BIGINT, TEXT) TO rol_soporte;


-- ============================================================================
-- 3. DATASET DE PRUEBA ANONIMIZADO (usuario_anon)
-- ============================================================================
-- Cumplimiento de la Ley 25.326 y frontera de privacidad con asistentes de IA.
-- Destruye de forma irreversible el vínculo con personas reales manteniendo:
-- - Cardinalidad idéntica fila por fila.
-- - Unicidad y formato de correos ('usuario' || id || '@ejemplo.test').
-- - Eliminación de celular (NULL) y neutralización de credenciales ('hash_no_valido').

DROP TABLE IF EXISTS usuario_anon;

CREATE TABLE usuario_anon AS
SELECT
    id,
    'Usuario ' || id                   AS nombre,
    'Apellido ' || id                  AS apellido,
    'usuario' || id || '@ejemplo.test' AS mail,
    NULL::VARCHAR(30)                  AS celular,
    'hash_no_valido'                   AS contrasena,
    rol,
    eliminado,
    created_at
FROM usuario;

-- Permisos sobre la tabla anonimizada: acceso para soporte y reportes sin riesgo
GRANT SELECT ON usuario_anon TO rol_soporte, rol_reportes;


-- ============================================================================
-- 4. BATERÍA DE PRUEBAS DE VERIFICACIÓN (Ejecución controlada con ROLLBACK)
-- ============================================================================

-- Test 1: Intento de Inyección de SQL contra fn_autenticar
-- Debe devolver 0 filas (el payload malicioso se trata estrictamente como literal de texto)
SELECT *
FROM fn_autenticar('admin@foodstore.com'' OR ''1''=''1'' --', 'cualquier_clave');

-- Test 2: Autenticación legítima con credencial correcta
SELECT *
FROM fn_autenticar('admin@foodstore.com', 'Admin2026!Segura');

-- Test 3: Demostración de funcionamiento de fn_resetear_password dentro de transacción
BEGIN;

-- Se resetea la contraseña del usuario 2 (Juan Perez)
SELECT fn_resetear_password(2, 'NuevaPasswordSegura2026!');

-- Se prueba la autenticación con la nueva contraseña
SELECT *
FROM fn_autenticar('juan.perez@foodstore.com', 'NuevaPasswordSegura2026!');

-- Se revierte la prueba para preservar el estado original
ROLLBACK;

-- Test 4: Verificación de equivalencia y anonimización
SELECT 'usuario_real' AS tabla, COUNT(*) AS total, COUNT(DISTINCT mail) AS mails_unicos FROM usuario
UNION ALL
SELECT 'usuario_anon' AS tabla, COUNT(*) AS total, COUNT(DISTINCT mail) AS mails_unicos FROM usuario_anon;
