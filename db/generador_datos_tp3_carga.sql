-- ============================================================================
-- Trabajo Práctico 3 - Base de Datos 2 (Food Store)
-- Script de Generación Masiva de Datos para Copia de Trabajo (bd2_tp3)
-- Archivo: db/generador_datos_tp3_carga.sql
-- ============================================================================
-- NOTA: Este script está preparado para ejecutarse dentro de un bloque
-- transaccional (BEGIN ... COMMIT).
-- NO realiza operaciones DDL ni modifica la estructura de las tablas.
--
-- ESTADO INICIAL QUE CREA ESTE SCRIPT (bloque 0, 1 registro por tabla principal):
--  - 1 categoría (id_categoria = 3, 'Bebidas')
--  - 1 cliente
--  - 1 producto
--  - 1 pedido
--  - 1 detalle
--
-- REQUISITOS DE ESTADO:
--  - Base recién creada con schema.sql, o
--  - base que contenga exactamente el estado inicial anterior.
--  - Si detecta filas adicionales o un estado incompatible, aborta.
--
-- REGISTROS A INSERTAR (cantidades exactas faltantes):
--  - 19.999 clientes        -> Total resultante:  20.000 clientes
--  - 49.999 productos       -> Total resultante:  50.000 productos
--  - 199.999 pedidos        -> Total resultante: 200.000 pedidos
--  - 199.999 detalles       -> Total resultante: 200.000 detalles
--
-- La carga masiva completa no es reejecutable después de completada.
-- El script termina en COMMIT. Las aserciones finales abortan la carga si
-- los conteos o las validaciones 4.1-4.8 no se cumplen.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 0. Estado inicial mínimo y validación de compatibilidad
-- ============================================================================
-- Crea el estado que la carga masiva asume:
-- 1 categoría (id_categoria=3, 'Bebidas'), 1 cliente, 1 producto,
-- 1 pedido y 1 detalle.
--
-- Es válido sobre una base recién creada con schema.sql o sobre una base
-- que ya contenga exactamente ese estado inicial.
-- Si detecta filas adicionales o un estado distinto, aborta la transacción.
-- No hace reejecutable la carga masiva completa.
-- ============================================================================

DO $$
DECLARE
    v_cat_id3_nombre    text;
    v_cat_bebidas_id    bigint;
    v_seq               regclass;
    v_seq_last_value    bigint;
    v_seq_is_called     boolean;
    v_max_categoria_id  bigint;

    v_cliente_id        bigint;
    v_producto_id       bigint;
    v_pedido_id         bigint;
    v_pedidos_cliente   bigint;
    v_detalles_pedido   bigint;
