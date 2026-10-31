-- ============================================================================
-- TP6 - Base de Datos 2 - Food Store
-- Parte 1 - Forma Normal de Boyce-Codd
-- Entregable: db/tp_fnbc_control_lote.sql
-- ============================================================================
-- Objetivo:
--   Representar la relación original control_lote_almacen y su instancia de
--   ejemplo, migrarla a la descomposición sin pérdida en responsable_deposito
--   y control_lote, conservar la vista de compatibilidad v_control_lote_almacen
--   y verificar que la vista reconstruye exactamente la instancia original.
--
-- Relación original:
--   control_lote_almacen(lote_id, deposito_id, responsable_control_id)
--   Clave primaria: (lote_id, deposito_id)
--   Clave candidata adicional: (lote_id, responsable_control_id)
--
-- Dependencias funcionales:
--   DF1: (lote_id, deposito_id) -> responsable_control_id
--   DF2: responsable_control_id -> deposito_id
--
-- Descomposición:
--   R1: responsable_deposito(responsable_control_id, deposito_id)
--   R2: control_lote(lote_id, responsable_control_id)
--
-- Orden de ejecución:
--   1. Conectarse a la base bd2_tp6.
--   2. Confirmar que el esquema public NO contiene los objetos usuario,
--      deposito, lote, control_lote_almacen, responsable_deposito,
--      control_lote ni v_control_lote_almacen.
--   3. Ejecutar el script completo, de arriba hacia abajo.
--   4. Revisar las consultas de la Sección 7 y comparar con los resultados
--      esperados.
--
-- Condiciones previas y alcance:
--   - PostgreSQL (el proyecto usa PostgreSQL 17).
--   - El script es de ejecución única y NO es reejecutable.
--   - No incluye DROP TABLE, TRUNCATE ni limpieza de datos.
--   - No modifica db/schema.sql ni agrega estas tablas al esquema base.
--   - No ejecutar sobre una base donde ya se ejecutó
--     db/tp6_descomposicion_fnbc.sql: los CREATE TABLE fallarán.
--   - Si alguno de los objetos ya existe, detener la ejecución y revisar la
--     base manualmente fuera de este script.
--   - La migración usa identificadores explícitos sobre columnas IDENTITY;
--     por eso requiere OVERRIDING SYSTEM VALUE.
--   - El script no ajusta las secuencias de identidad.
--   - Si alguna sentencia falla, la transacción debe revertirse con ROLLBACK
--     y revisarse la causa antes de reintentar sobre una base limpia.
--
-- Decisión de diseño:
--   - control_lote_almacen es la tabla fuente que representa la relación
--     original y conserva su instancia de ejemplo. Se mantiene en el script
--     para poder verificar la migración contra el origen. No representa el
--     modelo descompuesto final.
--   - Las tablas maestras y las tablas descompuestas se cargan desde esa
--     instancia mediante INSERT ... SELECT, no mediante valores duplicados
--     codificados por separado.
--
-- Ejecución segura de la transacción:
--   - El script abre una transacción con BEGIN y la cierra con COMMIT al
--     final de la Sección 8.
--   - Ejecutar por bloques: primero todo hasta la Sección 7, revisar los
--     resultados, y solo después ejecutar el COMMIT de la Sección 8.
--   - Si alguna verificación muestra discrepancias, ejecutar ROLLBACK en
--     lugar de COMMIT. Un SELECT no revierte la transacción ni provoca un
--     rollback automático.
--   - Si se ejecuta el archivo completo de una vez, el COMMIT se ejecutará
--     inmediatamente después de las verificaciones, sin pausa para revisión.
--
-- Aclaración:
--   Los resultados de la Sección 7 son esperados. Este archivo no declara
--   haber sido ejecutado ni verificado en PostgreSQL.
-- ============================================================================

SET search_path TO public;

BEGIN;

-- ============================================================================
-- 1. Tablas maestras mínimas
-- ============================================================================
-- Se crean antes de las relaciones derivadas para poder declarar las FK.
-- Solo contienen su clave primaria; no modelan el resto del dominio.

