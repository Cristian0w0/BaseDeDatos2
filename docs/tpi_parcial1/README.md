# Base de Datos 2 — Food Store

Repositorio del proyecto integrador **«Food Store»** desarrollado para la asignatura **Base de Datos II**.

El proyecto reúne el trabajo realizado durante los distintos trabajos prácticos de la materia y consolida los contenidos correspondientes a las unidades 1, 2 y 3 en la primera entrega parcial del Trabajo Práctico Integrador (TPI).

> Documento histórico de la primera entrega parcial. Para el estado actual del repositorio y el TP6, ver el [README principal](../../README.md).

## Estado de la entrega

Este documento describe la **primera entrega parcial del TPI**, correspondiente a:

1. Integridad, transacciones y concurrencia.
2. Optimización de consultas.
3. Índices, vistas y objetos programables del motor.

La entrega documenta el cumplimiento de los nueve objetivos establecidos por la cátedra y conserva las evidencias de los trabajos prácticos anteriores.

**Rama de la primera entrega:** `tpi-parcial1`

**Motor utilizado:** PostgreSQL 17.11

**Lenguaje de procedimientos:** PL/pgSQL

## Objetivos cubiertos

La primera entrega parcial documenta los siguientes objetivos:

1. Modelo entidad-relación.
2. Transformación del modelo ER al modelo relacional.
3. Normalización hasta 3FN/BCNF.
4. DDL completo con tipos, claves, restricciones e índices.
5. DML y consultas con JOIN, agregaciones, subconsultas, GROUP BY, HAVING y funciones de ventana.
6. Vistas, funciones y procedimientos almacenados.
7. Reglas de negocio mediante CHECK, UNIQUE y triggers.
8. Transacciones, niveles de aislamiento y concurrencia.
9. Borrado lógico y su impacto sobre consultas e índices.

## Estructura del repositorio en la primera entrega parcial

La siguiente estructura muestra la organización del repositorio en la primera entrega parcial, desde la raíz. El árbol es histórico y no incluye el TP6. En el estado actual, este README se encuentra en `docs/tpi_parcial1/README.md`.

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
│   └── backups/
│
├── docs/
│   ├── tp1/
│   ├── tp2/
│   ├── tp3/
│   ├── tp4/
│   ├── tp5/
│   │   └── README.md
│   └── tpi_parcial1/
│       └── informe_tpi_parcial1.md
│
├── specs/
│   └── especificaciones utilizadas durante TP5
│
└── README.md
```

## Base de datos

La base de datos utilizada para las pruebas de la primera entrega parcial es:

```text
bd2_tpi_parcial1
```

Se trata de una base de trabajo independiente utilizada para verificar los elementos incorporados al TPI, tomando como base el estado alcanzado durante el TP5.

El esquema principal se encuentra en:

```text
../../db/schema.sql
```

Este archivo contiene las tablas, tipos, claves, restricciones, triggers, funciones y el procedimiento almacenado `sp_desactivar_producto`.

## Scripts principales

### `../../db/schema.sql`

Contiene el esquema principal de Food Store, incluyendo:

* tablas y relaciones;
* claves primarias y foráneas;
* restricciones `CHECK` y `UNIQUE`;
* tipo `ENUM` para `forma_pago`;
* columnas `IDENTITY`;
* columnas `TIMESTAMPTZ`;
* triggers y funciones PL/pgSQL;
* procedimiento `sp_desactivar_producto`.

### `../../db/generador_datos_tp3_carga.sql`

Contiene la carga masiva de datos y el estado inicial mínimo requerido para reproducir la base:

* crea 1 categoría (`id_categoria = 3`, `Bebidas`), 1 cliente, 1 producto, 1 pedido y 1 detalle;
* inserta 19.999 clientes, 49.999 productos, 199.999 pedidos y 199.999 detalles adicionales;
* deja los totales en 1 categoría, 20.000 clientes, 50.000 productos, 200.000 pedidos y 200.000 detalles;
* requiere una base recién creada con `../../db/schema.sql` o exactamente el estado inicial anterior;
* aborta si detecta filas adicionales o un estado incompatible;
* no es reejecutable después de completar la carga;
* termina en `COMMIT` y sus aserciones finales abortan la carga si los conteos o las validaciones 4.1–4.8 no se cumplen.

### `../../db/generador_datos_tp3.sql`

Es la variante de prueba en seco del generador. Conserva la misma carga y las mismas aserciones, pero termina en `ROLLBACK`.

`ROLLBACK` revierte los cambios transaccionales, pero no reinicia las secuencias de identidad. Después de un dry-run, los IDs de una carga posterior pueden quedar desplazados. Tampoco valida los triggers diferidos, porque estos se disparan al hacer `COMMIT`. No debe ejecutarse sobre `bd2_tpi_parcial1` ni sobre una base que se quiera conservar; usar una base descartable.

### `../../db/indices.sql`

Contiene los índices adicionales incorporados después del análisis del workload:

* `idx_pedido_tarjeta_fecha`;
* `idx_producto_activo_precio`.

### `../../db/views.sql`

Contiene las vistas convencionales y la vista materializada:

* `v_productos_vigentes`;
* `v_pedidos_con_cliente`;
* `v_detalle_pedido_con_producto`;
* `v_resumen_gasto_cliente`.

### `../../db/tpi_parcial1_pruebas.sql`

Contiene pruebas reproducibles correspondientes a la primera entrega parcial, incluyendo:

* procedimiento y borrado lógico;
* reglas de negocio;
* restricciones de integridad;
* vistas;
* índices;
* transacciones;
* versión de PostgreSQL;
* consulta representativa con JOIN, agregación, GROUP BY, HAVING y RANK.

## Documentación

La documentación histórica de los trabajos prácticos se conserva organizada por etapa:

* `../tp1/` — modelo ER, normalización e informe del TP1.
* `../tp2/` — integridad, transacciones y concurrencia.
* `../tp3/` — optimización y análisis de consultas.
* `../tp4/` — consultas, joins, especificaciones y competencia.
* `../tp5/` — índices, vistas, mediciones y reproducción de las pruebas del TP5.
* `./` — informe integrado de la primera entrega parcial.

El README específico del TP5 se encuentra en:

```text
../tp5/README.md
```

## Optimización y mediciones

Las principales mejoras verificadas durante TP5 fueron:

| Caso                         |      Antes |   Después |
| ---------------------------- | ---------: | --------: |
| Pedidos con `TARJETA`        |  18,877 ms | 17,588 ms |
| Productos activos por precio |  10,446 ms |  0,150 ms |
| Resumen de gasto por cliente | 207,512 ms | 20,341 ms |

Las mediciones fueron obtenidas mediante `EXPLAIN (ANALYZE, BUFFERS)` y corresponden a ejecuciones concretas sobre la base utilizada durante el desarrollo.

La documentación detallada se encuentra en:

```text
../tp5/informe_mediciones.md
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