BEGIN
    -- 1. Categoría inicial: exactamente id_categoria=3, 'Bebidas'.
    SELECT nombre INTO v_cat_id3_nombre
    FROM categoria
    WHERE id_categoria = 3;

    SELECT id_categoria INTO v_cat_bebidas_id
    FROM categoria
    WHERE nombre = 'Bebidas';

    IF v_cat_id3_nombre IS NOT NULL AND v_cat_id3_nombre <> 'Bebidas' THEN
        RAISE EXCEPTION
            'Estado incompatible: categoria id_categoria=3 existe con nombre "%"; se esperaba "Bebidas".',
            v_cat_id3_nombre;
    END IF;

    IF v_cat_bebidas_id IS NOT NULL AND v_cat_bebidas_id <> 3 THEN
        RAISE EXCEPTION
            'Estado incompatible: categoria "Bebidas" existe con id_categoria=%; el generador requiere id_categoria=3.',
            v_cat_bebidas_id;
    END IF;

    IF v_cat_id3_nombre IS NULL THEN
        IF EXISTS (SELECT 1 FROM categoria) THEN
            RAISE EXCEPTION
                'Estado incompatible: categoria contiene filas pero no id_categoria=3.';
        END IF;

        INSERT INTO categoria (id_categoria, nombre, activa)
        OVERRIDING SYSTEM VALUE
        VALUES (3, 'Bebidas', TRUE);
    END IF;

    IF EXISTS (SELECT 1 FROM categoria WHERE id_categoria <> 3) THEN
        RAISE EXCEPTION
            'Estado incompatible: categoria contiene IDs distintos de 3.';
    END IF;

    -- 2. Sincronizar la secuencia de identidad sin retrocederla.
    v_seq := pg_get_serial_sequence('categoria', 'id_categoria')::regclass;

    IF v_seq IS NULL THEN
        RAISE EXCEPTION
            'No se encontró la secuencia de identidad de categoria.id_categoria.';
    END IF;

    EXECUTE format('SELECT last_value, is_called FROM %s', v_seq)
        INTO v_seq_last_value, v_seq_is_called;

    SELECT COALESCE(MAX(id_categoria), 0)
        INTO v_max_categoria_id
    FROM categoria;

    IF v_max_categoria_id > v_seq_last_value
       OR (NOT v_seq_is_called AND v_max_categoria_id >= v_seq_last_value) THEN
        PERFORM setval(
            v_seq,
            GREATEST(v_max_categoria_id, v_seq_last_value),
            TRUE
        );
    END IF;

    -- 3. Cliente inicial.
    SELECT id_cliente INTO v_cliente_id
    FROM cliente
    WHERE email = 'cliente.inicial@foodstore.local';

    IF v_cliente_id IS NULL THEN
        IF EXISTS (SELECT 1 FROM cliente) THEN
            RAISE EXCEPTION
                'Estado incompatible: cliente contiene filas pero no el cliente inicial esperado.';
        END IF;

        INSERT INTO cliente (nombre, apellido, email)
        VALUES ('Cliente', 'Inicial', 'cliente.inicial@foodstore.local')
        RETURNING id_cliente INTO v_cliente_id;
    END IF;

    -- 4. Producto inicial.
    SELECT id_producto INTO v_producto_id
    FROM producto
    WHERE categoria_id = 3
      AND nombre = 'Producto Inicial';

    IF v_producto_id IS NULL THEN
        IF EXISTS (SELECT 1 FROM producto) THEN
            RAISE EXCEPTION
                'Estado incompatible: producto contiene filas pero no el producto inicial esperado.';
        END IF;

        INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
        VALUES ('Producto Inicial', 100.00, 10, TRUE, 3)
        RETURNING id_producto INTO v_producto_id;
    END IF;

    -- 5. Pedido y detalle iniciales.
    SELECT COUNT(*) INTO v_pedidos_cliente
    FROM pedido
    WHERE cliente_id = v_cliente_id;

    IF v_pedidos_cliente = 0 THEN
        IF EXISTS (SELECT 1 FROM pedido) THEN
            RAISE EXCEPTION
                'Estado incompatible: pedido contiene filas pero no el pedido inicial esperado.';
        END IF;

        INSERT INTO pedido (cliente_id, forma_pago)
        VALUES (v_cliente_id, 'EFECTIVO'::forma_pago)
        RETURNING id_pedido INTO v_pedido_id;

        INSERT INTO detalle_pedido (
            pedido_id,
            producto_id,
            cantidad,
            precio_unitario
        )
        SELECT
            v_pedido_id,
            p.id_producto,
            1,
            p.precio
        FROM producto p
        WHERE p.id_producto = v_producto_id;

    ELSIF v_pedidos_cliente = 1 THEN
        SELECT id_pedido INTO v_pedido_id
        FROM pedido
        WHERE cliente_id = v_cliente_id
          AND forma_pago = 'EFECTIVO'::forma_pago;

        IF v_pedido_id IS NULL THEN
            RAISE EXCEPTION
                'Estado incompatible: el único pedido del cliente inicial no es EFECTIVO.';
        END IF;

        SELECT COUNT(*) INTO v_detalles_pedido
        FROM detalle_pedido
        WHERE pedido_id = v_pedido_id;

        IF v_detalles_pedido <> 1 OR NOT EXISTS (
            SELECT 1
            FROM detalle_pedido
            WHERE pedido_id = v_pedido_id
              AND producto_id = v_producto_id
              AND cantidad = 1
        ) THEN
            RAISE EXCEPTION
                'Estado incompatible: el pedido inicial (id_pedido=%) no tiene exactamente un detalle del producto inicial con cantidad 1.',
                v_pedido_id;
        END IF;

    ELSE
        RAISE EXCEPTION
            'Estado incompatible: el cliente inicial tiene % pedidos; se esperaba 0 o 1.',
            v_pedidos_cliente;
    END IF;

    -- 6. Antes de la carga masiva: exactamente 1 fila inicial por tabla.
    IF (SELECT COUNT(*) FROM categoria) <> 1
       OR (SELECT COUNT(*) FROM cliente) <> 1
       OR (SELECT COUNT(*) FROM producto) <> 1
       OR (SELECT COUNT(*) FROM pedido) <> 1
       OR (SELECT COUNT(*) FROM detalle_pedido) <> 1 THEN
        RAISE EXCEPTION
            'Estado incompatible: antes de la carga masiva se esperaba exactamente 1 fila en categoria, cliente, producto, pedido y detalle_pedido.';
    END IF;