CREATE TABLE usuario (
    id_usuario BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

CREATE TABLE deposito (
    id_deposito BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

CREATE TABLE lote (
    id_lote BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);


-- ============================================================================
-- 2. Relación original y su instancia de ejemplo
-- ============================================================================
-- Se materializa la relación original para conservar explícitamente el origen
-- de la migración. Su clave primaria es (lote_id, deposito_id) y se declara
-- además la clave candidata (lote_id, responsable_control_id).
--
-- Esta tabla se conserva para comparar la vista reconstruida contra el origen.
-- No es parte del modelo descompuesto final.

CREATE TABLE control_lote_almacen (
    lote_id BIGINT NOT NULL,
    deposito_id BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL,

    CONSTRAINT pk_control_lote_almacen
        PRIMARY KEY (lote_id, deposito_id),

    CONSTRAINT uq_control_lote_almacen_lote_responsable
        UNIQUE (lote_id, responsable_control_id)
);

INSERT INTO control_lote_almacen (
    lote_id,
    deposito_id,
    responsable_control_id
)
VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);


-- ============================================================================
-- 3. R1 - responsable_deposito(responsable_control_id, deposito_id)
-- ============================================================================
-- La PK sobre responsable_control_id garantiza DF2: cada responsable
-- pertenece a un único depósito.
--
-- Excepción deliberada a la convención de PK con identidad: esta columna es
-- el determinante de DF2 y debe recibir el identificador del responsable, no
-- uno generado por la base.

CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT NOT NULL,
    deposito_id BIGINT NOT NULL,

    CONSTRAINT pk_responsable_deposito
        PRIMARY KEY (responsable_control_id),

    CONSTRAINT fk_responsable_deposito_usuario
        FOREIGN KEY (responsable_control_id)
        REFERENCES usuario (id_usuario)
        ON DELETE RESTRICT,

    CONSTRAINT fk_responsable_deposito_deposito
        FOREIGN KEY (deposito_id)
        REFERENCES deposito (id_deposito)
        ON DELETE RESTRICT
);


-- ============================================================================
-- 4. R2 - control_lote(lote_id, responsable_control_id)
-- ============================================================================
-- La PK compuesta conserva la clave candidata (lote_id, responsable_control_id)
-- de la relación original. Las FK aseguran que el lote exista y que el
-- responsable tenga un depósito asignado en responsable_deposito, lo que hace
-- válida la reunión de la vista.
--
-- Esta tabla no almacena deposito_id: ese atributo se obtiene mediante la
-- vista de compatibilidad.

CREATE TABLE control_lote (
    lote_id BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL,

    CONSTRAINT pk_control_lote
        PRIMARY KEY (lote_id, responsable_control_id),

    CONSTRAINT fk_control_lote_lote
        FOREIGN KEY (lote_id)
        REFERENCES lote (id_lote)
        ON DELETE RESTRICT,

    CONSTRAINT fk_control_lote_responsable_deposito
        FOREIGN KEY (responsable_control_id)
        REFERENCES responsable_deposito (responsable_control_id)
        ON DELETE RESTRICT
);


-- ============================================================================
-- 5. Vista de compatibilidad
-- ============================================================================
-- Reconstruye la relación original con las columnas:
--   lote_id, deposito_id, responsable_control_id
--
-- El JOIN ... USING (responsable_control_id) es la reunión natural por el
-- atributo común. La FK de control_lote garantiza que toda fila de R2 tenga
-- su correspondiente fila en R1, por lo que el JOIN interno no pierde filas.
--
-- La vista no es actualizable automáticamente en PostgreSQL por ser una
-- reunión. Si se necesitara escribir a través de ella, habría que definir
-- triggers INSTEAD OF (fuera del alcance de este TP).

CREATE VIEW v_control_lote_almacen AS
SELECT
    cl.lote_id,
    rd.deposito_id,
    cl.responsable_control_id
FROM control_lote AS cl
JOIN responsable_deposito AS rd
    USING (responsable_control_id);


-- ============================================================================
-- 6. Migración desde la instancia original
-- ============================================================================
-- Todas las filas se derivan de control_lote_almacen.
--
-- Orden obligatorio para respetar las claves foráneas:
--   1. usuario, deposito y lote (valores distintos observados en el origen)
--   2. responsable_deposito (proyección de DF2)
--   3. control_lote (proyección de la clave candidata restante)
--
-- Las PK de usuario, deposito y lote son GENERATED ALWAYS AS IDENTITY.
-- Por eso los identificadores explícitos requieren OVERRIDING SYSTEM VALUE.
-- Las secuencias de identidad no se ajustan después de esta carga.

