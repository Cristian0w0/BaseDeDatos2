# Trabajo Práctico Integrador — Primera entrega parcial

## 1. Introducción y alcance

El presente informe documenta el estado del proyecto integrador **«Food Store»** correspondiente a la primera entrega parcial del Trabajo Práctico Integrador (TPI) de la asignatura Base de Datos II.

Esta entrega reúne y consolida los avances desarrollados durante los trabajos prácticos anteriores y las actividades correspondientes a las unidades 1, 2 y 3 de la materia. El objetivo es presentar de manera integrada los elementos implementados en el modelo de datos, los scripts SQL, los objetos de base de datos y las pruebas realizadas sobre PostgreSQL.

La entrega abarca los contenidos relacionados con:

* integridad, transacciones y concurrencia;
* optimización de consultas;
* índices, vistas y objetos programables del motor.

Además de documentar los avances por unidad, el informe verifica explícitamente la cobertura de los nueve objetivos establecidos por la cátedra para esta primera entrega. Para cada objetivo se indica el elemento implementado y la evidencia disponible en el repositorio, ya sea mediante scripts SQL, consultas de prueba, documentación o resultados de ejecución.

El trabajo se desarrolló utilizando **PostgreSQL 17.11**, compatible con el requisito de PostgreSQL 16 o superior, y PL/pgSQL para las funciones, triggers y procedimientos almacenados.

La base de datos utilizada específicamente para las pruebas de esta entrega es `bd2_tpi_parcial1`, creada como copia de trabajo de la base utilizada durante TP5. De esta manera se conservaron los resultados de TP5 y se dispuso de una base independiente para incorporar y verificar los elementos específicos de la primera entrega parcial.

## 2. Descripción general del proyecto

El proyecto integrador **«Food Store»** consiste en el diseño e implementación de una base de datos para gestionar información relacionada con categorías, productos, clientes y pedidos.

El modelo contempla las principales relaciones del dominio: una categoría puede contener múltiples productos, un cliente puede realizar múltiples pedidos y cada pedido puede incluir múltiples productos. La relación entre pedidos y productos se resuelve mediante la tabla `detalle_pedido`, que además almacena la cantidad solicitada y el precio unitario correspondiente a cada producto dentro del pedido.

El desarrollo del proyecto se realizó de manera incremental a través de los distintos trabajos prácticos de la asignatura. En las primeras etapas se construyeron el modelo entidad-relación, el modelo relacional y la justificación de la normalización. Posteriormente se incorporaron las restricciones de integridad, las consultas SQL, las pruebas de transacciones y concurrencia, el análisis y optimización de consultas, y finalmente los índices, vistas y objetos programables del motor.

El esquema actual se encuentra centralizado en `db/schema.sql`, mientras que las consultas, índices, vistas, generadores de datos y pruebas específicas se mantienen en scripts separados. La documentación de los distintos trabajos prácticos se conserva dentro de `docs/`, permitiendo mantener la trazabilidad de las decisiones y resultados obtenidos durante el desarrollo.

Para esta primera entrega parcial se consolidaron estos avances en la rama `tpi-entrega-parcial`, incorporando además las evidencias del TP1, el procedimiento almacenado para el borrado lógico de productos y el script `db/tpi_parcial1_pruebas.sql`, destinado a reproducir las principales verificaciones de la entrega.

## 3. Elementos implementados por unidad

### 3.1. Unidad 1 — Integridad, transacciones y concurrencia

Durante esta etapa se trabajó sobre la integridad de los datos y el comportamiento de las transacciones en PostgreSQL.

Se implementaron y verificaron restricciones de integridad mediante claves primarias, claves foráneas, restricciones `CHECK`, restricciones `UNIQUE` y reglas de negocio mediante triggers.

También se trabajó con transacciones utilizando `BEGIN`, `COMMIT` y `ROLLBACK`, analizando la atomicidad de las operaciones y el comportamiento de distintos niveles de aislamiento.

En relación con la concurrencia, se realizaron pruebas utilizando sesiones independientes para observar situaciones de lectura no repetible, aparición de filas adicionales en consultas sucesivas y espera por bloqueo mediante `SELECT ... FOR UPDATE`. Se compararon los comportamientos de `READ COMMITTED` y `REPEATABLE READ`.