END $$;

-- ============================================================================
-- 1. Inserción de Clientes (19.999 registros nuevos)
-- ============================================================================
-- Se generan emails con dominio interno exclusivo '@tp3-carga.foodstore.internal'
-- y un hash unívoco por iterador.
-- Prevención explícita de colisión mediante cláusula WHERE NOT EXISTS contra la
-- tabla cliente para descartar cualquier email preexistente.
-- id_cliente se genera automáticamente por PostgreSQL (GENERATED ALWAYS AS IDENTITY).
-- ============================================================================

INSERT INTO cliente (nombre, apellido, email, created_at)
SELECT
    (ARRAY['Juan', 'María', 'Carlos', 'Ana', 'Pedro', 'Lucía', 'Diego', 'Sofía', 'Martín', 'Laura',
           'Federico', 'Valentina', 'Gonzalo', 'Camila', 'Joaquín', 'Florencia', 'Mateo', 'Julieta', 'Lucas', 'Agustina'])[(i % 20) + 1] AS nombre,
    (ARRAY['Gómez', 'Rodríguez', 'Pérez', 'González', 'Fernández', 'López', 'Martínez', 'Díaz', 'Romero', 'Álvarez',
           'Torres', 'Ruiz', 'Ramírez', 'Flores', 'Benítez', 'Acosta', 'Medina', 'Herrera', 'Suárez', 'Castro'])[(i % 20) + 1] AS apellido,
    'cliente_tp3_' || i || '_' || md5(i::text || 'tp3_seed') || '@tp3-carga.foodstore.internal' AS email,
    now() - ((i % 730) || ' days')::INTERVAL - ((i % 86400) || ' seconds')::INTERVAL AS created_at
FROM generate_series(1, 19999) AS g(i)
WHERE NOT EXISTS (
    SELECT 1
    FROM cliente c_exist
    WHERE c_exist.email = 'cliente_tp3_' || i || '_' || md5(i::text || 'tp3_seed') || '@tp3-carga.foodstore.internal'
);

-- ============================================================================
-- 2. Inserción de Productos (49.999 registros nuevos)
-- ============================================================================
-- Todos los productos nuevos utilizan la categoría existente id_categoria = 3 ('Bebidas').
-- Nombres únicos garantizados por 'Producto Bebida TP3 #' || i dentro de categoria_id = 3.
-- Precios y stock estrictamente no negativos (cumpliendo CHECKs).
-- id_producto se genera automáticamente por PostgreSQL.
-- ============================================================================

INSERT INTO producto (nombre, precio, stock, activo, categoria_id, created_at)
SELECT
    'Producto Bebida TP3 #' || i AS nombre,
    (50.00 + ((i * 17) % 15000) * 0.50)::NUMERIC(12,2) AS precio,
    ((i * 13) % 500)::INTEGER AS stock,
    (i % 15 <> 0) AS activo,
    3 AS categoria_id,
    now() - ((i % 730) || ' days')::INTERVAL - ((i % 86400) || ' seconds')::INTERVAL AS created_at
