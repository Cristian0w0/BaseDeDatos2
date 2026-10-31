-- ============================================================================
-- TP6 - Base de Datos 2 - Food Store
-- Punto 4.2 e) - Descomposición sin pérdida de control_lote_almacen
-- Archivo: db/tp6_descomposicion_fnbc.sql
-- ============================================================================
-- Ejercicio académico autocontenido. Este script crea las tablas maestras
-- mínimas usuario, deposito y lote, y las relaciones resultantes de la
-- descomposición. No modifica db/schema.sql ni el esquema original de Food
-- Store.
--
-- Relación original:
--   control_lote_almacen(lote_id, deposito_id, responsable_control_id)
--
-- Claves candidatas de la relación original:
--   {lote_id, deposito_id} y {lote_id, responsable_control_id}
--
-- Dependencias funcionales:
--   DF1: (lote_id, deposito_id) -> responsable_control_id
--   DF2: responsable_control_id -> deposito_id
--
-- DF2 viola la FNBC porque su determinante no es una superclave de la
-- relación original. Se aplica la descomposición sin pérdida basada en DF2:
--
--   R1: responsable_deposito(responsable_control_id, deposito_id)
--   R2: control_lote(lote_id, responsable_control_id)
--
-- La descomposición es sin pérdida porque R1 ∩ R2 = {responsable_control_id}
-- y ese atributo es clave primaria de R1. Por lo tanto, cada fila de
-- control_lote se asocia con un único depósito y la reunión no genera tuplas
-- espurias.
--
-- R1 y R2 quedan en FNBC:
--   R1: responsable_control_id -> deposito_id, y responsable_control_id
--       es su clave.
--   R2: no tiene dependencias funcionales no triviales.
--
-- DF2 queda preservada por la clave primaria de responsable_deposito.
--
-- DF1 ((lote_id, deposito_id) -> responsable_control_id) NO queda preservada:
-- las claves primarias y foráneas de la descomposición no impiden que un mismo
-- par (lote_id, deposito_id) tenga más de un responsable. La consulta de
-- diagnóstico incluida al final permite detectar esos casos, pero no los
-- impide.
--
-- Las tablas maestras usuario, deposito y lote son mínimas y se crean
-- exclusivamente para que este ejercicio sea autocontenido y reproducible.
-- No forman parte del esquema original de Food Store.
--
-- No se agregan datos de ejemplo ni triggers correctivos.
-- ============================================================================

SET search_path TO public;


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
-- 2. R1 - responsable_deposito(responsable_control_id, deposito_id)
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
-- 3. R2 - control_lote(lote_id, responsable_control_id)
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
-- 4. Vista de compatibilidad
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

CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT
    cl.lote_id,
    rd.deposito_id,
    cl.responsable_control_id
FROM control_lote AS cl
JOIN responsable_deposito AS rd
    USING (responsable_control_id);


-- ============================================================================
-- 5. Consulta de diagnóstico (comentada; NO se ejecuta automáticamente)
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
