# Base de Datos 2 — Food Store

Repositorio del proyecto integrador **«Food Store»** desarrollado para la asignatura **Base de Datos II**.

El repositorio reúne los trabajos prácticos de la materia. La **primera entrega parcial del Trabajo Práctico Integrador (TPI)** consolida los contenidos de las **unidades 1, 2 y 3**. El **TP6** corresponde a la **Unidad 4: Forma Normal de Boyce-Codd y Desnormalización Controlada**.

## Estado del proyecto

El estado actual del repositorio incorpora el **TP6 — Forma Normal de Boyce-Codd y Desnormalización Controlada**, desarrollado sobre una copia poblada de la base Food Store y tomando como antecedente el TPI del primer parcial.

**Rama de trabajo:** `tp6-fnbc-desnormalizacion`

**Motor utilizado:** PostgreSQL 17.11

**Lenguaje de procedimientos:** PL/pgSQL

## Alcance del repositorio

### TPI del primer parcial (unidades 1, 2 y 3)

La primera entrega parcial del TPI reúne y consolida:

1. Integridad, transacciones y concurrencia.
2. Optimización de consultas.
3. Índices, vistas y objetos programables del motor.

El detalle de los nueve objetivos, las evidencias y los resultados de esa entrega se encuentran en:

```text
docs/tpi_parcial1/README.md
docs/tpi_parcial1/informe_tpi_parcial1.md
```

### TP6 (Unidad 4)

El TP6 se organiza en dos partes independientes:

* **Parte 1 — FNBC:** análisis de dependencias funcionales, clausuras, claves candidatas, verificación de FNBC, anomalías, descomposición sin pérdida, claves primarias y foráneas, vista de compatibilidad, migración y verificación.
* **Parte 2 — Desnormalización controlada:** consulta original, elección del patrón, estructura desnormalizada, mecanismo de sincronización, consulta desnormalizada, comparación con `EXPLAIN ANALYZE` y auditoría de sincronización.

La consigna completa se encuentra en:

```text
docs/tp6/TP_U4_FNBC_Desnormalizacion_FoodStore.pdf
```

## Requisitos de la consigna (Unidad 4)

La consigna establece dos partes independientes y tres entregables:

1. `db/tp_fnbc_control_lote.sql` — Parte 1: esquema original, instancia de ejemplo, tablas descompuestas, vista de compatibilidad y migración de datos verificada.
2. `db/tp_desnormalizacion_top_categorias.sql` — Parte 2: estructura desnormalizada, mecanismo de sincronización, consulta de 5.2(d) y auditoría de 5.2(e).
3. Informe breve en PDF o Word con las dependencias funcionales, claves candidatas, demostración de la violación de FNBC, justificación de la unión sin pérdida, capturas de `EXPLAIN ANALYZE` antes/después y justificación del patrón elegido.

En el repositorio, el informe se conserva como:

```text
docs/tp6/informe_fnbc.pdf
docs/tp6/informe_fnbc.md
```

La consigna también exige que toda afirmación técnica esté acompañada por el artefacto SQL o la salida de `EXPLAIN ANALYZE` que la demuestre.

## Decisiones de implementación

Estas decisiones pertenecen a la implementación del repositorio y no deben confundirse con los requisitos textuales de la consigna:

* La consulta de la Parte 2 fue adaptada a los nombres de columnas de `db/schema.sql`. El esquema del proyecto no contiene `detalle_pedido.subtotal` ni las columnas `eliminado` usadas en la consulta de la consigna; por eso el subtotal se calcula como `cantidad * precio_unitario` y no se aplican filtros de borrado lógico sobre `pedido` o `detalle_pedido`.
* El script de la Parte 1 crea las tablas maestras mínimas `usuario`, `deposito` y `lote` para que el ejercicio sea autocontenido. Esas tablas son una extensión del ejercicio y no forman parte del esquema original de Food Store.
* La Parte 2 utiliza una vista materializada (`mv_ventas_categoria_dia`) en lugar de una columna precalculada con disparador. Las tablas base siguen siendo la fuente de verdad.
* El refresco de la vista materializada es externo o manual. El script canónico define la estructura y el mecanismo, pero no programa ni ejecuta el refresco. La solución no es de tiempo real estricto: entre refrescos, la vista puede quedar desactualizada.
* `db/tp_desnormalizacion_top_categorias.sql` es la definición canónica de la Parte 2 y consolida la estructura y la auditoría. Los scripts auxiliares no son necesarios para la entrega.
* La discrepancia entre las mediciones del informe y la advertencia del script canónico se documenta en este README, pero no se modifica ningún script SQL para resolverla.