FROM generate_series(1, 49999) AS g(i);

-- ============================================================================
-- 3. Inserción de Pedidos y Detalles de Pedido (199.999 pedidos + 199.999 detalles)
-- ============================================================================
-- Se utiliza un CTE con INSERT ... RETURNING id_pedido para capturar los IDs reales
-- generados por PostgreSQL para los 199.999 pedidos nuevos.
--
-- Los clientes se asignan consultando todos los clientes reales existentes (incluyendo
-- los recién insertados) mediante ROW_NUMBER(), asegurando integridad referencial
-- sin asumir IDs correlativos o iniciales.
--
-- De igual manera, para los detalles se consultan los productos reales disponibles,
-- asignando a cada pedido exactamente un detalle con precio unitario válido y cantidad > 0.
--
-- Esto garantiza:
--  - Integridad referencial (FKs válidas hacia cliente, pedido y producto).
--  - Unicidad en PK (pedido_id, producto_id).
--  - Cumplimiento estricto del trigger DEFERRABLE trg_validar_pedido_con_detalle.
-- ============================================================================

WITH clientes_disponibles AS (
    SELECT
        id_cliente,
        ROW_NUMBER() OVER (ORDER BY id_cliente) AS rn,
        COUNT(*) OVER () AS total
    FROM cliente
),
productos_disponibles AS (
    SELECT
        id_producto,
        precio,
        ROW_NUMBER() OVER (ORDER BY id_producto) AS rn,
        COUNT(*) OVER () AS total
    FROM producto
),
nuevos_pedidos AS (
    INSERT INTO pedido (cliente_id, fecha_pedido, forma_pago)
    SELECT
        c.id_cliente,
        now() - ((g.i % 365) || ' days')::INTERVAL - ((g.i % 86400) || ' seconds')::INTERVAL AS fecha_pedido,
        (ARRAY['EFECTIVO'::forma_pago, 'TARJETA'::forma_pago, 'TRANSFERENCIA'::forma_pago])[(g.i % 3) + 1] AS forma_pago
    FROM generate_series(1, 199999) AS g(i)
    JOIN clientes_disponibles c
        ON c.rn = ((g.i - 1) % c.total) + 1
    RETURNING id_pedido
),
pedidos_numerados AS (
    SELECT
        id_pedido,
        ROW_NUMBER() OVER (ORDER BY id_pedido) AS rn
    FROM nuevos_pedidos
)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT
    pn.id_pedido,
    pd.id_producto,
    ((pn.rn % 10) + 1)::INTEGER AS cantidad,
    pd.precio AS precio_unitario
FROM pedidos_numerados pn
JOIN productos_disponibles pd
    ON pd.rn = ((pn.rn - 1) % pd.total) + 1;

-- ============================================================================
-- 4. Consultas de Verificación y Validación de Integridad
-- ============================================================================

-- 4.1. Conteo total por tabla (Totales esperados: 1 categoria, 20.000 clientes, 50.000 productos, 200.000 pedidos, 200.000 detalles)
SELECT 'categoria' AS tabla, COUNT(*) AS total_filas, 1 AS total_esperado FROM categoria
UNION ALL
SELECT 'cliente', COUNT(*), 20000 FROM cliente
UNION ALL
SELECT 'producto', COUNT(*), 50000 FROM producto
UNION ALL
SELECT 'pedido', COUNT(*), 200000 FROM pedido
UNION ALL
SELECT 'detalle_pedido', COUNT(*), 200000 FROM detalle_pedido;

-- 4.2. Validación de pedidos huérfanos (pedidos sin detalles)
-- Debe devolver 0 filas
SELECT COUNT(*) AS pedidos_sin_detalle
FROM pedido p
LEFT JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
WHERE dp.pedido_id IS NULL;

-- 4.3. Validación de integridad referencial: Pedidos con cliente inexistente
-- Debe devolver 0 filas
SELECT COUNT(*) AS pedidos_con_cliente_invalido
FROM pedido p
LEFT JOIN cliente c ON p.cliente_id = c.id_cliente
WHERE c.id_cliente IS NULL;

