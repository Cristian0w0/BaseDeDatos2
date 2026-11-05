# Especificación Kiro — Requisitos de Normalización FNBC y Desnormalización (Unidad 4)
## Asignatura: Base de Datos II · Tecnicatura Universitaria en Programación (UTN)
### Proyecto Integrador: Food Store · Módulo: Control de Almacén y Ventas

---

## 1. Contexto del Problema y Alcance
En el esquema relacional heredado del subsistema logístico de Food Store, la relación `control_lote_almacen` gestiona las asignaciones de control físico de lotes de insumos perecederos en depósitos de acopio. Dicho esquema presenta redundancias operativas y anomalías de actualización, inserción y borrado derivadas de dependencias funcionales no alineadas con la definición formal de la Forma Normal de Boyce-Codd (FNBC).

Asimismo, el panel gerencial de monitoreo de facturación experimenta cuellos de botella al calcular en tiempo real el ranking diario de ventas por categoría mediante uniones relacionales cuádruples sobre tablas masivas.

---

## 2. Requisitos Funcionales en Notación EARS

### 2.1. Normalización y Refactorización hasta FNBC (Subsistema Logístico)
* **REQ-FNBC-01 (Ubicua):** El sistema DEBE almacenar el responsable asignado a cada control de lote garantizando que cada responsable pertenezca a un único depósito.
* **REQ-FNBC-02 (Impulsada por evento):** CUANDO un responsable de control sea asignado a un depósito sin poseer aún lotes asignados, el sistema DEBE permitir registrar dicha pertenencia sin requerir identificadores ficticios (*eliminación de anomalía de inserción*).
* **REQ-FNBC-03 (Impulsada por evento):** CUANDO se elimine el registro de control de un lote específico, el sistema NO DEBE eliminar la relación de pertenencia entre el responsable y su depósito (*eliminación de anomalía de borrado*).
* **REQ-FNBC-04 (Impulsada por evento):** CUANDO un responsable sea transferido a otro depósito, el sistema DEBE exigir la actualización de una única fila en una tabla atómica (*eliminación de anomalía de actualización*).
* **REQ-FNBC-05 (Ubicua):** El esquema descompuesto DEBE garantizar la descomposición sin pérdida de información (*Lossless-Join Decomposition*) demostrable formalmente mediante el Criterio de Heath.
* **REQ-FNBC-06 (Ubicua):** El sistema DEBE proveer una vista de compatibilidad `v_control_lote_almacen` que reproduzca exactamente las tuplas del esquema original mediante una reunión natural interna.

### 2.2. Migración Transaccional y Plan de Reversión (Gobernanza)
* **REQ-MIG-01 (Ubicua):** La migración de datos desde el esquema heredado hacia las tablas descompuestas DEBE ejecutarse en su totalidad dentro de una transacción reversible explícita (`BEGIN ... COMMIT / ROLLBACK`).
* **REQ-MIG-02 (Impulsada por evento):** SI las consultas de validación de conjuntos (`EXCEPT` bidireccional) reportan cualquier diferencia de cardinalidad o de tuplas, el sistema DEBE abortar de inmediato la transacción mediante `ROLLBACK` (*reversión obligatoria*).
* **REQ-MIG-03 (Ubicua):** Ningún dato original DEBE ser destruido o eliminado (`DROP`, `TRUNCATE`) durante la migración; la tabla original `control_lote_almacen` debe conservarse como base testigo auditable.

### 2.3. Desnormalización Controlada (Panel Gerencial de Ventas)
* **REQ-DES-01 (Impulsada por evento):** CUANDO la gerencia consulte el Top 5 de categorías con mayor volumen de facturación para una fecha, el tiempo de respuesta DEBE reducirse en más del 90% respecto a la consulta sobre tablas base.
* **REQ-DES-02 (Ubicua):** Las tablas base `pedido`, `detalle_pedido`, `producto` y `categoria` DEBEN permanecer como la única fuente de verdad (*Single Source of Truth*); los datos agregados residirán en una vista materializada (`mv_ventas_categoria_dia`).
* **REQ-DES-03 (Ubicua):** La vista materializada DEBE admitir actualizaciones no bloqueantes mediante `REFRESH MATERIALIZED VIEW CONCURRENTLY` gracias a un índice único compuesto sobre `(fecha, categoria_id)`.
* **REQ-DES-04 (Ubicua):** El sistema DEBE disponer de una consulta de auditoría de sincronización que detecte discrepancias de importes o tuplas huérfanas mediante `FULL OUTER JOIN` entre las tablas base y la vista materializada.