La implementación correspondiente se encuentra principalmente en `db/schema.sql`, mientras que las pruebas y el análisis de concurrencia desarrollados durante esta etapa se documentan en `docs/tp2/informe_concurrencia.md`.

### 3.2. Unidad 2 — Optimización de consultas

En esta etapa se trabajó sobre el análisis del comportamiento de consultas y la optimización mediante el estudio de planes de ejecución.

Se utilizaron consultas `EXPLAIN (ANALYZE, BUFFERS)` para comparar planes y tiempos de ejecución antes y después de incorporar estrategias de optimización.

También se analizaron propuestas de índices generadas a partir del workload del proyecto, diferenciando entre aquellas que aportaban una mejora verificable y aquellas que no justificaban su incorporación.

Las experiencias de optimización desarrolladas durante TP3 y TP4 se encuentran documentadas en los archivos correspondientes dentro de `docs/tp3/` y `docs/tp4/`.

### 3.3. Unidad 3 — Índices, vistas y objetos programables

En esta etapa se incorporaron y evaluaron índices, vistas y objetos programables de PostgreSQL.

Se implementaron índices parciales orientados a consultas concretas del workload:

* `idx_pedido_tarjeta_fecha`, sobre `pedido`;
* `idx_producto_activo_precio`, sobre `producto`.

Además, se implementaron tres vistas convencionales:

* `v_productos_vigentes`;
* `v_pedidos_con_cliente`;
* `v_detalle_pedido_con_producto`.

También se implementó la vista materializada `v_resumen_gasto_cliente`, utilizada para materializar el resumen de gasto por cliente y reducir el costo de una consulta analítica repetitiva.

Dentro de los objetos programables se incorporaron funciones PL/pgSQL utilizadas por las reglas de integridad mediante triggers y el procedimiento almacenado `sp_desactivar_producto`, destinado a realizar el borrado lógico de productos.

La definición de los índices se encuentra en `db/indices.sql`, las vistas en `db/views.sql` y el procedimiento almacenado en `db/schema.sql`. Las mediciones y decisiones tomadas durante TP5 se documentan en `docs/tp5/informe_mediciones.md`.

## 4. Cobertura de los nueve objetivos de la entrega

La primera entrega parcial debe acreditar el cumplimiento verificable de nueve objetivos establecidos por la cátedra. A continuación se detalla cómo se encuentra cubierto cada uno de ellos en el proyecto.

### 4.1. Objetivo 1 — Modelo entidad-relación

El proyecto cuenta con un modelo entidad-relación correspondiente al dominio de Food Store, donde se identifican las entidades, sus atributos, claves, cardinalidades y participación en las relaciones.

El modelo fue desarrollado durante el TP1 y se conserva en:

* `docs/tp1/modelo_er.drawio`
* `docs/tp1/modelo_er.svg`
* `docs/tp1/informe_tp1.pdf`

El modelo contempla, entre otras, las entidades `categoria`, `producto`, `cliente`, `pedido` y `detalle_pedido`.

### 4.2. Objetivo 2 — Paso del modelo ER al modelo relacional

El modelo entidad-relación fue transformado al modelo relacional, definiendo las tablas, claves primarias y claves foráneas correspondientes.

Las relaciones 1:N se representan mediante claves foráneas, como la relación entre `categoria` y `producto` y entre `cliente` y `pedido`.

La relación N:M entre pedidos y productos se resuelve mediante la tabla intermedia `detalle_pedido`, que contiene las referencias a ambas entidades y los atributos propios de la relación, como `cantidad` y `precio_unitario`.

La documentación de esta transformación se encuentra en `docs/tp1/informe_tp1.pdf`.

### 4.3. Objetivo 3 — Normalización hasta 3FN/BCNF

Durante el TP1 se realizó el análisis de dependencias funcionales y la normalización de la relación de origen hasta 3FN y BCNF.

Se identificaron las dependencias funcionales correspondientes y se justificó la separación de las relaciones para evitar dependencias parciales y transitivas.

El resultado fue contrastado con el modelo entidad-relación definitivo, considerando las diferencias entre la estructura de la planilla utilizada como fuente del ejercicio de normalización y el modelo final de Food Store.

La fundamentación se encuentra documentada en `docs/tp1/informe_tp1.pdf`.

