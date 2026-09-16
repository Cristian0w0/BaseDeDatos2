# Informe de concurrencia — Parte 2

## 1. Introducción

En esta parte del trabajo práctico se realizaron pruebas de concurrencia sobre la base de datos `tp_bd2_trabajo`, utilizando dos sesiones independientes de PostgreSQL.

El objetivo fue reproducir y observar tres escenarios de concurrencia:

1. Lectura no repetible.
2. Lectura fantasma.
3. Espera por bloqueo.

Para los dos primeros escenarios se compararon los niveles de aislamiento `READ COMMITTED` y `REPEATABLE READ`.

Para el tercer escenario se utilizó `SELECT ... FOR UPDATE` para observar el comportamiento de los bloqueos de fila.

Todas las pruebas se realizaron sobre la base de trabajo `tp_bd2_trabajo`. Luego de las pruebas que agregaron o modificaron datos, se realizaron las acciones necesarias para devolver la base al estado inicial.

---

# 2. Entorno utilizado

* Motor: PostgreSQL 17.11.
* Herramienta utilizada para las sesiones SQL: DBeaver.
* Base de datos: `tp_bd2_trabajo`.
* Cantidad de sesiones: dos sesiones independientes conectadas a la misma base.
* Sesión A: conexión `postgres`.
* Sesión B: conexión `postgres (1)`.

Datos utilizados inicialmente:

### Categoría

```text
id_categoria | nombre  | activa
-------------+---------+-------
3            | Bebidas | true
```

### Producto

```text
id_producto | nombre    | precio  | stock | activo | categoria_id
------------+-----------+---------+-------+--------+-------------
5           | Coca Cola | 1000.00 | 10    | true   | 3
```

La fila `id_producto = 5` fue utilizada para las pruebas de lectura no repetible y espera por bloqueo.

---

# 3. Escenario 1 — Lectura no repetible

## Escenario

Se buscó demostrar que con `READ COMMITTED` una misma consulta realizada dos veces dentro de una misma transacción puede devolver valores diferentes si otra transacción modifica y confirma el dato entre ambas consultas.

Luego se repitió el experimento con `REPEATABLE READ` para comprobar que la segunda lectura conserva el mismo resultado.

---

## Cómo se reprodujo

### Primera prueba: READ COMMITTED

En la Sesión A se inició una transacción y se consultó el stock:

```sql
BEGIN;

SELECT id_producto, nombre, stock
FROM producto
WHERE id_producto = 5;
```

Resultado:

```text
id_producto | nombre    | stock
------------+-----------+------
5           | Coca Cola | 10
```

La transacción de A quedó abierta.

En la Sesión B se modificó el stock:

```sql
BEGIN;

UPDATE producto
SET stock = 20
WHERE id_producto = 5;

COMMIT;
```

Luego, sin cerrar la transacción de A, se repitió exactamente la misma consulta:

```sql
SELECT id_producto, nombre, stock
FROM producto
WHERE id_producto = 5;
```

Resultado:

```text
id_producto | nombre    | stock
------------+-----------+------
5           | Coca Cola | 20
```

Por lo tanto:

```text
Primera lectura:  10
Segunda lectura:  20
```

---

### Segunda prueba: REPEATABLE READ

Se cerró la transacción anterior con:

```sql
ROLLBACK;
```

Luego la Sesión B estableció el stock en 30:

```sql
BEGIN;

UPDATE producto
SET stock = 30
WHERE id_producto = 5;

COMMIT;
```

En la Sesión A se inició una transacción con `REPEATABLE READ`:

```sql
BEGIN;

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT id_producto, nombre, stock
FROM producto
WHERE id_producto = 5;
```

Resultado:

```text
id_producto | nombre    | stock
------------+-----------+------
5           | Coca Cola | 30
```

Mientras la transacción de A permanecía abierta, la Sesión B modificó nuevamente el stock:

```sql
BEGIN;

UPDATE producto
SET stock = 40
WHERE id_producto = 5;

COMMIT;
```

Luego A repitió la misma consulta:

```sql
SELECT id_producto, nombre, stock
FROM producto
WHERE id_producto = 5;
```

Resultado:

```text
id_producto | nombre    | stock
------------+-----------+------
5           | Coca Cola | 30
```

Por lo tanto:

```text
Primera lectura:  30
Segunda lectura:  30
```

---

## Qué se observó

Con `READ COMMITTED`, la misma consulta devolvió primero `10` y luego `20`.

Con `REPEATABLE READ`, la misma consulta devolvió `30` en ambas oportunidades, aunque otra sesión había confirmado posteriormente el cambio a `40`.

---

## Explicación de IA tal cual

Respuesta obtenida de OpenCode:

> 1. READ COMMITTED y la segunda lectura diferida
>    En READ COMMITTED, PostgreSQL obtiene un nuevo snapshot (fotografía de visibilidad) al inicio de cada sentencia SQL individual dentro de la transacción.
>    Cuando la Sesión A ejecutó la segunda consulta, PostgreSQL tomó un snapshot actualizado. Como la Sesión B ya había ejecutado COMMIT antes de esta segunda lectura, las modificaciones de B pasaron a ser visibles para el nuevo snapshot de A, devolviendo 20.
>
> 2. REPEATABLE READ y la constancia del valor
>    En REPEATABLE READ, PostgreSQL obtiene un único snapshot al inicio de la primera consulta de la transacción y lo reutiliza durante toda la duración de la transacción.
>    Cualquier modificación o COMMIT realizado por transacciones concurrentes (como la Sesión B) después de creado dicho snapshot es ignorado. Por ende, la segunda lectura de la Sesión A leyó la misma versión de la fila que la primera (stock = 30).
>
> 3. Mecanismo de PostgreSQL
>    El comportamiento se explica mediante MVCC (Multi-Version Concurrency Control) y Snapshots de Visibilidad:
>
> * PostgreSQL no bloquea las lecturas cuando hay escrituras; en su lugar, mantiene múltiples versiones físicas de las filas (usando identificadores como xmin y xmax).
>
> * Los niveles de aislamiento determinan cuándo se genera el snapshot:
>
> * READ COMMITTED: Snapshot a nivel de sentencia (Statement-level Snapshot).
>
> * REPEATABLE READ: Snapshot a nivel de transacción (Transaction-level Snapshot).
>
> 4. Nivel de aislamiento correspondiente
>
> * Prueba 1: READ COMMITTED (nivel por defecto en PostgreSQL).
>
> * Prueba 2: REPEATABLE READ.
>
> 5. Demostración del fenómeno
>    Sí, lo demuestra plenamente.
>
> * La Prueba 1 demuestra la ocurrencia de la anomalía de Lectura No Repetible (Non-Repeatable Read), en la que una misma transacción lee la misma fila dos veces y obtiene datos actualizados distintos producto del COMMIT de otra transacción concurrente.
> * La Prueba 2 demuestra la prevención exitosa de dicha anomalía mediante el uso del nivel de aislamiento adecuado.

---

## Verificación en motor

El comportamiento indicado por la IA fue comprobado directamente mediante PostgreSQL.

Los resultados observados fueron:

```text
READ COMMITTED
Primera lectura  → 10
Cambio confirmado por B → 20
Segunda lectura  → 20
```

y:

```text
REPEATABLE READ
Primera lectura  → 30
Cambio confirmado por B → 40
Segunda lectura  → 30
```

La explicación de la IA coincidió con el comportamiento observado.

**Resultado de la verificación: IA acertó.**

---

## Conclusión

El experimento permitió demostrar una lectura no repetible utilizando dos sesiones concurrentes.

Con `READ COMMITTED`, cada sentencia obtiene una nueva visión de los datos confirmados, por lo que una modificación confirmada por otra transacción puede ser observada en una consulta posterior.

Con `REPEATABLE READ`, la transacción mantiene el mismo snapshot y la segunda lectura conserva el valor observado inicialmente.

---

# 4. Escenario 2 — Lectura fantasma

## Escenario