-- 6.1 Tablas maestras: valores distintos presentes en la instancia original.

INSERT INTO usuario (id_usuario)
OVERRIDING SYSTEM VALUE
SELECT DISTINCT responsable_control_id
FROM control_lote_almacen;

INSERT INTO deposito (id_deposito)
OVERRIDING SYSTEM VALUE
SELECT DISTINCT deposito_id
FROM control_lote_almacen;

INSERT INTO lote (id_lote)
OVERRIDING SYSTEM VALUE
SELECT DISTINCT lote_id
FROM control_lote_almacen;

-- 6.2 R1: proyección de (responsable_control_id, deposito_id).
-- DISTINCT explicita que cada responsable debe quedar asociado a un único
-- depósito. Si la instancia original violara DF2, la PK de R1 rechazaría la
-- carga en lugar de aceptar un estado inconsistente.

INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT
    responsable_control_id,
    deposito_id
FROM control_lote_almacen;

-- 6.3 R2: proyección de (lote_id, responsable_control_id).

INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT
    lote_id,
    responsable_control_id
FROM control_lote_almacen;


-- ============================================================================
-- 7. Verificaciones (solo lectura)
-- ============================================================================
-- Estas consultas no modifican datos y se ejecutan dentro de la transacción
-- abierta en la Sección 1. Revisar sus resultados antes del COMMIT de la
-- Sección 8. Los valores indicados son los esperados para la instancia de
-- ejemplo y quedan pendientes de ejecución en PostgreSQL.

-- ----------------------------------------------------------------------------
-- 7.1 Instancia original cargada
-- ----------------------------------------------------------------------------
-- Resultado esperado:
--   lote_id | deposito_id | responsable_control_id
--   --------+-------------+------------------------
--       501 |          30 |                    801
--       502 |          30 |                    801
--       503 |          31 |                    802

SELECT
    lote_id,
    deposito_id,
    responsable_control_id
FROM control_lote_almacen
ORDER BY lote_id, deposito_id;


-- ----------------------------------------------------------------------------
-- 7.2 Reconstrucción de la vista
-- ----------------------------------------------------------------------------
-- Resultado esperado:
--   lote_id | deposito_id | responsable_control_id
--   --------+-------------+------------------------
--       501 |          30 |                    801
--       502 |          30 |                    801
--       503 |          31 |                    802

SELECT
    lote_id,
    deposito_id,
    responsable_control_id
FROM v_control_lote_almacen
ORDER BY lote_id, responsable_control_id;


-- ----------------------------------------------------------------------------
-- 7.3 Conteo de filas del origen, la migración y la vista
-- ----------------------------------------------------------------------------
-- Este conteo complementa las comparaciones de conjuntos: EXCEPT elimina
-- duplicados, por lo que las filas repetidas en el origen o en la vista se
-- detectarían por el conteo esperado de 3 filas.
--
-- Resultado esperado:
--   control_lote (R2)           | 3
--   control_lote_almacen        | 3
--   responsable_deposito (R1)   | 2
--   v_control_lote_almacen      | 3

SELECT 'control_lote (R2)' AS conjunto, COUNT(*) AS filas
FROM control_lote
UNION ALL
SELECT 'control_lote_almacen', COUNT(*)
FROM control_lote_almacen
UNION ALL
SELECT 'responsable_deposito (R1)', COUNT(*)
FROM responsable_deposito
UNION ALL
SELECT 'v_control_lote_almacen', COUNT(*)
FROM v_control_lote_almacen
ORDER BY conjunto;


-- ----------------------------------------------------------------------------
-- 7.4 Instancia original contra las tuplas literales esperadas
-- ----------------------------------------------------------------------------
-- Compara control_lote_almacen con las tres tuplas de la consigna mediante
-- EXCEPT en ambas direcciones. Devuelve 0 filas si la carga del origen es
-- exacta.
--
-- Casos detectados:
--   FALTA_EN_ORIGEN -> la tupla esperada no está en control_lote_almacen.
--   SOBRA_EN_ORIGEN -> control_lote_almacen contiene una tupla no esperada.
--
-- Resultado esperado: 0 filas.