### 4.4. Objetivo 4 — DDL completo

El esquema de la base de datos se encuentra definido principalmente en `db/schema.sql`.

Se implementaron:

* tipos de datos apropiados para cada atributo;
* tipo `ENUM` para `forma_pago`;
* columnas `IDENTITY`;
* columnas `TIMESTAMPTZ`;
* claves primarias;
* claves foráneas;
* restricciones `NOT NULL`;
* restricciones `CHECK`;
* restricciones `UNIQUE`;
* índices.

Los índices adicionales incorporados como resultado del análisis de workload se encuentran en `db/indices.sql`.

El esquema fue probado sobre PostgreSQL 17.11, cumpliendo el requisito de utilizar PostgreSQL 16 o superior.

### 4.5. Objetivo 5 — DML y consultas

El proyecto contiene consultas que utilizan diferentes recursos de SQL, incluyendo:

* `JOIN`;
* funciones de agregación;
* `GROUP BY`;
* `HAVING`;
* subconsultas;
* CTE;
* funciones de ventana.

Las consultas desarrolladas durante TP3 y TP4 se conservan principalmente en:

* `db/consultas_tp4_parte3.sql`;
* `db/generador_datos_tp3.sql`;
* `db/generador_datos_tp3_carga.sql`.

Además, `db/tpi_parcial1_pruebas.sql` contiene una consulta representativa que combina `JOIN`, agregación, `GROUP BY`, `HAVING` y la función de ventana `RANK()`.

### 4.6. Objetivo 6 — Vistas, funciones y procedimientos almacenados

El proyecto cuenta con vistas convencionales y una vista materializada definidas en `db/views.sql`:

* `v_productos_vigentes`;
* `v_pedidos_con_cliente`;
* `v_detalle_pedido_con_producto`;
* `v_resumen_gasto_cliente`.

También se utilizan funciones PL/pgSQL asociadas a reglas de integridad mediante triggers.

Para esta primera entrega se incorporó el procedimiento almacenado `sp_desactivar_producto`, definido en `db/schema.sql` y ejecutado mediante `CALL`.

El procedimiento implementa el borrado lógico de un producto modificando su atributo `activo`, sin eliminar físicamente el registro.

### 4.7. Objetivo 7 — Reglas de negocio mediante CHECK, UNIQUE y triggers

El esquema implementa reglas de integridad mediante distintos mecanismos de PostgreSQL.

Entre ellas se encuentran:

* `ck_producto_precio_no_negativo`, que impide precios negativos;
* `ck_producto_stock_no_negativo`, que impide stock negativo;
* `ck_detalle_cantidad_positiva`, que exige cantidades mayores que cero;
* `ck_detalle_precio_no_negativo`, que impide precios unitarios negativos;
* restricciones `UNIQUE` sobre atributos como `cliente.email` y `categoria.nombre`;
* `uq_producto_categoria_nombre`, que evita productos duplicados dentro de una misma categoría.

Además, se implementaron triggers diferibles para garantizar que un pedido no pueda quedar sin detalles. La regla se valida al finalizar la transacción cuando corresponde, utilizando `DEFERRABLE INITIALLY DEFERRED`.

Las definiciones se encuentran en `db/schema.sql` y las pruebas correspondientes se incluyen en `db/tpi_parcial1_pruebas.sql`.

### 4.8. Objetivo 8 — Transacciones, niveles de aislamiento y concurrencia

Se realizaron pruebas de transacciones utilizando `BEGIN`, `COMMIT` y `ROLLBACK`, verificando que las operaciones puedan confirmarse o revertirse de manera atómica.

También se analizaron los niveles de aislamiento `READ COMMITTED` y `REPEATABLE READ` mediante sesiones concurrentes de PostgreSQL.

Las pruebas permitieron observar diferencias en el comportamiento de lecturas sucesivas y situaciones de concurrencia, además de analizar la espera producida por bloqueos mediante `SELECT ... FOR UPDATE`.

La documentación de estas pruebas se encuentra en `docs/tp2/informe_concurrencia.md`.

Adicionalmente, `db/tpi_parcial1_pruebas.sql` incluye una prueba reproducible de `ROLLBACK` sobre una modificación de stock.

### 4.9. Objetivo 9 — Borrado lógico y su impacto