## Estructura del repositorio

```text
Food-Store/

├── db/
│   ├── schema.sql
│   ├── indices.sql
│   ├── views.sql
│   ├── consultas_tp4_parte3.sql
│   ├── generador_datos_tp3.sql
│   ├── generador_datos_tp3_carga.sql
│   ├── tpi_parcial1_pruebas.sql
│   ├── tp_fnbc_control_lote.sql
│   ├── tp_desnormalizacion_top_categorias.sql
│   ├── tp6_descomposicion_fnbc.sql
│   ├── tp6_vista_materializada_ventas.sql
│   ├── tp6_auditoria_ventas.sql
│   └── backups/
│
├── docs/
│   ├── tp1/
│   ├── tp2/
│   ├── tp3/
│   ├── tp4/
│   ├── tp5/
│   │   ├── README.md
│   │   ├── informe_mediciones.md
│   │   └── especificaciones/
│   │       ├── indice_pedido_tarjeta_fecha.md
│   │       ├── indice_producto_activo_id_rechazado.md
│   │       ├── indice_producto_activo_precio.md
│   │       ├── vista_detalle_pedido_con_producto.md
│   │       ├── vista_materializada_gasto_cliente.md
│   │       ├── vista_pedidos_con_cliente.md
│   │       └── vista_productos_vigentes.md
│   ├── tp6/
│   │   ├── TP_U4_FNBC_Desnormalizacion_FoodStore.pdf
│   │   ├── informe_fnbc.md
│   │   ├── informe_fnbc.pdf
│   │   └── evidencias/
│   │       ├── explain_original.png
│   │       └── explain_vista_materializada.png
│   └── tpi_parcial1/
│       ├── informe_tpi_parcial1.md
│       └── README.md
│
└── README.md
```

### Especificaciones históricas de TP5

`docs/tp5/especificaciones/` contiene las especificaciones documentales históricas de TP5 sobre índices y vistas. No son scripts SQL ejecutables. Incluye propuestas aceptadas y una propuesta rechazada (`indice_producto_activo_id_rechazado.md`); el índice rechazado no debe incorporarse a los scripts ejecutables. Las implementaciones efectivas de vistas e índices están en `db/views.sql` y `db/indices.sql`, que son la fuente de verdad.

## Base de datos

La base de datos del **TPI del primer parcial** es:

```text
bd2_tpi_parcial1
```

El esquema principal del proyecto se encuentra en:

```text
db/schema.sql
```

Este archivo contiene las tablas, tipos, claves, restricciones, triggers, funciones y el procedimiento almacenado `sp_desactivar_producto`.

El **TP6** se documenta sobre una base separada:

```text
bd2_tp6
```

La Parte 1 es autocontenida y no requiere las tablas de Food Store. La Parte 2 requiere que las tablas `pedido`, `detalle_pedido`, `producto` y `categoria` existan y estén pobladas.

## Scripts del TP6

### Entregables oficiales

#### `db/tp_fnbc_control_lote.sql`

Entregable oficial de la **Parte 1**. Crea la relación original `control_lote_almacen` con su instancia de ejemplo, las tablas maestras mínimas (`usuario`, `deposito`, `lote`), las tablas descompuestas (`responsable_deposito`, `control_lote`) y la vista de compatibilidad `v_control_lote_almacen`.

Restricciones indicadas por el script:

* es de ejecución única y no es reejecutable;
* no incluye `DROP TABLE`, `TRUNCATE` ni limpieza de datos;
* no modifica `db/schema.sql`;
* no ajusta las secuencias de identidad;
* no debe ejecutarse sobre una base donde ya se ejecutó `db/tp6_descomposicion_fnbc.sql`;
* si algún objeto ya existe, debe detenerse la ejecución y revisar la base manualmente.

