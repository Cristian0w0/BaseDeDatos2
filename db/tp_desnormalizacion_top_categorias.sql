-- ============================================================================
-- TP6 - Base de Datos 2 - Food Store
-- Parte 2 - Desnormalización controlada: Top categorías por día
-- Entregable oficial: db/tp_desnormalizacion_top_categorias.sql
-- ============================================================================
-- Contenido:
--   0. Convención temporal para comparar 5.2(a) y 5.2(d)
--   1. Estructura desnormalizada y costo de creación
--   2. Mecanismo de sincronización y costo de refresco
--   3. Verificaciones previas de objetos (existencia, definición y validez)
--   4. Consulta 5.2(d)
--   5. Auditoría 5.2(e) y alcance de la detección
--   6. Diagnóstico posterior de la vista materializada (opcional)
--
-- Este archivo consolida la estructura y el mecanismo definidos en
-- db/tp6_vista_materializada_ventas.sql, y la auditoría histórica definida en
-- db/tp6_auditoria_ventas.sql. Es la definición canónica de la Parte 2.
-- Para la entrega, este archivo es autosuficiente: no es necesario ejecutar
-- los auxiliares para crear la estructura, la consulta o la auditoría.
--
-- El orden es intencional: la Sección 3 comprueba existencia, definición y
-- validez de los objetos antes de ejecutar la consulta (Sección 4) y la
-- auditoría (Sección 5). Las verificaciones son de solo lectura: no crean,
-- modifican, refrescan ni eliminan datos u objetos.
--
-- No modifica db/schema.sql, los scripts auxiliares ni el informe.
-- No incluye DROP, TRUNCATE ni DELETE.
-- No declara resultados medidos nuevos ni afirma que el entregable esté
-- validado. Las mediciones existentes deben re-ejecutarse si se quiere
-- demostrar la comparación de rendimiento bajo la convención temporal de la
-- Sección 0.
-- ============================================================================

SET search_path TO public;