El modelo utiliza el atributo `activo` para representar el estado lógico de los productos sin eliminar físicamente sus registros.

El procedimiento `sp_desactivar_producto` establece `activo = FALSE` para el producto indicado. De esta manera se conserva la información histórica relacionada con pedidos anteriores.

El impacto del borrado lógico sobre las consultas se encuentra contemplado en `v_productos_vigentes`, que solamente expone productos con `activo = TRUE`.

Al mismo tiempo, `v_detalle_pedido_con_producto` no filtra por `activo`, permitiendo conservar el historial de productos utilizados en pedidos aunque posteriormente hayan sido desactivados.

El índice parcial `idx_producto_activo_precio` también se encuentra definido considerando el estado activo del producto, vinculando el diseño del soft delete con la estrategia de indexación.

El procedimiento, las vistas y el índice se encuentran en `db/schema.sql`, `db/views.sql` y `db/indices.sql`, respectivamente.

## 5. Pruebas realizadas y resultados

Las pruebas de esta entrega se realizaron sobre la base de datos `bd2_tpi_parcial1`, utilizando PostgreSQL 17.11 y DBeaver. Se utilizaron consultas SQL, transacciones controladas, sesiones concurrentes y análisis de planes de ejecución según el tipo de funcionalidad evaluada.

### 5.1. Procedimiento almacenado y borrado lógico

Se probó el procedimiento `sp_desactivar_producto` dentro de una transacción.

Para la prueba se utilizó un producto existente. Luego de ejecutar `CALL sp_desactivar_producto(5)`, el producto permaneció almacenado físicamente pero su atributo `activo` pasó a `FALSE`.

A continuación, la consulta sobre `v_productos_vigentes` dejó de devolver el producto desactivado. Finalmente se ejecutó `ROLLBACK`, comprobándose que el producto volvía a quedar activo.

El resultado permitió verificar tanto el funcionamiento del procedimiento como el efecto del borrado lógico sobre las consultas.

### 5.2. Regla de negocio sobre los pedidos

Se verificó el trigger `trg_validar_pedido_con_detalle`, configurado como `DEFERRABLE INITIALLY DEFERRED`.

Se inició una transacción y se intentó crear un pedido sin ningún detalle. La inserción fue aceptada inicialmente, pero el `COMMIT` produjo la excepción:

> `El pedido 400001 debe contener al menos un detalle.`

La transacción fue posteriormente revertida mediante `ROLLBACK`.

Esto permitió comprobar que la regla de negocio se evalúa al finalizar la transacción, evitando que quede persistido un pedido sin detalles.

### 5.3. Restricciones de integridad

Se probaron individualmente diferentes restricciones definidas en el esquema.

Los resultados fueron:

| Restricción           | Prueba                                                   | Resultado |
| --------------------- | -------------------------------------------------------- | --------- |
| `CHECK` de precio     | Intento de insertar un producto con precio `-1`          | Rechazado |
| `CHECK` de stock      | Intento de insertar un producto con stock `-1`           | Rechazado |
| `UNIQUE` de categoría | Intento de duplicar el nombre de una categoría existente | Rechazado |
| `FOREIGN KEY`         | Intento de utilizar una categoría inexistente            | Rechazado |

Las cuatro operaciones generaron las correspondientes excepciones de PostgreSQL y no produjeron modificaciones permanentes en la base de datos.

### 5.4. Vistas

Se verificó la existencia y el contenido de las vistas implementadas.

Los conteos obtenidos fueron:

| Vista                           | Registros verificados |
| ------------------------------- | --------------------: |
| `v_productos_vigentes`          |                46.667 |
| `v_pedidos_con_cliente`         |               200.000 |
| `v_detalle_pedido_con_producto` |               200.000 |
| `v_resumen_gasto_cliente`       |                20.000 |

