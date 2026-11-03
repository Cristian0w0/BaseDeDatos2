-- ==============================================================================
-- health_check.sql
-- Unidad 6: Mantenimiento, Respaldo y Recuperación — Food Store
-- PostgreSQL 16+ / Base de Datos: foodstore
-- ==============================================================================
-- Monitoreo preventivo del estado del cluster y la base de datos de producción.
-- Incluye 4 dimensiones fundamentales:
-- 1. Espacio y almacenamiento (Base de datos y objetos principales).
-- 2. Actividad de transacciones y conexiones activas.
-- 3. Estado de tuplas vivas/muertas y frescura de autovacuum/analyze.
-- 4. Consultas activas de larga duración o potencialmente bloqueantes.
-- ==============================================================================

\echo '===================================================================='
\echo ' [CONTROL 1] TAMAÑO TOTAL DE LA BASE DE DATOS Y OBJETOS PRINCIPALES'
\echo '===================================================================='

SELECT 
    current_database() AS base_datos,
    pg_size_pretty(pg_database_size(current_database())) AS tamano_total;

-- Detalle de espacio por tabla e índices
SELECT 
    relname AS tabla,
    pg_size_pretty(pg_total_relation_size(relid)) AS tamano_total,
    pg_size_pretty(pg_relation_size(relid)) AS tamano_tabla,
    pg_size_pretty(pg_indexes_size(relid)) AS tamano_indices
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;

\echo '===================================================================='
\echo ' [CONTROL 2] ACTIVIDAD DE CONEXIONES Y TRANSACCIONES'
\echo '===================================================================='

SELECT 
    datname AS base_datos,
    numbackends AS conexiones_activas,
    xact_commit AS transacciones_commit,
    xact_rollback AS transacciones_rollback,
    CASE 
        WHEN (xact_commit + xact_rollback) = 0 THEN 0.0
        ELSE ROUND(100.0 * xact_rollback / (xact_commit + xact_rollback), 2)
    END AS pct_rollback,
    blks_read AS bloques_leidos_disco,
    blks_hit AS bloques_leidos_cache,
    ROUND(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_ratio_pct
FROM pg_stat_database
WHERE datname = current_database();

\echo '===================================================================='
\echo ' [CONTROL 3] ESTADO DE TABLAS, TUPLAS MUERTAS Y AUTOVACUUM'
\echo '===================================================================='

SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    CASE 
        WHEN (n_live_tup + n_dead_tup) = 0 THEN 0.0
        ELSE ROUND(100.0 * n_dead_tup / (n_live_tup + n_dead_tup), 2)
    END AS pct_tuplas_muertas,
    COALESCE(to_char(last_vacuum, 'YYYY-MM-DD HH24:MI:SS'), 'Nunca') AS ultimo_vacuum,
    COALESCE(to_char(last_autovacuum, 'YYYY-MM-DD HH24:MI:SS'), 'Nunca') AS ultimo_autovacuum,
    COALESCE(to_char(last_analyze, 'YYYY-MM-DD HH24:MI:SS'), 'Nunca') AS ultimo_analyze,
    COALESCE(to_char(last_autoanalyze, 'YYYY-MM-DD HH24:MI:SS'), 'Nunca') AS ultimo_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

\echo '===================================================================='
\echo ' [CONTROL 4] CONSULTAS ACTIVAS DE LARGA DURACIÓN (NO IDLE)'
\echo '===================================================================='

SELECT 
    pid,
    usename AS usuario,
    client_addr AS ip_cliente,
    state AS estado,
    clock_timestamp() - query_start AS duracion_consulta,
    wait_event_type,
    wait_event,
    LEFT(query, 120) AS consulta_truncada
FROM pg_stat_activity
WHERE datname = current_database()
  AND state <> 'idle'
  AND pid <> pg_backend_pid()
ORDER BY query_start ASC;