WITH esperado (lote_id, deposito_id, responsable_control_id) AS (
    VALUES
        (501::BIGINT, 30::BIGINT, 801::BIGINT),
        (502::BIGINT, 30::BIGINT, 801::BIGINT),
        (503::BIGINT, 31::BIGINT, 802::BIGINT)
),
faltantes AS (
    SELECT lote_id, deposito_id, responsable_control_id
    FROM esperado
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id
    FROM control_lote_almacen
),
sobrantes AS (
    SELECT lote_id, deposito_id, responsable_control_id
    FROM control_lote_almacen
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id
    FROM esperado
)
SELECT
    lote_id,
    deposito_id,
    responsable_control_id,
    'FALTA_EN_ORIGEN'::TEXT AS tipo_discrepancia
FROM faltantes
UNION ALL
SELECT
    lote_id,
    deposito_id,
    responsable_control_id,
    'SOBRA_EN_ORIGEN'::TEXT AS tipo_discrepancia
FROM sobrantes
ORDER BY tipo_discrepancia, lote_id, deposito_id, responsable_control_id;


-- ----------------------------------------------------------------------------
-- 7.5 Comparación de conjuntos: vista contra instancia original
-- ----------------------------------------------------------------------------
-- Compara la vista contra la tabla fuente mediante EXCEPT en ambas
-- direcciones. Devuelve 0 filas si no hay tuplas faltantes ni sobrantes.
--
-- Casos detectados:
--   FALTA_EN_VISTA -> la tupla original no aparece en la vista.
--   SOBRA_EN_VISTA -> la vista contiene una tupla que no está en el original.
--
-- Resultado esperado: 0 filas.

WITH faltantes AS (
    SELECT lote_id, deposito_id, responsable_control_id
    FROM control_lote_almacen
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id
    FROM v_control_lote_almacen
),
sobrantes AS (
    SELECT lote_id, deposito_id, responsable_control_id
    FROM v_control_lote_almacen
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id
    FROM control_lote_almacen
)
SELECT
    lote_id,
    deposito_id,
    responsable_control_id,
    'FALTA_EN_VISTA'::TEXT AS tipo_discrepancia
FROM faltantes
UNION ALL
SELECT
    lote_id,
    deposito_id,
    responsable_control_id,
    'SOBRA_EN_VISTA'::TEXT AS tipo_discrepancia
FROM sobrantes
ORDER BY tipo_discrepancia, lote_id, deposito_id, responsable_control_id;


-- ============================================================================
-- 8. Confirmación de la transacción
-- ============================================================================
-- La transacción permanece abierta mientras se ejecutan las verificaciones
-- de la Sección 7. Revisar sus resultados antes de confirmar.
--
-- Si alguna verificación muestra discrepancias:
--   ROLLBACK;
--
-- Si todas las verificaciones coinciden con los resultados esperados:
--   COMMIT;
--
-- Un SELECT no revierte la transacción ni provoca un rollback automático:
-- la decisión entre COMMIT y ROLLBACK es manual.
--
-- Si se ejecuta el archivo completo de una vez, el COMMIT siguiente se
-- ejecutará inmediatamente después de las verificaciones, sin pausa para
-- revisión. Para revisar antes de confirmar, ejecutar por bloques.

COMMIT;


-- ============================================================================
-- 9. Consulta de diagnóstico (opcional y comentada)
-- ============================================================================
-- Detecta pares (lote_id, deposito_id) asociados a más de un responsable.
-- Si devuelve filas, la instancia no satisface la DF1:
--   (lote_id, deposito_id) -> responsable_control_id
--
-- Esta consulta solo detecta la violación; no la impide ni corrige los datos.

-- SELECT
--     lote_id,
--     deposito_id,
--     COUNT(DISTINCT responsable_control_id) AS cantidad_responsables
-- FROM v_control_lote_almacen
-- GROUP BY lote_id, deposito_id
-- HAVING COUNT(DISTINCT responsable_control_id) > 1
-- ORDER BY lote_id, deposito_id;