También se verificó la existencia del índice único `idx_v_resumen_gasto_cliente_cliente` sobre la vista materializada, requerido para realizar `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

Las vistas convencionales fueron además comparadas con sus consultas equivalentes durante TP5, obteniéndose diferencias de cero registros mediante consultas con `EXCEPT` en ambas direcciones.

### 5.5. Índices

Se verificó mediante el catálogo `pg_indexes` la existencia de los índices incorporados durante TP5, entre ellos:

* `idx_pedido_tarjeta_fecha`;
* `idx_producto_activo_precio`.

También se comprobó el inventario completo de índices del esquema público, incluyendo los índices asociados a claves primarias y restricciones `UNIQUE`.

### 5.6. Transacciones

Se realizó una prueba controlada de `ROLLBACK` sobre el stock de un producto.

Dentro de una transacción, el stock del producto 5 pasó temporalmente de `10` a `11`. Luego de ejecutar `ROLLBACK`, el valor volvió a `10`.

Esto permitió verificar que la modificación no confirmada no permanece en la base de datos.

### 5.7. Concurrencia y niveles de aislamiento

Durante TP2 se realizaron pruebas con dos sesiones independientes de PostgreSQL.

Con `READ COMMITTED` se observó que una segunda lectura podía visualizar una modificación confirmada por otra transacción entre ambas lecturas. Con `REPEATABLE READ`, las lecturas sucesivas mantuvieron la misma visión de los datos correspondiente al snapshot de la transacción.

También se verificó el comportamiento de bloqueos mediante `SELECT ... FOR UPDATE`, observándose la espera de una segunda sesión hasta que la primera transacción liberó el bloqueo mediante `COMMIT`.

Los resultados completos se encuentran documentados en `docs/tp2/informe_concurrencia.md`.

### 5.8. Consultas del proyecto

Se ejecutó una consulta representativa que combina `JOIN`, funciones de agregación, `GROUP BY`, `HAVING` y la función de ventana `RANK()`.

La consulta devolvió 10 registros como resultado del `LIMIT 10`, mostrando correctamente la cantidad de pedidos, el gasto total y la posición del cliente dentro del ranking.

Las consultas desarrolladas durante TP3 y TP4 se mantienen en los scripts correspondientes y constituyen la base de las pruebas y análisis realizados durante las etapas posteriores.

### 5.9. Verificación del motor

Se ejecutó `SELECT version()` sobre la base utilizada para la entrega, obteniéndose:

`PostgreSQL 17.11 on x86_64-windows, compiled by msvc-19.44.35228, 64-bit`

El resultado confirma el cumplimiento del requisito de utilizar PostgreSQL 16 o superior.

## 6. Optimización de consultas y mediciones

La optimización se realizó a partir del análisis del workload del proyecto y de la comparación de planes de ejecución mediante `EXPLAIN (ANALYZE, BUFFERS)`.

Las decisiones de incorporación de índices se tomaron a partir de la evidencia obtenida en las mediciones y no únicamente por la existencia de una condición de filtrado en las consultas.

### 6.1. Índice parcial sobre pedidos con pago mediante tarjeta

Se analizó la siguiente consulta:

```sql
SELECT
    p.id_pedido,
    p.cliente_id,
    p.fecha_pedido,
    p.forma_pago
FROM pedido p
WHERE p.fecha_pedido >= TIMESTAMPTZ '2026-01-01'
  AND p.forma_pago = 'TARJETA'
ORDER BY p.fecha_pedido DESC;
```

Sin el índice adicional, el plan utilizaba un `Seq Scan` sobre `pedido`, recorriendo aproximadamente 200.000 registros y posteriormente realizando una operación de ordenamiento.

La medición obtenida fue:

* Tiempo de ejecución: **18,877 ms**
* Buffers: **1472 hits**

Luego se incorporó el índice parcial:

```sql
CREATE INDEX idx_pedido_tarjeta_fecha
    ON pedido (fecha_pedido DESC)
    WHERE forma_pago = 'TARJETA';
```

Con el índice, el plan pasó a utilizar `Bitmap Index Scan` y `Bitmap Heap Scan`.

La medición obtenida fue:

* Tiempo de ejecución: **17,588 ms**
* Buffers: **1470 hits + 130 reads**

La diferencia fue de aproximadamente **1,289 ms**, equivalente a una reducción cercana al **6,8 %** en esa ejecución.

La mejora fue moderada para esta variante de la consulta porque todavía fue necesario realizar el ordenamiento de los resultados.

También se evaluó una variante con `LIMIT 100`, en la que PostgreSQL pudo utilizar un `Index Scan` y evitar el ordenamiento, obteniéndose aproximadamente **0,129 ms** de ejecución. Esta medición corresponde a una consulta diferente y por ese motivo no se utilizó como comparación directa con la consulta sin `LIMIT`.

### 6.2. Índice parcial sobre productos activos ordenados por precio

Se analizó la consulta:

```sql
SELECT
    p.id_producto,
    p.nombre,
    p.precio,
    p.stock