Las declaraciones de uso de IA (DUIA) se conservan en las carpetas correspondientes de `../tp2/`, `../tp3/`, `../tp4/` y `../tp5/`.

## Reproducción de la base de datos

La base de datos de la primera entrega parcial puede reconstruirse utilizando los scripts SQL versionados del repositorio, sin depender de los archivos de backup ubicados en `../../db/backups/`.

Orden de ejecución:

1. `../../db/schema.sql`
2. `../../db/generador_datos_tp3_carga.sql`
3. `../../db/indices.sql`
4. `../../db/views.sql`

La reconstrucción presupone una base vacía. El generador crea el estado inicial mínimo y luego la carga masiva. Si detecta filas adicionales o un estado incompatible, aborta; no es reejecutable después de completada.

El archivo `../../db/generador_datos_tp3.sql` es una variante de prueba en seco que termina en `ROLLBACK`. No debe usarse sobre una base que se quiera conservar, porque `ROLLBACK` no reinicia las secuencias de identidad y los triggers diferidos no se validan hasta un `COMMIT`.

El archivo `../../db/tpi_parcial1_pruebas.sql` contiene las pruebas de verificación y no forma parte de la construcción de la base.

Los archivos `.dump` de `../../db/backups/` se mantienen como respaldos locales y no forman parte del control de versiones.

## Reproducción de las pruebas

Para consultar el procedimiento específico de reproducción de las pruebas del TP5:

```text
../tp5/README.md
```

Para consultar las pruebas correspondientes a la primera entrega parcial:

```text
../../db/tpi_parcial1_pruebas.sql
```

El informe integrado de la entrega se encuentra en:

```text
informe_tpi_parcial1.md
```

## Historial del desarrollo

El repositorio conserva el historial de los trabajos prácticos y de la consolidación del TPI mediante Git.

La rama:

```text
tpi-parcial1
```

contiene la integración de las evidencias de TP1 junto con los resultados y documentación desarrollados hasta TP5.