-- ============================================================================
-- 0. Convención temporal para comparar 5.2(a) y 5.2(d)
-- ============================================================================
-- fecha_pedido es TIMESTAMPTZ (db/schema.sql).
--
-- La consulta original reportada en 5.2(a) filtra:
--   fecha_pedido::date = CURRENT_DATE
--
-- Esa expresión depende del TimeZone de la sesión: tanto el cast de
-- TIMESTAMPTZ a DATE como CURRENT_DATE usan la zona configurada en la sesión.
--
-- La vista materializada y la consulta optimizada usan el día local de
-- America/Argentina/Buenos_Aires de forma explícita:
--   (fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date
--
-- Por lo tanto, no se afirma equivalencia exacta entre ambas consultas si no
-- se fija la zona horaria de la sesión. Para compararlas de forma consistente,
-- ejecutar la consulta original y la consulta 5.2(d) en la misma sesión con la
-- zona de Buenos Aires:
SET TIME ZONE 'America/Argentina/Buenos_Aires';

-- SET TIME ZONE solo afecta esta sesión; no modifica datos ni la configuración
-- global de PostgreSQL. Si la consulta original se ejecuta en otra conexión,
-- aplicar la misma zona en esa conexión antes de comparar.
--
-- Bajo esta configuración, fecha_pedido::date y CURRENT_DATE coinciden con el
-- día local usado por la vista. Si la sesión se deja en otra zona, los
-- resultados pueden diferir cerca de la medianoche y la comparación de tiempos
-- no sería entre consultas equivalentes.
--
-- Alternativa (no aplicada en este archivo): reescribir ambas consultas con la
-- expresión explícita de Buenos Aires. Eso cambia el texto de la consulta
-- original y obliga a repetir EXPLAIN ANALYZE; la medición quedaría pendiente.
--
-- Si la regla de negocio fuera "día local de la sesión/servidor" y no "día
-- local de Buenos Aires", la vista materializada debería usar la misma
-- expresión que la consulta original. Eso también requeriría modificar la MV
-- y repetir las mediciones; no se hace en este archivo.
--
-- Las mediciones de 41,965 ms y 0,039 ms registradas en el informe no fueron
-- revalidadas con esta convención temporal. No se declaran equivalentes ni
-- definitivas en este entregable.
--
-- Para volver a medir manualmente en DBeaver, en la misma sesión:
--   EXPLAIN (ANALYZE, BUFFERS) <consulta original de 5.2(a)>;
--   EXPLAIN (ANALYZE, BUFFERS) <consulta 5.2(d) de la Sección 4>;
-- Registrar versión de PostgreSQL, zona horaria de sesión, estado de la vista
-- materializada y si se ejecutó un refresco antes de la medición.


-- ============================================================================
-- 1. Estructura desnormalizada y costo de creación
-- ============================================================================
-- La vista materializada almacena el total vendido por día local y categoría.
-- Es un dato derivado de pedido, detalle_pedido y producto; las tablas base
-- siguen siendo la fuente de verdad.
--
-- El índice único sobre (fecha, categoria_id) es obligatorio para
-- REFRESH MATERIALIZED VIEW CONCURRENTLY y además refleja la granularidad de
-- la consulta del panel.
--
-- Costo de creación:
--   - CREATE MATERIALIZED VIEW ... WITH DATA recorre pedido, detalle_pedido y
--     producto, agrega por (día local, categoría) y escribe el resultado
--     completo. El costo crece con el volumen histórico y con la cantidad de
--     grupos; consume CPU, I/O y espacio en disco equivalente al resultado
--     materializado más sus índices.
--   - Toma locks ACCESS SHARE sobre las tablas base: no bloquea lecturas, pero
--     compite por I/O y CPU con las consultas concurrentes.
--   - Si la vista ya existe, IF NOT EXISTS no vuelve a calcularla: el costo se
--     reduce a la comprobación de catálogo y la definición existente no se
--     actualiza.
--   - Crear el índice único agrega un recorrido y ordenamiento adicional sobre
--     la vista.
--   - El tiempo de creación no está medido en este archivo.
--
-- Este script no abre una transacción explícita. Si falla la creación del
-- índice, la vista materializada puede quedar creada; revisar los objetos
-- existentes (Sección 3) antes de reintentar.

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_ventas_categoria_dia AS
SELECT
    (p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS fecha,
    pr.categoria_id,
    SUM(dp.cantidad * dp.precio_unitario) AS total_ventas
FROM pedido AS p
JOIN detalle_pedido AS dp
    ON dp.pedido_id = p.id_pedido
JOIN producto AS pr
    ON pr.id_producto = dp.producto_id
GROUP BY
    (p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date,
    pr.categoria_id
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS uq_mv_ventas_categoria_dia_fecha_categoria
    ON mv_ventas_categoria_dia (fecha, categoria_id);

-- Advertencias sobre reejecución:
--   - CREATE MATERIALIZED VIEW IF NOT EXISTS no actualiza la definición de una
--     vista preexistente. Si la vista ya existe con otra definición, este
--     script no la corrige; verificarla con pg_get_viewdef (Sección 3) y
--     recrearla manualmente fuera de este archivo si corresponde.
--   - CREATE UNIQUE INDEX IF NOT EXISTS solo comprueba el nombre. No garantiza
--     que un índice preexistente con ese nombre tenga la definición correcta
--     sobre (fecha, categoria_id). Verificarlo con la Sección 3.


-- ============================================================================
-- 2. Mecanismo de sincronización y costo de refresco
-- ============================================================================
-- La vista se actualiza con REFRESH MATERIALIZED VIEW CONCURRENTLY. Ese modo
-- permite lecturas mientras se refresca, pero exige:
--   1. que la vista esté poblada (ispopulated = true);
--   2. un índice UNIQUE válido sobre (fecha, categoria_id);
--   3. no ejecutarse dentro de un bloque de transacción explícito.
--
-- Refresco habitual (vista poblada y con índice único válido):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_ventas_categoria_dia;
--
-- Refresco normal, solo si la vista está vacía o fue creada WITH NO DATA:
-- REFRESH MATERIALIZED VIEW public.mv_ventas_categoria_dia;
--
-- Después de un refresco normal, verificar que ispopulated = true y que el
-- índice único siga siendo válido antes de volver a usar CONCURRENTLY.
--
-- Costo y límites del refresco:
--   - PostgreSQL no incluye un planificador nativo de refrescos: no hay un
--     scheduler interno equivalente a cron. La frecuencia debe definirse con
--     una herramienta externa (por ejemplo, el Programador de tareas de
--     Windows, cron, o pg_cron si la extensión está instalada) o ejecutarse
--     manualmente.
--   - REFRESH MATERIALIZED VIEW (normal) recalcula toda la vista y toma un lock
--     ACCESS EXCLUSIVE sobre ella: bloquea las lecturas mientras dura.
--   - REFRESH MATERIALIZED VIEW CONCURRENTLY recalcula, compara contra el
--     contenido actual y aplica las diferencias. Permite lecturas, pero hace
--     más trabajo, requiere espacio temporal, no puede ejecutarse dentro de un
--     bloque de transacción explícito y depende del índice único válido.
--   - PostgreSQL estándar no tiene refresco incremental: cada refresco vuelve
--     a agregar todo el histórico. El costo crece con el volumen de pedidos,
--     detalles y productos, y con el tiempo que tarde el agregado.
--   - Mientras no se refresque, la vista queda desactualizada. La demora máxima
--     esperada es el intervalo configurado más la duración del refresco.
--   - El refresco no corrige reatribuciones históricas producidas por cambios
--     en producto.categoria_id: vuelve a calcular con la categoría actual
--     (ver el alcance de la auditoría en la Sección 5).
--
-- Este archivo no programa ni ejecuta el refresco. Entre un refresco y el
-- siguiente, las ventas nuevas o modificadas no se reflejan en la vista: el
-- panel puede mostrar información desactualizada.
--
-- Ejemplo seguro para PowerShell, sin contraseña embebida:
--   $psql = "C:\Program Files\PostgreSQL\<version>\bin\psql.exe"
--   & $psql -h "localhost" -p 5432 -U "<usuario>" -d "bd2_tp6" `
--     -c "REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_ventas_categoria_dia;"
--
-- Configurar la autenticación en %APPDATA%\postgresql\pgpass.conf. No guardar
-- la contraseña en el script ni en variables de entorno persistentes.
--
-- En el Programador de tareas, evitar solapamientos: no iniciar una nueva
-- instancia si la tarea anterior sigue ejecutándose. Si el índice único falta,
-- es inválido o no cubre todas las filas, el refresco concurrente falla; en
-- ese caso revisar la estructura antes de reintentar.


-- ============================================================================
-- 3. Verificaciones previas de objetos (solo lectura)
-- ============================================================================
-- Ejecutar esta sección después de la creación (Sección 1) y antes de la
-- consulta (Sección 4) y la auditoría (Sección 5).
--
-- No se usa DROP ni se recrean objetos: todas las comprobaciones conservan los
-- datos y leen catálogos, la definición actual y la vista materializada.
--
-- 3.1 Existencia y estado de la vista materializada
SELECT
    to_regclass('public.mv_ventas_categoria_dia') IS NOT NULL AS vista_existe,
    COALESCE(
        (SELECT m.ispopulated
           FROM pg_matviews AS m
          WHERE m.schemaname = 'public'
            AND m.matviewname = 'mv_ventas_categoria_dia'),
        false
    ) AS vista_poblada,
    COALESCE(
        (SELECT m.hasindexes
           FROM pg_matviews AS m
          WHERE m.schemaname = 'public'
            AND m.matviewname = 'mv_ventas_categoria_dia'),
        false
    ) AS vista_tiene_indices;

-- 3.2 Definición almacenada de la vista materializada
--
-- Comprobación textual conservadora sobre el texto normalizado de
-- pg_get_viewdef. El patrón exige el SELECT, los alias de salida, el FROM y los
-- dos JOIN con sus predicados, SUM(cantidad * precio_unitario), la fecha local
-- sobre p.fecha_pedido y el GROUP BY exacto (fecha, categoria_id). Rechaza
-- cláusulas adicionales (WHERE, HAVING, LIMIT, DISTINCT, FILTER, UNION, joins
-- extra) y cualquier otra columna de agrupación.
--
-- No es una prueba formal de equivalencia semántica ni garantiza el balance de
-- paréntesis del texto generado: depende del formato de pg_get_viewdef. La
-- normalización contempla espacios, mayúsculas, ::text y el prefijo public.
--
-- Un resultado false no demuestra necesariamente que la definición sea
-- incorrecta: puede ser un falso negativo por el formato que genera
-- PostgreSQL. Si definicion_estructural_valida es false, primero inspeccionar
-- definicion_actual y compararla con la definición canónica de la Sección 1
-- antes de modificar este patrón. Mientras no se aclare, no ejecutar la
-- consulta ni la auditoría. Mantener esta documentación sincronizada con 3.4.
WITH def AS (
    SELECT CASE
               WHEN to_regclass('public.mv_ventas_categoria_dia') IS NULL THEN NULL
               ELSE pg_get_viewdef(
                        to_regclass('public.mv_ventas_categoria_dia'),
                        false
                    )
           END AS definicion_actual
),
norm AS (
    SELECT
        definicion_actual,
        btrim(
            lower(
                regexp_replace(
                    regexp_replace(COALESCE(definicion_actual, ''), '\s+', ' ', 'g'),
                    'public\.',
                    '',
                    'g'
                )
            )
        ) AS d
    FROM def
)
SELECT
    definicion_actual,
    (definicion_actual IS NOT NULL) AS definicion_disponible,
    (
        d ~ (
            '^select\s+\(\(p\.fecha_pedido\s+at time zone\s+''america/argentina/buenos_aires''::text\)\)::date\s+as\s+fecha,\s+' ||
            'pr\.categoria_id,\s+sum\(\(\(dp\.cantidad\)::numeric\s*\*\s*dp\.precio_unitario\)\)\s+as\s+total_ventas\s+' ||
            'from\s+\(\(pedido\s+p\s+join\s+detalle_pedido\s+dp\s+on\s+\(\(dp\.pedido_id\s*=\s*p\.id_pedido\)\)\)\s+' ||
            'join\s+producto\s+pr\s+on\s+\(\(pr\.id_producto\s*=\s*dp\.producto_id\)\)\)\s+' ||
            'group by\s+\(\(\(p\.fecha_pedido\s+at time zone\s+''america/argentina/buenos_aires''::text\)\)::date\),\s+' ||
            'pr\.categoria_id\s*;?$'
        )
    ) AS definicion_estructural_valida
FROM norm;

-- 3.3 Índices de la vista materializada y validez del índice único
--
-- Se listan todos los índices de la vista. Un índice es apto para
-- REFRESH ... CONCURRENTLY si es UNIQUE, válido, está listo, no tiene
-- predicado ni expresiones y cubre exactamente (fecha, categoria_id).
-- El nombre esperado del índice es uq_mv_ventas_categoria_dia_fecha_categoria;
-- si el índice apto tiene otro nombre, el refresco concurrente puede funcionar,
-- pero la diferencia debe quedar documentada.
SELECT
    c.relname AS indice,
    (c.relname = 'uq_mv_ventas_categoria_dia_fecha_categoria') AS es_indice_esperado,
    i.indisunique,
    i.indisvalid,
    i.indisready,
    (i.indpred IS NULL) AS sin_predicado,
    (i.indexprs IS NULL) AS sin_expresiones,
    i.indnkeyatts AS columnas_clave_cantidad,
    (
        SELECT array_agg(pg_get_indexdef(i.indexrelid, k, true) ORDER BY k)
        FROM generate_series(1, i.indnkeyatts) AS k
    ) AS columnas_clave,
    pg_get_indexdef(i.indexrelid) AS definicion_indice,
    (
        i.indisunique
        AND i.indisvalid
        AND i.indisready
        AND i.indpred IS NULL
        AND i.indexprs IS NULL
        AND i.indnkeyatts = 2
        AND (
            SELECT array_agg(pg_get_indexdef(i.indexrelid, k, true) ORDER BY k)
            FROM generate_series(1, i.indnkeyatts) AS k
        ) = ARRAY['fecha', 'categoria_id']::text[]
    ) AS apto_para_concurrente
FROM pg_index AS i
JOIN pg_class AS c
    ON c.oid = i.indexrelid
WHERE i.indrelid = to_regclass('public.mv_ventas_categoria_dia')
ORDER BY c.relname;

-- 3.4 Barrera automática de prerrequisitos
--
-- Este bloque DO es de solo lectura y no modifica datos ni objetos. Si la
-- vista no existe, no está poblada, la definición no coincide con la
-- estructura esperada o no hay un índice único válido sobre (fecha,
-- categoria_id), emite una excepción. Si el cliente detiene el script ante el
-- error, la consulta y la auditoría no se ejecutan.
--
-- La comprobación de definición es textual y conservadora: depende del formato
-- de pg_get_viewdef y no garantiza balance de paréntesis ni equivalencia
-- semántica. Un error no demuestra necesariamente que la definición sea
-- incorrecta; puede ser un falso negativo por el formato generado por
-- PostgreSQL. Ante un fallo, inspeccionar la definición actual (definicion_actual
-- en 3.2) y compararla con la definición canónica de la Sección 1 antes de
-- modificar el patrón. Mantener esta documentación sincronizada con 3.2.
--
-- Compatibilidad con el flujo del archivo y con la ejecución por secciones:
--   - RAISE EXCEPTION aborta la sentencia DO, pero no garantiza por sí solo
--     que el cliente deje de enviar las sentencias siguientes.
--   - En psql -f, por defecto se continúa tras el error. Para detener el
--     script: psql -v ON_ERROR_STOP=1 -f db/tp_desnormalizacion_top_categorias.sql
--   - En psql -c con varias sentencias, el error aborta el comando completo.
--   - En DBeaver "Execute script", la detención depende de la opción de
--     detenerse en error; verificar que esté activa. "Execute statement"
--     (Ctrl+Enter) ejecuta solo la sentencia seleccionada.
--   - Dentro de una transacción explícita, el error deja la transacción
--     abortada y las sentencias posteriores fallan hasta ROLLBACK. Este
--     archivo no abre una transacción explícita.
--   - El bloque es idempotente y puede ejecutarse las veces necesarias. No
--     reemplaza la revisión visual de 3.1 a 3.3. Un falso negativo solo
--     bloquea el análisis y se resuelve revisando la definición impresa, sin
--     tocar los datos.
DO $$
DECLARE
    v_definicion text;
    v_poblada boolean;
    v_indice_apto boolean;
BEGIN
    IF to_regclass('public.mv_ventas_categoria_dia') IS NULL THEN
        RAISE EXCEPTION
            'Verificación previa fallida: no existe la vista materializada public.mv_ventas_categoria_dia.';
    END IF;

    SELECT m.ispopulated
      INTO v_poblada
      FROM pg_matviews AS m
     WHERE m.schemaname = 'public'
       AND m.matviewname = 'mv_ventas_categoria_dia';

    IF v_poblada IS DISTINCT FROM true THEN
        RAISE EXCEPTION
            'Verificación previa fallida: la vista materializada no está poblada (ispopulated <> true). Ejecutar REFRESH MATERIALIZED VIEW sin CONCURRENTLY antes de continuar.';
    END IF;

    SELECT btrim(
               lower(
                   regexp_replace(
                       regexp_replace(
                           pg_get_viewdef(
                               to_regclass('public.mv_ventas_categoria_dia'),
                               false
                           ),
                           '\s+',
                           ' ',
                           'g'
                       ),
                       'public\.',
                       '',
                       'g'
                   )
               )
           )
      INTO v_definicion;

    IF v_definicion IS NULL
       OR v_definicion !~ (
            '^select\s+\(\(p\.fecha_pedido\s+at time zone\s+''america/argentina/buenos_aires''::text\)\)::date\s+as\s+fecha,\s+' ||
            'pr\.categoria_id,\s+sum\(\(\(dp\.cantidad\)::numeric\s*\*\s*dp\.precio_unitario\)\)\s+as\s+total_ventas\s+' ||
            'from\s+\(\(pedido\s+p\s+join\s+detalle_pedido\s+dp\s+on\s+\(\(dp\.pedido_id\s*=\s*p\.id_pedido\)\)\)\s+' ||
            'join\s+producto\s+pr\s+on\s+\(\(pr\.id_producto\s*=\s*dp\.producto_id\)\)\)\s+' ||
            'group by\s+\(\(\(p\.fecha_pedido\s+at time zone\s+''america/argentina/buenos_aires''::text\)\)::date\),\s+' ||
            'pr\.categoria_id\s*;?$'
       )
    THEN
        RAISE EXCEPTION
            'Verificación previa fallida: la definición actual de la vista no coincide con la estructura esperada. Revisar 3.2 antes de continuar. Definición actual: %',
            v_definicion;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM pg_index AS i
        WHERE i.indrelid = to_regclass('public.mv_ventas_categoria_dia')
          AND i.indisunique
          AND i.indisvalid
          AND i.indisready
          AND i.indpred IS NULL
          AND i.indexprs IS NULL
          AND i.indnkeyatts = 2
          AND (
              SELECT array_agg(pg_get_indexdef(i.indexrelid, k, true) ORDER BY k)
              FROM generate_series(1, i.indnkeyatts) AS k
          ) = ARRAY['fecha', 'categoria_id']::text[]
    )
    INTO v_indice_apto;

    IF NOT v_indice_apto THEN
        RAISE EXCEPTION
            'Verificación previa fallida: no existe un índice UNIQUE válido sobre (fecha, categoria_id) en la vista materializada. Revisar 3.3.';
    END IF;
END
$$;


-- ============================================================================
-- 4. Consulta 5.2(d) - Top 5 de categorías del día local
-- ============================================================================
-- Usa la misma fecha local que la vista materializada. No se afirma que sea
-- equivalente a la consulta original con CURRENT_DATE fuera de la convención
-- de sesión explicada en la Sección 0.
--
-- Ejecutar después de la Sección 3.

SELECT
    c.nombre AS categoria,
    mv.total_ventas
FROM mv_ventas_categoria_dia AS mv
JOIN categoria AS c
    ON c.id_categoria = mv.categoria_id
WHERE mv.fecha = (CURRENT_TIMESTAMP AT TIME ZONE 'America/Argentina/Buenos_Aires')::date
ORDER BY mv.total_ventas DESC, c.nombre
LIMIT 5;

-- Para medir esta consulta, anteponer:
--   EXPLAIN (ANALYZE, BUFFERS)
-- y ejecutarla en la misma sesión usada para la consulta original de 5.2(a).


-- ============================================================================
-- 5. Auditoría 5.2(e) - Sincronización histórica de la vista materializada
-- ============================================================================
-- La auditoría es de solo lectura: no crea, modifica ni refresca objetos ni
-- datos. Recalcula los totales desde las tablas base con la misma expresión de
-- fecha que la vista y compara todo el histórico mediante FULL OUTER JOIN.
--
-- Un resultado vacío indica que la vista coincide con las tablas base bajo la
-- definición de fecha de la vista. No demuestra equivalencia con la consulta
-- original basada en CURRENT_DATE si la sesión no está en la zona de Buenos
-- Aires; esa diferencia se documenta en la Sección 0.
--
-- La auditoría recorre todo el histórico y puede ser costosa. Si se ejecutó un
-- refresco recientemente y no hubo cambios posteriores, se espera 0 filas.
--
-- La consulta principal es una sola sentencia: las lecturas de las tablas base
-- y de la vista materializada usan el mismo snapshot de PostgreSQL. Esto evita
-- mezclar dos estados distintos dentro de la propia auditoría.
--
-- Alcance de la detección:
--   La auditoría compara el estado actual de las tablas base con el estado
--   actual de la vista materializada. No reconstruye la historia. Si cambia
--   producto.categoria_id, el recálculo desde las tablas base imputa todas las
--   ventas históricas de ese producto a la categoría actual, mientras que la
--   vista puede conservar la categoría de la última materialización. Un
--   refresco posterior haría coincidir ambos lados, pero reatribuyendo ventas
--   pasadas sin dejar rastro. Por eso la auditoría no detecta por sí sola las
--   reatribuciones históricas causadas por cambios en producto.categoria_id:
--   solo detecta diferencias entre el estado actual de la base y el estado
--   actual de la vista. Para auditarlas haría falta conservar la categoría
--   vigente al momento de la venta (tabla histórica o trigger), fuera del
--   alcance de este entregable.
--
-- 5.1 Auditoría principal: faltantes, sobrantes y diferencias de importe
--
-- Casos detectados:
--   FALTA_EN_VISTA   -> combinación (fecha, categoria_id) presente en las
--                       tablas base pero ausente en la vista.
--   SOBRA_EN_VISTA   -> combinación presente en la vista pero sin respaldo
--                       actual en las tablas base.
--   IMPORTE_DISTINTO -> la combinación existe en ambos lados, pero el total
--                       no coincide.
--
-- Si la vista está desactualizada por ventas nuevas, las diferencias son
-- esperadas hasta el próximo refresco; no son necesariamente un error de la
-- vista.

WITH base AS (
    SELECT
        (p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS fecha,
        pr.categoria_id,
        SUM(dp.cantidad * dp.precio_unitario) AS total_ventas
    FROM pedido AS p
    JOIN detalle_pedido AS dp
        ON dp.pedido_id = p.id_pedido
    JOIN producto AS pr
        ON pr.id_producto = dp.producto_id
    GROUP BY
        (p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date,
        pr.categoria_id
),
vista AS (
    SELECT
        mv.fecha,
        mv.categoria_id,
        mv.total_ventas
    FROM mv_ventas_categoria_dia AS mv
)
SELECT
    COALESCE(b.fecha, v.fecha)                AS fecha,
    COALESCE(b.categoria_id, v.categoria_id)  AS categoria_id,
    b.total_ventas                            AS total_base,
    v.total_ventas                            AS total_vista,
    b.total_ventas - v.total_ventas           AS diferencia,
    CASE
        WHEN v.fecha IS NULL THEN 'FALTA_EN_VISTA'
        WHEN b.fecha IS NULL THEN 'SOBRA_EN_VISTA'
        ELSE 'IMPORTE_DISTINTO'
    END                                       AS tipo_discrepancia
FROM base AS b
FULL OUTER JOIN vista AS v
    ON v.fecha = b.fecha
   AND v.categoria_id = b.categoria_id
WHERE b.fecha IS NULL
   OR v.fecha IS NULL
   OR b.total_ventas IS DISTINCT FROM v.total_ventas
ORDER BY fecha, categoria_id;


-- ----------------------------------------------------------------------------
-- 5.2 Control de ejecución y resultado de la auditoría
-- ----------------------------------------------------------------------------
-- La consulta 5.1 devuelve únicamente el detalle de las discrepancias. Un
-- resultado vacío de 5.1 es ambiguo si no se registró si la sentencia llegó a
-- ejecutarse. Esta consulta de control recalcula la auditoría de forma
-- independiente y devuelve siempre una fila con:
--   - grupos_base: grupos (fecha, categoria_id) agregados desde las tablas
--     originales;
--   - grupos_vista: grupos presentes en la vista materializada;
--   - discrepancias: grupos faltantes, sobrantes o con importe distinto;
--   - estado: SIN_DATOS, SIN_DISCREPANCIAS o CON_DISCREPANCIAS.
--
-- La consulta no depende del resultado de 5.1: puede ejecutarse aunque 5.1 no
-- se haya ejecutado y vuelve a calcular las discrepancias desde las tablas
-- base y la vista materializada con la misma convención temporal de Buenos
-- Aires. Si la vista no existe, no está poblada o no puede leerse, esta
-- consulta falla y no devuelve la fila de control; por lo tanto, la presencia
-- de la fila es evidencia de que el control se ejecutó.
--
-- Interpretación:
--   SIN_DATOS          -> no hay grupos ni en las tablas base ni en la vista;
--                         no es una validación sustantiva de datos.
--   SIN_DISCREPANCIAS  -> hay datos y coinciden cantidad de grupos y totales.
--   CON_DISCREPANCIAS  -> hay al menos una discrepancia o los conteos de
--                         grupos no coinciden.
--
-- Para evitar un falso SIN_DISCREPANCIAS ante un error previo, ejecutar 5.1 y
-- 5.2 en la misma sesión y con detención ante error (por ejemplo,
-- psql -v ON_ERROR_STOP=1 o la opción equivalente en DBeaver). Si se ejecutan
-- por separado, 5.2 sigue siendo válida por sí misma y su fila solo aparece
-- si la consulta se ejecutó correctamente.
--
-- La consulta de control repite los CTE base y vista porque los CTE no se
-- comparten entre sentencias distintas. No modifica ni reemplaza la salida de
-- 5.1.

WITH base AS (
    SELECT
        (p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS fecha,
        pr.categoria_id,
        SUM(dp.cantidad * dp.precio_unitario) AS total_ventas
    FROM pedido AS p
    JOIN detalle_pedido AS dp
        ON dp.pedido_id = p.id_pedido
    JOIN producto AS pr
        ON pr.id_producto = dp.producto_id
    GROUP BY
        (p.fecha_pedido AT TIME ZONE 'America/Argentina/Buenos_Aires')::date,
        pr.categoria_id
),
vista AS (
    SELECT
        mv.fecha,
        mv.categoria_id,
        mv.total_ventas
    FROM mv_ventas_categoria_dia AS mv
),
resumen AS (
    SELECT
        (SELECT COUNT(*) FROM base) AS grupos_base,
        (SELECT COUNT(*) FROM vista) AS grupos_vista,
        COUNT(*) FILTER (
            WHERE b.fecha IS NULL
               OR v.fecha IS NULL
               OR b.total_ventas IS DISTINCT FROM v.total_ventas
        ) AS discrepancias
    FROM base AS b
    FULL OUTER JOIN vista AS v
        ON v.fecha = b.fecha
       AND v.categoria_id = b.categoria_id
)
SELECT
    grupos_base,
    grupos_vista,
    discrepancias,
    CASE
        WHEN grupos_base = 0 AND grupos_vista = 0
            THEN 'SIN_DATOS'
        WHEN discrepancias > 0 OR grupos_base <> grupos_vista
            THEN 'CON_DISCREPANCIAS'
        ELSE 'SIN_DISCREPANCIAS'
    END AS estado
FROM resumen;


-- ============================================================================
-- 6. Diagnóstico posterior de la vista materializada (opcional)
-- ============================================================================
-- Estas consultas no son prerrequisitos de la consulta ni de la auditoría; se
-- incluyen para revisar la granularidad y el volumen después de ejecutarlas.

-- 6.1 Duplicados para (fecha, categoria_id); se espera 0 filas
SELECT fecha, categoria_id, COUNT(*) AS filas
FROM mv_ventas_categoria_dia
GROUP BY fecha, categoria_id
HAVING COUNT(*) > 1;

-- 6.2 Cantidad de filas y rango de fechas materializadas
SELECT
    COUNT(*) AS total_filas_materializadas,
    MIN(fecha) AS primera_fecha,
    MAX(fecha) AS ultima_fecha
FROM mv_ventas_categoria_dia;