FROM producto p
WHERE p.activo = TRUE
ORDER BY p.precio DESC
LIMIT 100;
```

Sin el índice adicional, PostgreSQL realizó un `Seq Scan` sobre los 50.000 productos y posteriormente utilizó un `top-N heapsort`.

La medición inicial fue:

* Tiempo de ejecución: **10,446 ms**
* Registros recorridos: **50.000**

Se incorporó el índice:

```sql
CREATE INDEX idx_producto_activo_precio
    ON producto (precio DESC)
    WHERE activo = TRUE;
```

Después de incorporar el índice, el plan pasó a utilizar un `Index Scan`, eliminando la necesidad de realizar el ordenamiento.

La medición obtenida fue:

* Tiempo de ejecución: **0,150 ms**
* Buffers: **100 hits + 2 reads**

La diferencia representa una reducción aproximada del **98,6 %** respecto de la ejecución inicial.

Este caso mostró un beneficio especialmente claro debido a que el índice parcial coincide con el filtro `activo = TRUE` y además proporciona el orden requerido por la consulta.

### 6.3. Propuesta de índice rechazada

Durante el análisis también se evaluó una propuesta de índice sobre `producto`:

```sql
CREATE INDEX idx_producto_activo_id
    ON producto (id_producto)
    WHERE activo = TRUE;
```

La propuesta fue descartada después de analizar su utilidad.

El atributo `id_producto` ya posee un índice asociado a la clave primaria y la condición `activo = TRUE` presenta una selectividad baja, ya que aproximadamente el **93,3 %** de los productos se encontraba activo.

Además, la consulta analizada era un JOIN masivo entre `detalle_pedido` y `producto`, para el cual PostgreSQL seleccionaba un `Hash Join` y recorridos secuenciales.

Al realizar una prueba experimental con el índice, el plan no cambió de manera significativa. Por este motivo el índice fue eliminado y no forma parte de la implementación definitiva.

Este caso se utilizó como criterio de decisión para evitar agregar índices sin una mejora verificable.

### 6.4. Vista materializada para el resumen de gasto por cliente

También se optimizó una consulta analítica que calcula el gasto total por cliente y su posición en un ranking.

La consulta original realizaba JOIN entre `cliente`, `pedido` y `detalle_pedido`, además de agrupación, ordenamiento y función de ventana.

La medición de la consulta original fue:

* Tiempo de ejecución: **207,512 ms**
* Tiempo de planificación: **5,101 ms**
* Buffers: **3660 hits**
* Uso de espacio temporal durante la ejecución.

Se implementó la vista materializada:

```sql
CREATE MATERIALIZED VIEW v_resumen_gasto_cliente AS
SELECT
    c.id_cliente,
    c.nombre || ' ' || c.apellido AS nombre_completo,
    SUM(dp.cantidad * dp.precio_unitario) AS gasto_total
FROM cliente c
INNER JOIN pedido p ON p.cliente_id = c.id_cliente
INNER JOIN detalle_pedido dp ON dp.pedido_id = p.id_pedido
GROUP BY c.id_cliente, c.nombre, c.apellido
WITH DATA;
```

La consulta equivalente sobre la vista materializada obtuvo:

* Tiempo de ejecución: **20,341 ms**
* Tiempo de planificación: **0,061 ms**
* Buffers: **150 hits**

La diferencia fue de aproximadamente **187,171 ms**, equivalente a una reducción cercana al **90,2 %** del tiempo de ejecución medido.

La vista materializada contiene **20.000 registros** y posee un índice único sobre `id_cliente`, lo que permite utilizar `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

Se consideró una frecuencia de actualización periódica, aproximadamente horaria, aceptando que el resumen pueda presentar un nivel de desactualización de hasta el intervalo definido entre actualizaciones. La actualización concurrente permite mantener la vista disponible para lecturas durante el proceso de refresh, aunque no constituye un mecanismo de actualización incremental.

### 6.5. Resumen de mediciones