El script abre una transacción con `BEGIN` y la cierra con `COMMIT` al final de la Sección 8. Las verificaciones de la Sección 7 son de solo lectura.

#### `db/tp_desnormalizacion_top_categorias.sql`

Entregable oficial de la **Parte 2** y definición canónica. Consolida la estructura desnormalizada (`mv_ventas_categoria_dia`), el índice único, el mecanismo de sincronización, las verificaciones previas, la consulta desnormalizada y la auditoría de sincronización.

El script es autosuficiente: no es necesario ejecutar los auxiliares para crear la estructura, la consulta o la auditoría. No modifica `db/schema.sql`, no incluye `DROP`, `TRUNCATE` ni `DELETE` y no abre una transacción explícita.

### Scripts auxiliares

| Script | Uso | Advertencia |
|---|---|---|
| `db/tp6_descomposicion_fnbc.sql` | Alternativa para crear la estructura descompuesta sin datos de ejemplo. | No es entregable oficial. Crea las mismas tablas que la Parte 1; **no ejecutar sobre la misma base** donde se ejecutó `tp_fnbc_control_lote.sql`. |
| `db/tp6_vista_materializada_ventas.sql` | Alternativa para estructura, índice, consulta, verificaciones y notas de programación. | No es entregable oficial. La Parte 2 canónica ya consolida todo; no es necesario ejecutarlo. |
| `db/tp6_auditoria_ventas.sql` | Auditoría de solo lectura de la vista materializada. | No es entregable oficial. La Parte 2 ya incluye la auditoría; es opcional. Requiere que la vista esté poblada. |

## Ejecución segura del TP6

### Preparación común

* Usar una **copia descartable** de la base Food Store ya poblada, o un backup verificado.
* Base indicada por los scripts: `bd2_tp6`.
* Usar un cliente con detención ante error: `psql -v ON_ERROR_STOP=1` o DBeaver con la opción de detenerse en error.
* Configurar la contraseña en `%APPDATA%\postgresql\pgpass.conf`; no incrustarla en scripts ni en variables de entorno persistentes.
* No usar `DROP`, `TRUNCATE` ni `DELETE` para “limpiar” errores. Si una ejecución falla, restaurar la copia o hacer `ROLLBACK` cuando corresponda.

### Parte 1 — procedimiento recomendado por bloques

1. Confirmar que en `public` **no existen** `usuario`, `deposito`, `lote`, `control_lote_almacen`, `responsable_deposito`, `control_lote` ni `v_control_lote_almacen`.
2. Ejecutar el script desde la Sección 1 hasta la Sección 7.
3. Revisar las verificaciones de la Sección 7:
   * instancia original: `(501, 30, 801)`, `(502, 30, 801)`, `(503, 31, 802)`;
   * conteos: `control_lote` 3, `control_lote_almacen` 3, `responsable_deposito` 2, vista 3;
   * comparaciones `EXCEPT`: 0 diferencias.
4. Si todo coincide, ejecutar el `COMMIT` de la Sección 8.
5. Si hay discrepancias, ejecutar `ROLLBACK`.

Si alguna sentencia falla, hacer `ROLLBACK` si la transacción sigue abierta y revisar la causa antes de reintentar sobre una base limpia.

### Parte 1 — ejecución completa

La ejecución completa del archivo debe realizarse **únicamente sobre una copia descartable**, porque el `COMMIT` se ejecuta automáticamente después de las verificaciones, sin pausa para revisión:

```powershell
psql -v ON_ERROR_STOP=1 -U <usuario> -d bd2_tp6 -f db/tp_fnbc_control_lote.sql
```

### Parte 2

La Parte 2 requiere que las tablas de Food Store existan y estén pobladas. No debe envolverse en una transacción explícita `BEGIN ... COMMIT`.

```powershell
psql -v ON_ERROR_STOP=1 -U <usuario> -d bd2_tp6 -f db/tp_desnormalizacion_top_categorias.sql
```