-- 4.4. Validación de integridad referencial: Detalles con producto inexistente
-- Debe devolver 0 filas
SELECT COUNT(*) AS detalles_con_producto_invalido
FROM detalle_pedido dp
LEFT JOIN producto pr ON dp.producto_id = pr.id_producto
WHERE pr.id_producto IS NULL;

-- 4.5. Validación de integridad referencial: Detalles con pedido inexistente
-- Debe devolver 0 filas
SELECT COUNT(*) AS detalles_con_pedido_invalido
FROM detalle_pedido dp
LEFT JOIN pedido p ON dp.pedido_id = p.id_pedido
WHERE p.id_pedido IS NULL;

-- 4.6. Validación de productos con categoría inexistente o distinta de 3
-- Debe devolver 0 filas
SELECT COUNT(*) AS productos_categoria_invalida
FROM producto
WHERE categoria_id <> 3;

-- 4.7. Validación de restricciones CHECK (valores inválidos)
-- Todos los conteos deben ser 0
SELECT
    (SELECT COUNT(*) FROM cliente WHERE length(trim(email)) = 0) AS clientes_email_vacio,
    (SELECT COUNT(*) FROM producto WHERE precio < 0) AS productos_precio_negativo,
    (SELECT COUNT(*) FROM producto WHERE stock < 0) AS productos_stock_negativo,
    (SELECT COUNT(*) FROM detalle_pedido WHERE cantidad <= 0) AS detalles_cantidad_invalida,
    (SELECT COUNT(*) FROM detalle_pedido WHERE precio_unitario < 0) AS detalles_precio_negativo;

-- 4.8. Validación de duplicados en detalle_pedido (pedido_id, producto_id)
-- Debe devolver 0 filas
SELECT pedido_id, producto_id, COUNT(*) AS duplicados
FROM detalle_pedido
GROUP BY pedido_id, producto_id
HAVING COUNT(*) > 1;

-- ============================================================================
-- 5. Aserciones finales (después de 4.1-4.8, antes de COMMIT)
-- ============================================================================
-- Si alguna aserción falla, la transacción se aborta y se revierten las filas
-- de la carga. Las secuencias de identidad no son transaccionales y no se
-- reinician automáticamente.
-- ============================================================================

DO $$
DECLARE
    v_categoria                    bigint;
    v_cliente                      bigint;
    v_producto                     bigint;
    v_pedido                       bigint;
    v_detalle                      bigint;
    v_pedidos_sin_detalle          bigint;
    v_pedidos_cliente_invalido     bigint;
    v_detalles_producto_invalido   bigint;
    v_detalles_pedido_invalido     bigint;
    v_productos_categoria_invalida bigint;
    v_clientes_email_vacio         bigint;
    v_productos_precio_negativo    bigint;
    v_productos_stock_negativo     bigint;
    v_detalles_cantidad_invalida   bigint;
    v_detalles_precio_negativo     bigint;
    v_detalles_duplicados          bigint;