| Caso                         |      Antes |   Después | Diferencia aproximada |
| ---------------------------- | ---------: | --------: | --------------------: |
| Pedidos con `TARJETA`        |  18,877 ms | 17,588 ms |                -6,8 % |
| Productos activos por precio |  10,446 ms |  0,150 ms |               -98,6 % |
| Resumen de gasto por cliente | 207,512 ms | 20,341 ms |               -90,2 % |

Las mediciones corresponden a ejecuciones concretas mediante `EXPLAIN (ANALYZE, BUFFERS)` y deben interpretarse como resultados de las pruebas realizadas sobre la base de datos utilizada para el proyecto, ya que los tiempos de ejecución pueden variar entre ejecuciones según el estado del sistema y de la caché.

La documentación detallada de estas mediciones y de las decisiones tomadas se encuentra en `docs/tp5/informe_mediciones.md`.

## 7. Uso de herramientas de IA y decisiones tomadas

Durante el desarrollo del proyecto se utilizaron herramientas de inteligencia artificial como apoyo para la especificación, generación, revisión y análisis de distintas soluciones. Las propuestas generadas por estas herramientas no se incorporaron automáticamente: fueron revisadas y, cuando correspondió, ejecutadas de manera controlada sobre la base de trabajo para verificar su comportamiento.

La trazabilidad de los usos de IA realizados durante los distintos trabajos prácticos se encuentra documentada mediante las correspondientes declaraciones de uso de IA (DUIA) en `docs/tp2/`, `docs/tp3/`, `docs/tp4/` y `docs/tp5/`.

### 7.1. Kiro

Kiro se utilizó principalmente para transformar necesidades del proyecto en especificaciones más precisas y verificables.

Durante TP5 se utilizaron especificaciones para definir objetivos, workload, criterios de aceptación y características esperadas de índices y vistas. Entre las especificaciones utilizadas se encuentran:

* `specs/indice_pedido_tarjeta_fecha.md`;
* `specs/indice_producto_activo_precio.md`;
* `specs/indice_producto_activo_id_rechazado.md`;
* `specs/vista_productos_vigentes.md`;
* `specs/vista_pedidos_con_cliente.md`;
* `specs/vista_detalle_pedido_con_producto.md`;
* `specs/vista_materializada_gasto_cliente.md`.

El uso de especificaciones permitió establecer previamente qué debía resolver cada objeto y bajo qué criterios debía considerarse aceptable.

### 7.2. OpenCode

OpenCode se utilizó como herramienta de apoyo para la generación de implementaciones a partir de especificaciones previamente definidas.

Las propuestas obtenidas fueron revisadas antes de incorporarse al proyecto. La documentación de TP5 registra el flujo de trabajo utilizado y relaciona las implementaciones con las especificaciones correspondientes.

El uso de esta herramienta no sustituyó la validación mediante PostgreSQL: las soluciones debían ser ejecutables y sus resultados debían coincidir con los objetivos definidos.

### 7.3. Revisión y validación de las propuestas

La decisión final sobre cada implementación correspondió al desarrollo del proyecto y se basó en la revisión de la propuesta, la ejecución controlada y los resultados obtenidos.

Un ejemplo concreto fue la propuesta de crear el índice:

```sql id="0o5bqp"
CREATE INDEX idx_producto_activo_id
    ON producto (id_producto)
    WHERE activo = TRUE;
```

La propuesta fue analizada y probada experimentalmente, pero fue descartada porque `id_producto` ya se encuentra indexado mediante la clave primaria, la condición `activo = TRUE` presenta baja selectividad y el plan de ejecución de la consulta analizada no mejoró de manera significativa.

El índice experimental fue posteriormente eliminado y no forma parte del esquema definitivo.

En contraste, los índices `idx_pedido_tarjeta_fecha` e `idx_producto_activo_precio` fueron aceptados después de analizar sus planes de ejecución y obtener mejoras medibles en las consultas correspondientes.

También se verificó la equivalencia de las vistas propuestas respecto de sus consultas de referencia mediante comparaciones con `EXCEPT`, evitando considerar correcta una vista únicamente porque pudiera ejecutarse sin errores.

### 7.4. Criterio general de uso

El criterio utilizado durante el proyecto fue considerar a las herramientas de IA como apoyo para la elaboración de especificaciones, generación de alternativas y revisión técnica, pero mantener la validación mediante evidencia reproducible.

