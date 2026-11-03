-- ============================================================================
-- Archivo: db/usuario_anon.sql
-- Proyecto: Food Store - UTN Base de Datos II
-- Unidad 5 · TP7 - Parte D: Dataset Anonimizado y Consultas de Equivalencia
-- ============================================================================
-- Este script construye la tabla usuario_anon y define las dos consultas de
-- agregación analítica (sobre usuario real y usuario_anon) para verificar
-- que la anonimización determinista no distorsiona las métricas agregadas.
-- ============================================================================

SET search_path TO public;

-- ============================================================================
-- 1. CREACIÓN / ACTUALIZACIÓN DE usuario_anon
-- ============================================================================

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

-- Comentario documental del objeto
COMMENT ON TABLE usuario_anon IS 'Tabla anonimizada de forma irreversible bajo la Ley 25.326 para entornos de prueba y análisis con IA.';


-- ============================================================================
-- 2. CONSULTAS AGREGADAS EQUIVALENTES (Verificación de Equivalencia)
-- ============================================================================

-- Consulta A: Agregación sobre la tabla real usuario
-- Métrica: Cantidad de usuarios por rol y por mes de alta (created_at)
SELECT
    'usuario_real' AS origen_datos,
    rol,
    to_char(created_at AT TIME ZONE 'America/Argentina/Buenos_Aires', 'YYYY-MM') AS mes_alta,
    COUNT(*) AS total_usuarios,
    COUNT(DISTINCT mail) AS total_emails_unicos
FROM usuario
GROUP BY
    rol,
    to_char(created_at AT TIME ZONE 'America/Argentina/Buenos_Aires', 'YYYY-MM')
ORDER BY rol, mes_alta;


-- Consulta B: Agregación equivalente sobre la tabla anonimizada usuario_anon
SELECT
    'usuario_anon' AS origen_datos,
    rol,
    to_char(created_at AT TIME ZONE 'America/Argentina/Buenos_Aires', 'YYYY-MM') AS mes_alta,
    COUNT(*) AS total_usuarios,
    COUNT(DISTINCT mail) AS total_emails_unicos
FROM usuario_anon
GROUP BY
    rol,
    to_char(created_at AT TIME ZONE 'America/Argentina/Buenos_Aires', 'YYYY-MM')
ORDER BY rol, mes_alta;
