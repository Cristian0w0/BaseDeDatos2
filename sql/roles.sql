-- ============================================================================
-- Archivo: sql/roles.sql
-- Proyecto: Food Store - UTN Base de Datos II
-- Unidad 5 · TP7 - Parte A: Esquema de Roles y Permisos de Mínimo Privilegio
-- ============================================================================

SET search_path TO public;

-- 1. ROLES DE GRUPO (NOLOGIN: definen QUÉ se puede hacer)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_lectura') THEN
        CREATE ROLE rol_app_lectura NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_escritura') THEN
        CREATE ROLE rol_app_escritura NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_soporte') THEN
        CREATE ROLE rol_soporte NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes') THEN
        CREATE ROLE rol_reportes NOLOGIN;
    END IF;
END $$;

-- 2. ACCESO AL ESQUEMA
GRANT USAGE ON SCHEMA public
    TO rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes;

-- 3. PERMISOS GRANULARES DE OBJETOS
-- rol_app_lectura: Catálogo público
GRANT SELECT ON v_productos_vigentes, v_categorias_vigentes
    TO rol_app_lectura;

-- rol_app_escritura: Circuito de compra y checkout
GRANT SELECT, INSERT, UPDATE ON pedido, detalle_pedido
    TO rol_app_escritura;

REVOKE DELETE, TRUNCATE ON pedido, detalle_pedido
    FROM rol_app_escritura;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public
    TO rol_app_escritura;

GRANT EXECUTE ON PROCEDURE sp_crear_pedido(BIGINT, forma_pago, JSONB)
    TO rol_app_escritura;

-- rol_soporte: Mesa de ayuda sin exposición de contraseñas ni teléfonos
GRANT SELECT ON v_usuarios_publico, v_pedidos_resumen
    TO rol_soporte;

-- Proyección restringida por columna sobre tabla usuario
GRANT SELECT (id, nombre, apellido, mail, rol)
    ON usuario
    TO rol_soporte;

-- rol_reportes: Extracción de datos analíticos
GRANT SELECT ON mv_ventas_categoria_mes
    TO rol_reportes;

-- 4. POLÍTICAS DE ROW-LEVEL SECURITY (RLS)
ALTER TABLE pedido ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS aislacion_clientes_pedido ON pedido;

CREATE POLICY aislacion_clientes_pedido ON pedido
    FOR ALL
    TO rol_app_escritura
    USING (cliente_id = current_setting('app.usuario_actual', true)::bigint);

-- 5. ROLES DE LOGIN (definen QUIÉN se conecta)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_web') THEN
        CREATE ROLE app_web WITH LOGIN PASSWORD 'cambiar_en_produccion'
            CONNECTION LIMIT 50
            VALID UNTIL '2027-01-01';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_datos') THEN
        CREATE ROLE admin_datos WITH LOGIN PASSWORD 'cambiar_en_produccion'
            CREATEDB
            CREATEROLE
            NOSUPERUSER;
    END IF;
END $$;

-- 6. ASIGNACIÓN JERÁRQUICA (Membresía)
GRANT rol_app_lectura, rol_app_escritura TO app_web;

-- 7. AUTOMATIZACIÓN DE PERMISOS FUTUROS (ALTER DEFAULT PRIVILEGES)
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_reportes;