Flujo del script:

1. Sección 0: fija `America/Argentina/Buenos_Aires` solo para la sesión de comparación.
2. Sección 1: crea `mv_ventas_categoria_dia` y el índice único.
3. Sección 3: verificaciones de solo lectura. La Sección 3.4 es una barrera `DO` que emite excepción si la vista no existe, no está poblada, la definición no coincide o falta el índice único válido.
4. Sección 4: consulta del top 5.
5. Sección 5: auditoría de solo lectura. Se espera que 5.1 no devuelva filas y que 5.2 devuelva `SIN_DISCREPANCIAS`.
6. Sección 6: diagnósticos opcionales.

Si falla la creación del índice, la vista materializada puede haber quedado creada. Revisar la Sección 3 antes de reintentar. `CREATE MATERIALIZED VIEW IF NOT EXISTS` y `CREATE UNIQUE INDEX IF NOT EXISTS` no actualizan definiciones preexistentes.

### Refresco de la vista materializada

El script no programa ni ejecuta el refresco. Si la vista está poblada y el índice único es válido:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_ventas_categoria_dia;
```

Si la vista está vacía o fue creada `WITH NO DATA`:

```sql
REFRESH MATERIALIZED VIEW public.mv_ventas_categoria_dia;
```

`REFRESH ... CONCURRENTLY` no debe ejecutarse dentro de un bloque de transacción explícito. PostgreSQL estándar no incluye un planificador nativo de refrescos; la frecuencia debe definirse con una herramienta externa o ejecutarse manualmente.

### Script auxiliar de auditoría

La auditoría auxiliar es de solo lectura y equivalente a la Sección 5 de la Parte 2. Requiere que la vista esté poblada:

```powershell
psql -U <usuario> -d bd2_tp6 -f db/tp6_auditoria_ventas.sql
```

## Verificaciones y resultados

### Parte 1

Los resultados documentados en `docs/tp6/informe_fnbc.md` son:

| Conjunto | Filas |
|---|---:|
| `control_lote` (R2) | 3 |
| `control_lote_almacen` | 3 |
| `responsable_deposito` (R1) | 2 |
| `v_control_lote_almacen` | 3 |

Las comparaciones de conjuntos entre `control_lote_almacen` y `v_control_lote_almacen` devolvieron **0 diferencias** en ambas direcciones.

### Parte 2 — auditoría

Los resultados documentados en `docs/tp6/informe_fnbc.md` son:

| Control | Resultado |
|---|---:|
| Grupos en las tablas originales (`grupos_base`) | 366 |
| Grupos en la vista materializada (`grupos_vista`) | 366 |
| Discrepancias | 0 |
| Estado del control | `SIN_DISCREPANCIAS` |
| Duplicados para `(fecha, categoria_id)` | 0 |
| Filas materializadas | 366 |
| Primera fecha materializada | 2025-10-25 |
| Última fecha materializada | 2026-10-25 |

La auditoría compara el estado actual de las tablas base con el estado actual de la vista. No reconstruye la historia ni detecta por sí sola reatribuciones históricas causadas por cambios en `producto.categoria_id`.

### Mediciones del TP6

| Métrica | Consulta original | Vista materializada |
|---|---:|---:|
| Planning Time | 0,475 ms | 0,102 ms |
| Execution Time | 58,419 ms | 0,036 ms |
| Buffers | `shared hit=4172` | `shared hit=5` |

Las mediciones de **58,419 ms** y **0,036 ms** son las documentadas en el informe y en las capturas de `docs/tp6/evidencias/`, con fecha fija `2026-10-25`. Corresponden a una sola ejecución, no a un promedio ni a un benchmark.

El script canónico `db/tp_desnormalizacion_top_categorias.sql` advierte sobre **41,965 ms** y **0,039 ms**, pero esos valores no están respaldados por el informe vigente ni por las capturas. Se dejan como referencias no conciliadas y no verificadas. No fue posible determinar su origen con los archivos actuales del repositorio.

Además, las mediciones no fueron revalidadas bajo la convención temporal de la Sección 0 del script canónico. Los tiempos y buffers dependen del entorno, del plan elegido, del volumen de datos y del estado de caché.

### Nodos dominantes de los planes

Criterio utilizado: se considera nodo dominante al nodo de acceso o de reunión que concentra el trabajo real del plan. No se toma como dominante a un nodo superior cuyo `actual time` es acumulado y que incluye el trabajo de todos sus hijos.

| Plan | Nodo dominante | Fundamento |
|---|---|---|
| Consulta original | `Parallel Hash Join`, con `Parallel Seq Scan` sobre `pedido` como acceso base más costoso | El `Parallel Hash Join` reúne `pedido` y `detalle_pedido`; el escaneo de `pedido` aplica el filtro de fecha y descarta 99.805 filas. Los `Sort`, `GroupAggregate`, `Nested Loop` y `Gather Merge` superiores tienen tiempos acumulados y no explican por sí solos el costo. |
| Vista materializada | `Nested Loop` con `Index Scan` sobre `mv_ventas_categoria_dia` y `categoria` | El acceso principal usa el índice único `uq_mv_ventas_categoria_dia_fecha_categoria`; el `Sort` final es despreciable. |

No se afirma un tiempo exclusivo exacto por nodo: las capturas no permiten separar con rigor los tiempos propios de cada nodo cuando hay paralelismo y múltiples `loops`. Para un cálculo exacto haría falta el `EXPLAIN` en texto o JSON completo.

## Limitaciones y alcance de los resultados

* El informe no identifica textualmente el nodo dominante de cada plan; la identificación anterior se deriva de las capturas.
* Las mediciones no fueron revalidadas bajo la convención temporal de la Sección 0 del script canónico.
* Existe una referencia no conciliada a 41,965 ms y 0,039 ms en el script canónico. No se modificó el script.
* La vista materializada puede quedar desactualizada entre refrescos; no es tiempo real estricto.
* No existe una declaración DUIA en `docs/tp6/`. Las DUIA conservadas corresponden a `docs/tp2/`, `docs/tp3/`, `docs/tp4/` y `docs/tp5/`.

## Documentación y evidencias

* Consigna: `docs/tp6/TP_U4_FNBC_Desnormalizacion_FoodStore.pdf`
* Informe: `docs/tp6/informe_fnbc.pdf` y `docs/tp6/informe_fnbc.md`
* Evidencias: `docs/tp6/evidencias/explain_original.png` y `docs/tp6/evidencias/explain_vista_materializada.png`
* TPI del primer parcial: `docs/tpi_parcial1/README.md` y `docs/tpi_parcial1/informe_tpi_parcial1.md`
* TP5: `docs/tp5/README.md` y `docs/tp5/informe_mediciones.md`
* Especificaciones históricas de TP5: `docs/tp5/especificaciones/`

## Recreación de la base de datos

Los scripts SQL versionados permiten reconstruir la base sin depender de los archivos de backup de `db/backups/`. La reconstrucción presupone una base vacía y los comandos deben ejecutarse desde la raíz del repositorio. `db/schema.sql` no crea la base: solo define los objetos dentro de una base existente.

### Preparación mínima para TP6 (`bd2_tp6`)

Para ejecutar la Parte 2 de TP6 hacen falta el esquema base y la carga de datos:

```powershell
createdb -U <usuario> bd2_tp6