Se buscó demostrar una lectura fantasma utilizando un `COUNT(*)`.

La consulta cuenta los productos pertenecientes a la categoría `Bebidas` (`categoria_id = 3`).

Primero se realizó la prueba con `READ COMMITTED`, y posteriormente con `REPEATABLE READ`.

---

## Cómo se reprodujo

### Primera prueba: READ COMMITTED

Inicialmente la categoría `Bebidas` tenía un solo producto.

En la Sesión A se ejecutó:

```sql
BEGIN;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT COUNT(*) AS cantidad_productos
FROM producto
WHERE categoria_id = 3;
```

Resultado:

```text
cantidad_productos
------------------
1
```

La transacción de A quedó abierta.

En la Sesión B se insertó un nuevo producto:

```sql
BEGIN;

INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Producto Fantasma', 500.00, 5, TRUE, 3);

COMMIT;
```

Luego, sin cerrar la transacción de A, se repitió la consulta:

```sql
SELECT COUNT(*) AS cantidad_productos
FROM producto
WHERE categoria_id = 3;
```

Resultado:

```text
cantidad_productos
------------------
2
```

Por lo tanto:

```text
Primer COUNT:  1
Segundo COUNT: 2
```

---

### Segunda prueba: REPEATABLE READ

Se cerró la transacción anterior de A mediante:

```sql
ROLLBACK;
```

Los datos de la prueba anterior fueron limpiados posteriormente, dejando nuevamente un único producto en la categoría.

Luego se inició una transacción con `REPEATABLE READ`:

```sql
BEGIN;

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT COUNT(*) AS cantidad_productos
FROM producto
WHERE categoria_id = 3;
```

Resultado:

```text
cantidad_productos
------------------
2
```

En este punto había dos productos visibles para A.

Mientras la transacción permanecía abierta, la Sesión B insertó otro producto:

```sql
BEGIN;

INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Producto Fantasma 2', 700.00, 3, TRUE, 3);

COMMIT;
```

Luego A repitió la consulta:

```sql
SELECT COUNT(*) AS cantidad_productos
FROM producto
WHERE categoria_id = 3;
```

Resultado:

```text
cantidad_productos
------------------
2
```

La nueva fila confirmada por B no apareció en el snapshot de A.

---

## Qué se observó

Con `READ COMMITTED`, el `COUNT(*)` pasó de `1` a `2` después de que otra sesión insertó y confirmó una nueva fila.

Con `REPEATABLE READ`, el `COUNT(*)` permaneció en `2`, aunque otra sesión había confirmado la inserción de un tercer producto.

---

## Explicación de IA tal cual

Respuesta obtenida de OpenCode:

