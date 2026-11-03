-- ============================================================================
-- Archivo: db/tp7_clase1_auditoria_servidor.sql
-- Proyecto: Food Store - UTN Base de Datos II
-- Unidad 5 · Clase 1: Configuración de Auditoría Nativa y Verificación de Catálogo
-- ============================================================================

-- ============================================================================
-- 1. CONSULTA DE PARÁMETROS ACTUALES DE AUDITORÍA
-- ============================================================================

SHOW log_statement;
SHOW log_connections;
SHOW log_disconnections;


-- ============================================================================
-- 2. ACTIVACIÓN DE POLÍTICA DE AUDITORÍA BÁSICA EN EL MOTOR
-- ============================================================================
-- Se registran conexiones, desconexiones y todas las sentencias de modificación (mod: DDL + DML)
-- sin saturar el almacenamiento con lecturas rutinarias (all).

ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_statement = 'mod';

-- Recargar la configuración sin reiniciar el servicio
SELECT pg_reload_conf();


-- ============================================================================
-- 3. INSPECCIÓN DE SESIONES ACTIVAS EN TIEMPO REAL
-- ============================================================================
-- Primer recurso de diagnóstico del DBA ante incidentes o bloqueos

SELECT
    pid,
    usename,
    client_addr,
    application_name,
    state,
    backend_start,
    query_start,
    query
FROM pg_stat_activity
WHERE datname = current_database()
ORDER BY backend_start DESC;


-- ============================================================================
-- 4. VERIFICACIÓN DE ATRIBUTOS ADMINISTRATIVOS EN EL CATÁLOGO (pg_roles)
-- ============================================================================
-- Valida que ningún rol de aplicación ni analítico tenga atributos administrativos excesivos

SELECT
    rolname,
    rolcanlogin,
    rolsuper,
    rolcreaterole,
    rolcreatedb,
    rolconnlimit,
    rolvaliduntil
FROM pg_roles
WHERE rolname IN (
    'rol_app_lectura',
    'rol_app_escritura',
    'rol_soporte',
    'rol_reportes',
    'app_web',
    'admin_datos'
)
ORDER BY rolname;


-- ============================================================================
-- 5. VERIFICACIÓN DE JERARQUÍAS Y MEMBRESÍAS (pg_auth_members)
-- ============================================================================
-- Valida que app_web herede rol_app_lectura y rol_app_escritura

SELECT
    r.rolname AS rol_usuario_login,
    m.rolname AS rol_grupo_heredado,
    am.admin_option
FROM pg_roles r
JOIN pg_auth_members am ON r.oid = am.member
JOIN pg_roles m ON am.roleid = m.oid
WHERE r.rolname IN ('app_web', 'admin_datos')
ORDER BY r.rolname, m.rolname;


-- ============================================================================
-- 6. MATRIZ DE PRIVILEGIOS OTORGADOS SOBRE TABLAS Y VISTAS
-- ============================================================================
-- Comprobación granular contra el principio de mínimo privilegio

SELECT
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN (
    'rol_app_lectura',
    'rol_app_escritura',
    'rol_soporte',
    'rol_reportes',
    'app_web',
    'admin_datos'
  )
ORDER BY table_name, grantee, privilege_type;