psql -v ON_ERROR_STOP=1 -U <usuario> -d bd2_tp6 -f db/schema.sql
psql -v ON_ERROR_STOP=1 -U <usuario> -d bd2_tp6 -f db/generador_datos_tp3_carga.sql
```

Si `createdb` no está disponible en el `PATH`, se puede crear la base con:

```powershell
psql -U <usuario> -d postgres -c "CREATE DATABASE bd2_tp6;"
```

La Parte 1 es autocontenida y puede ejecutarse sobre una base vacía o sobre esta misma `bd2_tp6`; no requiere el esquema ni la carga de Food Store. No ejecutar `db/tp6_descomposicion_fnbc.sql` en la misma base donde ya se ejecutó `db/tp_fnbc_control_lote.sql`.

`db/indices.sql` y `db/views.sql` son opcionales para TP6 y no son dependencias de la Parte 2. Si se ejecutan, hacerlo después de la carga:

```powershell
psql -v ON_ERROR_STOP=1 -U <usuario> -d bd2_tp6 -f db/indices.sql
psql -v ON_ERROR_STOP=1 -U <usuario> -d bd2_tp6 -f db/views.sql
```

`db/views.sql` debe ejecutarse después de `db/generador_datos_tp3_carga.sql` para que su vista materializada se cree con datos.

### Preparación completa para TPI/TP5

La base completa del TPI/TP5 se reconstruye con el mismo esquema y la misma carga, agregando los índices y las vistas:

1. `db/schema.sql`
2. `db/generador_datos_tp3_carga.sql`
3. `db/indices.sql`
4. `db/views.sql`

La base `bd2_tpi_parcial1` debe permanecer intacta. No ejecutar sobre ella los scripts de TP6 ni usarla como entorno de pruebas destructivo. Para TP6 usar `bd2_tp6`.

### Advertencias de reconstrucción

* `db/schema.sql`, `db/indices.sql` y `db/views.sql` no son idempotentes: deben ejecutarse una sola vez sobre una base vacía. Si una ejecución falla a mitad de camino, recrear la base en lugar de borrar objetos manualmente.
* El generador crea el estado inicial mínimo y luego la carga masiva. Si detecta filas adicionales o un estado incompatible, aborta; no es reejecutable después de completada.
* El generador produce una sola categoría (`id_categoria = 3`, `Bebidas`) y asigna todas las ventas a esa categoría. Por eso la consulta de top 5 devuelve como máximo una fila.
* Las fechas del generador se calculan con `now()`, por lo que los valores y las fechas documentados dependen del momento de ejecución y no se reproducen de forma idéntica en otra fecha.
* El archivo `db/generador_datos_tp3.sql` es una variante de prueba en seco que termina en `ROLLBACK`. No debe usarse sobre una base que se quiera conservar, porque `ROLLBACK` no reinicia las secuencias de identidad y los triggers diferidos no se validan hasta un `COMMIT`.
* El archivo `db/tpi_parcial1_pruebas.sql` contiene las pruebas de verificación y no forma parte de la construcción de la base.
* Los archivos `.dump` de `db/backups/` se mantienen como respaldos locales y no forman parte del control de versiones.

## Reproducción de las pruebas del TPI y TP5

Para consultar el procedimiento específico de reproducción de las pruebas del TP5:

```text
docs/tp5/README.md
```

Para consultar las pruebas correspondientes a la primera entrega parcial:

```text
db/tpi_parcial1_pruebas.sql
```

El informe integrado de la entrega se encuentra en:

```text
docs/tpi_parcial1/informe_tpi_parcial1.md
```

## Uso de herramientas de IA

Durante el desarrollo se utilizaron herramientas de IA como apoyo para:

* especificación de requisitos;
* generación de alternativas;
* implementación de soluciones;
* revisión técnica;
* análisis de consultas e índices.

Principalmente se utilizaron **Kiro** para la elaboración de especificaciones y **OpenCode** para generar implementaciones a partir de dichas especificaciones.

Las propuestas generadas fueron revisadas y verificadas mediante ejecución controlada en PostgreSQL. Las decisiones de aceptar, modificar o rechazar soluciones se basaron en los requisitos del proyecto y en evidencia reproducible.

Las declaraciones de uso de IA (DUIA) se conservan en las carpetas correspondientes de `docs/tp2/`, `docs/tp3/`, `docs/tp4/` y `docs/tp5/`.

## Historial del desarrollo

El repositorio conserva el historial de los trabajos prácticos y de la consolidación del TPI mediante Git.

La rama:

```text
tpi-parcial1
```

contiene la integración de las evidencias de TP1 junto con los resultados y documentación desarrollados hasta TP5.

La rama:

```text
tp6-fnbc-desnormalizacion
```

contiene el desarrollo del TP6 (FNBC y desnormalización controlada).