> 1. READ COMMITTED y el cambio en el segundo COUNT
>    En el nivel READ COMMITTED, PostgreSQL toma un nuevo snapshot de visibilidad al comienzo de cada instrucción SQL.
>
> * Al ejecutar el primer COUNT(*), el snapshot de la Sesión A solo vio 1 fila.
>
> * Antes del segundo COUNT(*), la Sesión B insertó un nuevo registro y realizó COMMIT.
>
> * Cuando la Sesión A ejecutó el segundo COUNT(*), se generó un snapshot actualizado. Como el insert de la Sesión B ya estaba confirmado, la nueva fila pasó a ser visible, resultando en un conteo de 2.
>
> 2. REPEATABLE READ y la constancia del conteo
>    En el nivel REPEATABLE READ, PostgreSQL toma un único snapshot al comienzo de la primera sentencia ejecutable de la transacción y lo mantiene durante toda la duración de esta.
>
> * Al ejecutar el primer COUNT(*), el snapshot congeló la visibilidad de los datos en ese instante (2 productos).
>
> * Cuando la Sesión B insertó 'Producto Fantasma 2' y confirmó, dicha fila nació con una transacción (xmin) posterior al snapshot de la Sesión A.
>
> * Al repetir la consulta, la Sesión A continuó evaluando los datos bajo su snapshot inicial, ignorando la nueva fila insertada y manteniendo el resultado en 2.
>
> 3. Mecanismo de PostgreSQL
>    El comportamiento está fundamentado en MVCC (Multi-Version Concurrency Control) y la gestión de Snapshots de Visibilidad:
>
> * En PostgreSQL, la visibilidad de una fila no depende de bloqueos de lectura sobre rangos de datos, sino de comparar las tuplas visibles contra el snapshot de la transacción (basado en IDs de transacciones xmin/xmax).
>
> * READ COMMITTED evalúa el criterio de búsqueda (WHERE categoria_id = 3) con un snapshot renovado por cada consulta.
>
> * REPEATABLE READ evalúa el criterio de búsqueda siempre sobre el mismo snapshot congelado al inicio de la transacción.
>
> 4. Nivel de aislamiento correspondiente
>
> * Prueba 1: READ COMMITTED.
>
> * Prueba 2: REPEATABLE READ.
>
> 5. Demostración del fenómeno
>    Sí, demuestra la aparición y prevención de la anomalía de Lectura Fantasma (Phantom Read).
>
> * La Prueba 1 demuestra cómo aparece una "lectura fantasma": un conjunto de filas que satisface una condición de búsqueda cambia entre dos consultas dentro de la misma transacción debido a inserciones confirmadas por otra transacción.
>
> * La Prueba 2 demuestra cómo el nivel REPEATABLE READ previene exitosamente que este "fantasma" afecte las consultas de la transacción.
>
> 6. Particularidad de PostgreSQL respecto a REPEATABLE READ y Lecturas Fantasma
>    De acuerdo con el estándar ANSI SQL-92, el nivel REPEATABLE READ solo está obligado a prevenir lecturas no repetibles, permitiendo potencialmente lecturas fantasma (requiriendo SERIALIZABLE para evitarlas).
>    Sin embargo, PostgreSQL ofrece una garantía más fuerte de lo exigido por el estándar:
>
> * En PostgreSQL, el nivel REPEATABLE READ no permite lecturas fantasma.
> * Gracias a su implementación basada en snapshots de MVCC (Snapshot Isolation), la transacción no solo ve los mismos valores en las filas existentes, sino que tampoco ve registros nuevos (fantasmas) agregados por otras transacciones después de que se tomó el snapshot.
> * En PostgreSQL, para prevenir lecturas fantasma no es estrictamente necesario llegar a SERIALIZABLE (este último se reserva para prevenir anomalías de secuenciabilidad más complejas como Write Skew).

---

## Verificación en motor

La explicación fue contrastada con el comportamiento observado directamente en PostgreSQL.

Los resultados fueron:

```text
READ COMMITTED
Primer COUNT  → 1
Inserción confirmada por B → nuevo producto
Segundo COUNT → 2
```

y:

```text
REPEATABLE READ
Primer COUNT  → 2
Inserción confirmada por B → tercer producto
Segundo COUNT → 2
```

La explicación de la IA coincidió con los resultados obtenidos.

**Resultado de la verificación: IA acertó.**

---

## Conclusión

El experimento permitió observar una lectura fantasma con `READ COMMITTED`, ya que una nueva fila que cumplía la condición del `WHERE` pasó a ser visible entre dos ejecuciones del mismo `COUNT(*)`.

Con `REPEATABLE READ`, PostgreSQL mantuvo el snapshot de la transacción y la nueva fila no fue visible para la Sesión A.

---

# 5. Escenario 3 — Espera por bloqueo

## Escenario

Se buscó demostrar una espera por bloqueo utilizando `SELECT ... FOR UPDATE` sobre la misma fila desde dos sesiones concurrentes.

La fila utilizada fue:

```text
id_producto = 5
nombre = Coca Cola
stock = 10
```

---

## Cómo se reprodujo

En la Sesión A se inició una transacción y se solicitó el bloqueo de la fila:

```sql
BEGIN;

SELECT id_producto, nombre, stock
FROM producto
WHERE id_producto = 5
FOR UPDATE;
```

La consulta devolvió:

```text
id_producto | nombre    | stock
------------+-----------+------
5           | Coca Cola | 10
```

