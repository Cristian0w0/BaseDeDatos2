# Plan de Migración Transaccional y Reversión Obligatoria (Unidad 4)
## Asignatura: Base de Datos II · Tecnicatura Universitaria en Programación (UTN)
### Proyecto Integrador: Food Store · Módulo: Migración FNBC y Salvaguardas

---

## 1. Principios de Seguridad en la Migración de Datos
En consonancia con el Protocolo Obligatorio de Manejo de Datos de la cátedra y las políticas de seguridad del proyecto (`.kiro/steering/security-policies.md`), toda mutación estructural o migración de esquemas debe cumplir con las siguientes directivas:
1. **Atomicidad estricta y transacciones reversibles:** Ninguna sentencia DDL o DML de migración se ejecuta en modo autocommit. Se utiliza un bloque transaccional explícito `BEGIN ... COMMIT / ROLLBACK`.
2. **Aislamiento en copias de prueba:** La migración se ensaya inicialmente sobre la base descartable de trabajo (`bd2_tp6`), preservando la base de producción intacta.
3. **Validación automática previa a la confirmación:** El cierre con `COMMIT` solo es admisible si las consultas de verificación de conjuntos (`EXCEPT` bidireccional) reportan cero diferencias.
4. **Preservación de la fuente de verdad original:** La tabla heredada `control_lote_almacen` no se elimina (`DROP`) ni se vacía (`TRUNCATE`), permaneciendo como testigo histórico para auditoría forense.

---

## 2. Procedimiento de Ejecución Paso a Paso

### 2.1. Bloque de Ejecución Transaccional
```sql
-- Conexión a la base de prueba bd2_tp6
SET search_path TO public;

BEGIN; -- Inicio de transacción reversible

-- Paso 1: Creación de tablas maestras mínimas
CREATE TABLE IF NOT EXISTS usuario (
    id_usuario BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);
CREATE TABLE IF NOT EXISTS deposito (
    id_deposito BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);
CREATE TABLE IF NOT EXISTS lote (
    id_lote BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

-- Paso 2: Creación de relaciones descompuestas en FNBC
CREATE TABLE IF NOT EXISTS responsable_deposito (
    responsable_control_id BIGINT PRIMARY KEY,
    deposito_id BIGINT NOT NULL,
    CONSTRAINT fk_rd_usuario FOREIGN KEY (responsable_control_id) 
        REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
    CONSTRAINT fk_rd_deposito FOREIGN KEY (deposito_id) 
        REFERENCES deposito(id_deposito) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS control_lote (
    lote_id BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL,
    PRIMARY KEY (lote_id, responsable_control_id),
    CONSTRAINT fk_cl_lote FOREIGN KEY (lote_id) 
        REFERENCES lote(id_lote) ON DELETE RESTRICT,
    CONSTRAINT fk_cl_responsable FOREIGN KEY (responsable_control_id) 
        REFERENCES responsable_deposito(responsable_control_id) ON DELETE RESTRICT
);

-- Paso 3: Migración de datos mediante inserción con deduplicación
INSERT INTO usuario (id_usuario)
OVERRIDING SYSTEM VALUE
SELECT DISTINCT responsable_control_id FROM control_lote_almacen;

INSERT INTO deposito (id_deposito)
OVERRIDING SYSTEM VALUE
SELECT DISTINCT deposito_id FROM control_lote_almacen;

INSERT INTO lote (id_lote)
OVERRIDING SYSTEM VALUE
SELECT DISTINCT lote_id FROM control_lote_almacen;

INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id FROM control_lote_almacen;

INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT lote_id, responsable_control_id FROM control_lote_almacen;

-- Paso 4: Creación de la vista de compatibilidad
CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT
    cl.lote_id,
    rd.deposito_id,
    cl.responsable_control_id
FROM control_lote AS cl
JOIN responsable_deposito AS rd USING (responsable_control_id);
```

---

## 3. Criterios de Aceptación y Validación Automática
Antes de emitir el `COMMIT`, se ejecutan las siguientes aserciones analíticas de conjuntos:

### Aserción A · Verificación de Pérdida Cero (Diferencia de Conjuntos)
```sql
-- 1. Tuplas en la relación original que no aparecen en la vista descompuesta:
SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen
EXCEPT
SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen;
-- RESULTADO EXIGIDO: 0 filas.

-- 2. Tuplas espurias en la vista que no existían en la relación original:
SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen
EXCEPT
SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen;
-- RESULTADO EXIGIDO: 0 filas.
```

### Aserción B · Comprobación de Conteos Cardinales
```sql
SELECT 
    (SELECT COUNT(*) FROM control_lote_almacen) AS cant_original,
    (SELECT COUNT(*) FROM v_control_lote_almacen) AS cant_vista,
    (SELECT COUNT(*) FROM responsable_deposito) AS cant_responsables,
    (SELECT COUNT(*) FROM control_lote) AS cant_controles;
-- RESULTADO ESPERADO: cant_original = cant_vista = 3, cant_responsables = 2, cant_controles = 3.
```

---

## 4. Plan de Reversión Obligatorio (*Rollback Strategy*)

### 4.1. Reversión Inmediata en Fase de Ejecución (En Memoria)
Si cualquiera de las consultas de aserción falla, devuelve tuplas o arroja un error de clave foránea/unicidad:
```sql
-- ABORTO INMEDIATO DE LA OPERACIÓN
ROLLBACK;
```
*Efecto de la reversión inmediata:*  
PostgreSQL cancela todas las operaciones DDL y DML ejecutadas dentro del bloque. El catálogo del motor y los datos vuelven instantáneamente al estado exacto previo al `BEGIN`, garantizando que ningún objeto huérfano quede creado.

### 4.2. Reversión Post-Commit (Plan de Contingencia ante Fallos en Producción)
Si tras un `COMMIT` inadvertido se detectan anomalías en el software consumidor o inconsistencias lógicas en el negocio, se activa el protocolo de contingencia mediante el siguiente script de desmantelamiento controlado:

```sql
BEGIN;

-- 1. Redirigir el software cliente a la tabla original (si se alteró el alias)
DROP VIEW IF EXISTS v_control_lote_almacen CASCADE;

-- 2. Eliminar relaciones dependientes en orden inverso de claves foráneas
DROP TABLE IF EXISTS control_lote CASCADE;
DROP TABLE IF EXISTS responsable_deposito CASCADE;

-- 3. Eliminar tablas maestras accesorias creadas para el ejercicio
DROP TABLE IF EXISTS lote CASCADE;
DROP TABLE IF EXISTS deposito CASCADE;
DROP TABLE IF EXISTS usuario CASCADE;

-- 4. Comprobación de integridad de la tabla testigo
SELECT COUNT(*) AS filas_recuperadas FROM control_lote_almacen;
-- Debe devolver exactamente 3 filas.

COMMIT;
```

*Garantía del plan de reversión:*  
Dado que la tabla original `control_lote_almacen` nunca fue alterada ni eliminada durante el proceso, el restablecimiento del estado anterior es 100% determinista, inmediato y sin ninguna pérdida de información histórica.