BEGIN
    SELECT COUNT(*) INTO v_categoria FROM categoria;
    SELECT COUNT(*) INTO v_cliente FROM cliente;
    SELECT COUNT(*) INTO v_producto FROM producto;
    SELECT COUNT(*) INTO v_pedido FROM pedido;
    SELECT COUNT(*) INTO v_detalle FROM detalle_pedido;

    IF v_categoria <> 1
       OR v_cliente <> 20000
       OR v_producto <> 50000
       OR v_pedido <> 200000
       OR v_detalle <> 200000 THEN
        RAISE EXCEPTION
            'Conteos finales inesperados: categoria=%, cliente=%, producto=%, pedido=%, detalle_pedido=%; se esperaba 1/20000/50000/200000/200000.',
            v_categoria, v_cliente, v_producto, v_pedido, v_detalle;
    END IF;

    SELECT COUNT(*) INTO v_pedidos_sin_detalle
    FROM pedido p
    LEFT JOIN detalle_pedido dp ON dp.pedido_id = p.id_pedido
    WHERE dp.pedido_id IS NULL;

    IF v_pedidos_sin_detalle <> 0 THEN
        RAISE EXCEPTION
            'Validación 4.2: existen % pedidos sin detalle.',
            v_pedidos_sin_detalle;
    END IF;

    SELECT COUNT(*) INTO v_pedidos_cliente_invalido
    FROM pedido p
    LEFT JOIN cliente c ON c.id_cliente = p.cliente_id
    WHERE c.id_cliente IS NULL;

    IF v_pedidos_cliente_invalido <> 0 THEN
        RAISE EXCEPTION
            'Validación 4.3: existen % pedidos con cliente inexistente.',
            v_pedidos_cliente_invalido;
    END IF;

    SELECT COUNT(*) INTO v_detalles_producto_invalido
    FROM detalle_pedido dp
    LEFT JOIN producto pr ON pr.id_producto = dp.producto_id
    WHERE pr.id_producto IS NULL;

    IF v_detalles_producto_invalido <> 0 THEN
        RAISE EXCEPTION
            'Validación 4.4: existen % detalles con producto inexistente.',
            v_detalles_producto_invalido;
    END IF;

    SELECT COUNT(*) INTO v_detalles_pedido_invalido
    FROM detalle_pedido dp
    LEFT JOIN pedido p ON p.id_pedido = dp.pedido_id
    WHERE p.id_pedido IS NULL;

    IF v_detalles_pedido_invalido <> 0 THEN
        RAISE EXCEPTION
            'Validación 4.5: existen % detalles con pedido inexistente.',
            v_detalles_pedido_invalido;
    END IF;

    SELECT COUNT(*) INTO v_productos_categoria_invalida
    FROM producto
    WHERE categoria_id <> 3;

    IF v_productos_categoria_invalida <> 0 THEN
        RAISE EXCEPTION
            'Validación 4.6: existen % productos con categoria distinta de 3.',
            v_productos_categoria_invalida;
    END IF;

    SELECT COUNT(*) INTO v_clientes_email_vacio
    FROM cliente
    WHERE length(trim(email)) = 0;

    SELECT COUNT(*) INTO v_productos_precio_negativo
    FROM producto
    WHERE precio < 0;

    SELECT COUNT(*) INTO v_productos_stock_negativo
    FROM producto
    WHERE stock < 0;

    SELECT COUNT(*) INTO v_detalles_cantidad_invalida
    FROM detalle_pedido
    WHERE cantidad <= 0;

    SELECT COUNT(*) INTO v_detalles_precio_negativo
    FROM detalle_pedido
    WHERE precio_unitario < 0;

    IF v_clientes_email_vacio <> 0
       OR v_productos_precio_negativo <> 0
       OR v_productos_stock_negativo <> 0
       OR v_detalles_cantidad_invalida <> 0
       OR v_detalles_precio_negativo <> 0 THEN
        RAISE EXCEPTION
            'Validación 4.7: CHECKs inválidos: email_vacio=%, precio_negativo=%, stock_negativo=%, cantidad_invalida=%, precio_detalle_negativo=%.',
            v_clientes_email_vacio,
            v_productos_precio_negativo,
            v_productos_stock_negativo,
            v_detalles_cantidad_invalida,
            v_detalles_precio_negativo;
    END IF;

    SELECT COUNT(*) INTO v_detalles_duplicados
    FROM (
        SELECT pedido_id, producto_id
        FROM detalle_pedido
        GROUP BY pedido_id, producto_id
        HAVING COUNT(*) > 1
    ) d;

    IF v_detalles_duplicados <> 0 THEN
        RAISE EXCEPTION
            'Validación 4.8: existen % combinaciones (pedido_id, producto_id) duplicadas.',
            v_detalles_duplicados;
    END IF;
END $$;

-- ============================================================================
-- FIN DEL SCRIPT
-- Carga productiva: termina en COMMIT.
-- Las aserciones finales abortan la transacción si fallan.
-- ============================================================================
COMMIT;