La transacción de A quedó abierta.

Luego, en la Sesión B se ejecutó:

```sql
BEGIN;

SELECT id_producto, nombre, stock
FROM producto
WHERE id_producto = 5
FOR UPDATE;
```

La consulta de B quedó esperando y no devolvió inmediatamente el resultado.

Mientras B estaba esperando, la Sesión A ejecutó:

```sql
COMMIT;
```

Después del `COMMIT` de A, la consulta de B dejó de esperar y devolvió:

```text
id_producto | nombre    | stock
------------+-----------+------
5           | Coca Cola | 10
```

---

## Qué se observó

La Sesión A obtuvo primero el bloqueo de la fila.

Cuando la Sesión B intentó obtener un bloqueo `FOR UPDATE` sobre la misma fila, tuvo que esperar.

Al finalizar la transacción de A mediante `COMMIT`, el bloqueo fue liberado y B pudo continuar.

La secuencia observada fue:

```text
Sesión A → FOR UPDATE → obtiene el bloqueo
Sesión B → FOR UPDATE → queda esperando
Sesión A → COMMIT → libera el bloqueo
Sesión B → continúa → obtiene la fila
```

---

## Explicación de IA tal cual

Respuesta obtenida de OpenCode:

> 1. Mecanismo de bloqueo de SELECT ... FOR UPDATE
>    SELECT ... FOR UPDATE adquiere un bloqueo exclusivo a nivel de fila de tipo RowExclusiveLock / FOR UPDATE (Row Lock) sobre los registros devueltos por la consulta.
>    Este tipo de bloqueo bloquea la tupla seleccionada como si fuera a ser actualizada en ese instante (UPDATE), impidiendo que otras transacciones concurrentes adquieran bloqueos contrapuestos (como otros FOR UPDATE, FOR NO KEY UPDATE, FOR SHARE, o ejecuten operaciones UPDATE / DELETE) sobre las mismas filas hasta que la transacción propietaria finalice.
>
> 2. Por qué la Sesión B tuvo que esperar
>    En PostgreSQL, los bloqueos explícitos a nivel de fila son incompatibles entre sí cuando ambas transacciones intentan adquirir permisos de escritura o exclusión (FOR UPDATE) sobre la misma fila.
>
> 3. La Sesión A obtuvo con éxito el bloqueo exclusivo sobre la fila con id_producto = 5.
>
> 4. Cuando la Sesión B ejecutó la misma sentencia sobre el mismo registro, solicitó un bloqueo FOR UPDATE que entró en conflicto con el bloqueo retenido por A.
>
> 5. PostgreSQL puso a la Sesión B en un estado de espera (lock wait), pausando la ejecución de la consulta de B a la espera de que la transacción de A libere el recurso.
>
> 6. Qué ocurrió cuando la Sesión A hizo COMMIT
>    Los bloqueos a nivel de fila en PostgreSQL se mantienen vigentes durante toda la duración de la transacción que los adquirió.
>
> * Al ejecutar COMMIT, la Sesión A finalizó formalmente su transacción y liberó todos los bloqueos retenidos en la tabla y sus tuplas.
>
> * PostgreSQL notificó al gestor de bloqueos (Lock Manager), despertando inmediatamente a la Sesión B que estaba en cola de espera.
>
> * La Sesión B pudo entonces adquirir el bloqueo FOR UPDATE sobre id_producto = 5 y retornar la fila a la aplicación.
>
> 4. Rol del nivel de aislamiento vs. bloqueo explícito
>    Este fenómeno depende principalmente del bloqueo explícito a nivel de fila y no del nivel de aislamiento.
>
> * SELECT ... FOR UPDATE es una instrucción de concurrencia pesimista que anula el comportamiento por defecto del motor (lecturas no bloqueantes mediante MVCC) para forzar un bloqueo físico de la fila.
>
> * El comportamiento de espera por bloqueo ocurre de manera idéntica en cualquier nivel de aislamiento (READ COMMITTED, REPEATABLE READ, SERIALIZABLE), ya que la regla de compatibilidad de bloqueos a nivel de fila impuesta por FOR UPDATE aplica globalmente en PostgreSQL.
>
> 5. Demostración del experimento
>    Sí, el experimento demuestra perfectamente una espera por bloqueo (Lock Wait / Blocking) en PostgreSQL.
>    Muestra claramente el control de concurrencia pesimista: cómo una transacción retiene un recurso exclusivo y cómo PostgreSQL encola y suspende el procesamiento de otra transacción hasta que el recurso es liberado.
>
> 6. Diferencia breve con un Interbloqueo (Deadlock)
>
> * Espera por bloqueo (este experimento): Es una dependencia unidireccional y lineal. La Sesión B espera a la Sesión A. Tan pronto como A termina, B continúa normalmente sin errores.
> * Interbloqueo (Deadlock): Es una dependencia circular cruzada. Ocurre cuando la Sesión A espera un recurso bloqueado por la Sesión B, y simultáneamente la Sesión B espera un recurso bloqueado por la Sesión A. En este caso, ninguna transacción puede avanzar por sí misma y PostgreSQL se ve obligado a abortar automáticamente una de las dos transacciones arrojando un error (ERROR: deadlock detected).