Las decisiones de incorporación, modificación o rechazo se tomaron a partir de:

1. correspondencia con los requisitos de la consigna;
2. coherencia con el modelo y el workload del proyecto;
3. revisión del SQL generado;
4. ejecución controlada sobre la base de datos;
5. análisis de resultados y planes de ejecución cuando correspondía.

De esta manera, la utilización de IA se integró al proceso de desarrollo sin reemplazar la revisión técnica ni la comprobación del funcionamiento de las soluciones.

## 8. Conclusiones

La primera entrega parcial del Trabajo Práctico Integrador permite consolidar los principales componentes desarrollados para el proyecto Food Store durante las etapas anteriores y las unidades 1, 2 y 3 de la asignatura.

El proyecto cuenta actualmente con un modelo entidad-relación documentado, su correspondiente transformación al modelo relacional y la justificación de la normalización. Sobre esta base se implementó un esquema PostgreSQL que incorpora claves primarias y foráneas, restricciones de integridad, tipos de datos, índices y reglas de negocio.

También se desarrollaron y verificaron consultas que utilizan JOIN, agregaciones, subconsultas, GROUP BY, HAVING y funciones de ventana. El análisis de planes de ejecución permitió evaluar distintas alternativas de optimización y seleccionar aquellas que presentaron beneficios verificables.

En cuanto a los objetos específicos del motor, se incorporaron índices parciales, vistas convencionales, una vista materializada, funciones PL/pgSQL, triggers y un procedimiento almacenado. El procedimiento `sp_desactivar_producto` permite implementar el borrado lógico de productos, conservando los registros necesarios para mantener el historial de pedidos.

Las pruebas realizadas permitieron verificar las restricciones de integridad, el comportamiento de las transacciones, los niveles de aislamiento y los mecanismos de control de concurrencia. También se comprobó el impacto del borrado lógico sobre las consultas y la relación entre las estrategias de indexación y el workload del proyecto.

Finalmente, el análisis de las propuestas generadas mediante herramientas de IA permitió incorporar soluciones que presentaron resultados verificables y descartar aquellas que no justificaban su incorporación. La validación mediante ejecución y medición fue utilizada como criterio para las decisiones técnicas.

Con esta primera entrega se dispone de una base integrada y verificable sobre la cual continuar ampliando el proyecto durante las siguientes unidades de la materia. La entrega no representa la finalización del TPI, sino el estado consolidado del proyecto correspondiente a esta primera etapa.

## 9. Referencias y evidencias del proyecto

La siguiente tabla resume los principales archivos utilizados como evidencia de los objetivos y resultados documentados en este informe.

| Tema                               | Evidencia principal                                               |
| ---------------------------------- | ----------------------------------------------------------------- |
| Modelo ER                          | `docs/tp1/modelo_er.drawio` y `docs/tp1/modelo_er.svg`            |
| Informe y normalización TP1        | `docs/tp1/informe_tp1.pdf`                                        |
| Esquema DDL                        | `db/schema.sql`                                                   |
| Índices                            | `db/indices.sql`                                                  |
| Vistas                             | `db/views.sql`                                                    |
| Consultas TP3/TP4                  | `db/consultas_tp4_parte3.sql`                                     |
| Generación y consultas TP3         | `db/generador_datos_tp3.sql` y `db/generador_datos_tp3_carga.sql` |
| Pruebas de la primera entrega      | `db/tpi_parcial1_pruebas.sql`                                     |
| Transacciones y concurrencia       | `docs/tp2/informe_concurrencia.md`                                |
| Optimización de consultas          | `docs/tp3/` y `docs/tp4/`                                         |
| Mediciones de índices y vistas     | `docs/tp5/informe_mediciones.md`                                  |
| Declaraciones de uso de IA         | `docs/tp2/`, `docs/tp3/`, `docs/tp4/` y `docs/tp5/`               |
| Especificaciones utilizadas en TP5 | `specs/`                                                          |

Las pruebas reproducibles correspondientes a esta entrega se encuentran centralizadas en `db/tpi_parcial1_pruebas.sql`. Este archivo contiene verificaciones del procedimiento almacenado, borrado lógico, reglas de negocio, vistas, índices, transacciones, versión del motor y una consulta representativa del proyecto.