---

## Verificación en motor

El comportamiento descrito fue comprobado directamente con las dos sesiones de PostgreSQL.

La Sesión B quedó efectivamente esperando mientras la Sesión A mantenía abierta la transacción.

Después de ejecutar:

```sql
COMMIT;
```

en la Sesión A, la consulta de la Sesión B continuó y devolvió correctamente la fila:

```text
id_producto | nombre    | stock
------------+-----------+------
5           | Coca Cola | 10
```

La explicación de la IA coincidió con el comportamiento observado.

**Resultado de la verificación: IA acertó.**

El experimento también permitió diferenciar una espera por bloqueo de un interbloqueo. En este caso solamente B esperaba a A; al liberar A el bloqueo, B pudo continuar. En un deadlock existiría una dependencia circular entre las transacciones y PostgreSQL abortaría una de ellas.

---

## Conclusión

El experimento demostró una espera por bloqueo producida por `SELECT ... FOR UPDATE` sobre una misma fila.

La Sesión A adquirió el bloqueo y la Sesión B tuvo que esperar hasta que A finalizó su transacción.

Este escenario muestra el uso de bloqueos explícitos para controlar el acceso concurrente a determinadas filas.

---

# 6. Conclusión general

Los tres experimentos permitieron observar diferentes comportamientos de concurrencia en PostgreSQL utilizando dos sesiones independientes.

### Lectura no repetible

Se comprobó que:

```text
READ COMMITTED     → 10 → 20
REPEATABLE READ    → 30 → 30
```

Por lo tanto, `REPEATABLE READ` evitó que una segunda lectura dentro de la misma transacción observara el cambio confirmado posteriormente por otra sesión.

### Lectura fantasma

Se comprobó que:

```text
READ COMMITTED     → 1 → 2
REPEATABLE READ    → 2 → 2
```

La nueva fila insertada y confirmada por otra transacción fue visible con `READ COMMITTED`, pero no con `REPEATABLE READ` dentro del snapshot de la transacción.

### Espera por bloqueo

Se comprobó que:

```text
Sesión A → FOR UPDATE → bloqueo
Sesión B → FOR UPDATE → espera
Sesión A → COMMIT → libera
Sesión B → continúa
```

La prueba permitió observar directamente el bloqueo de una fila y la espera de una segunda transacción.

En los tres escenarios, las explicaciones obtenidas de OpenCode fueron contrastadas con los resultados observados en PostgreSQL y se consideraron correctas.

Finalmente, los datos temporales utilizados durante las pruebas de lectura fantasma fueron eliminados y la base quedó nuevamente con el producto original:

```text
id_producto | nombre    | stock | categoria_id
------------+-----------+-------+-------------
5           | Coca Cola | 10    | 3
```

Por lo tanto, las pruebas pudieron realizarse sin dejar los datos de prueba agregados en la base de trabajo.
