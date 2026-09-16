# DUIA — Parte 2: Laboratorio de concurrencia y niveles de aislamiento

## Herramientas y entorno general

* **Herramienta de IA:** OpenCode 1.18.23 (Google Gemini 3.6 Flash)
* **Motor de Base de Datos:** PostgreSQL 17.11
* **Cliente SQL:** DBeaver
* **Base de datos:** `tp_bd2_trabajo`
* **Sesiones concurrentes:** 
  * Sesión A: Conexión `postgres`
  * Sesión B: Conexión `postgres (1)`

---

## Escenario 1 — Lectura no repetible

### 1. Objetivo
Demostrar el fenómeno de lectura no repetible en el nivel de aislamiento `READ COMMITTED` y verificar su prevención en `REPEATABLE READ`, evaluando mediante contrastación empírica en el motor PostgreSQL las explicaciones sobre MVCC y snapshots brindadas por la IA.

### 2. Herramientas y entorno
* Base de trabajo `tp_bd2_trabajo`.
* Dos sesiones SQL independientes en DBeaver (Sesión A y Sesión B).
* Registro utilizado: `producto.id_producto = 5` (`Coca Cola`, stock inicial 10).

### 3. Prompt o solicitud realizada a la IA
> Analizá la prueba de lectura no repetible realizada entre dos sesiones sobre `producto.id_producto = 5`. Explicá por qué en READ COMMITTED la Sesión A observó stock 10 y luego stock 20 (tras el UPDATE y COMMIT de B), mientras que en REPEATABLE READ la Sesión A observó stock 30 en ambas lecturas aunque B actualizó y confirmó stock 40. Explicá el mecanismo interno de PostgreSQL (MVCC, snapshots) y qué nivel de aislamiento corresponde a cada prueba.

### 4. Cambios o material generado por la IA
La IA generó una explicación teórica detallada:
1. **READ COMMITTED:** PostgreSQL obtiene un nuevo snapshot (fotografía de visibilidad) al inicio de cada instrucción SQL individual dentro de la transacción. Al ejecutar B un `COMMIT` antes de la segunda lectura de A, el nuevo snapshot de A visibilizó la modificación (stock = 20).
2. **REPEATABLE READ:** PostgreSQL obtiene un único snapshot al inicio de la primera consulta de la transacción y lo mantiene congelado durante toda la duración de esta. Los cambios confirmados por B después de crear dicho snapshot son ignorados (stock = 30).
3. **Mecanismo:** Basado en MVCC (Multi-Version Concurrency Control) mediante identificadores `xmin` y `xmax`.

### 5. Verificación realizada por el estudiante
Se ejecutó la prueba en dos etapas sobre la base `tp_bd2_trabajo`:

* **Prueba READ COMMITTED:**
  * Sesión A inició transacción (`BEGIN;`) y leyó stock de `id_producto = 5` (resultado: 10).
  * Sesión B inició transacción (`BEGIN;`), ejecutó `UPDATE producto SET stock = 20 WHERE id_producto = 5;` y realizó `COMMIT;`.
  * Sesión A repitió la consulta sin cerrar su transacción y observó stock 20.
  * Sesión A ejecutó `ROLLBACK;`.

* **Prueba REPEATABLE READ:**
  * Sesión B actualizó previamente el stock a 30 y realizó `COMMIT;`.
  * Sesión A inició transacción con `SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;` y consultó stock (resultado: 30).
  * Sesión B ejecutó `UPDATE producto SET stock = 40 WHERE id_producto = 5;` y realizó `COMMIT;`.
  * Sesión A repitió la consulta y continuó observando stock 30.
  * Sesión A ejecutó `ROLLBACK;`.
  * Finalmente, el stock fue restaurado a su valor inicial 10.

### 6. Resultado de la verificación
Los datos observados en DBeaver coincidieron exactamente con lo previsto:
* `READ COMMITTED`: Lectura 1 = 10, Lectura 2 = 20 (ocurrió lectura no repetible).
* `REPEATABLE READ`: Lectura 1 = 30, Lectura 2 = 30 (anomalía prevenida).

### 7. Evaluación de la respuesta de IA
La respuesta de la IA fue evaluada como correcta en cuanto al comportamiento observado, con una imprecisión terminológica puntual que fue identificada y documentada. La explicación se basó adecuadamente en MVCC y en la diferencia fundamental entre snapshots por sentencia (statement-level) y snapshots por transacción (transaction-level). La respuesta no se aceptó por mera autoridad, sino porque describió fielmente el comportamiento real observado en PostgreSQL.

### 8. Decisión final
Aceptar plenamente la explicación conceptual de la IA al ser validada de manera directa y empírica mediante el comportamiento de las dos sesiones en el motor.

### 9. Relación con la consigna de la Parte 2
Cumple con el requerimiento de reproducir la lectura no repetible, comparar el comportamiento entre niveles de aislamiento y fundamentar el fenómeno mediante el control de concurrencia multiversión de PostgreSQL.

---

## Escenario 2 — Lectura fantasma

### 1. Objetivo
Demostrar la anomalía de lectura fantasma en `READ COMMITTED` mediante consultas de agregación (`COUNT(*)`) sobre la categoría `categoria_id = 3` (`Bebidas`), y verificar la particularidad de PostgreSQL que impide este fenómeno en `REPEATABLE READ`.

### 2. Herramientas y entorno
* Base de trabajo `tp_bd2_trabajo`.
* Dos sesiones SQL independientes en DBeaver.
* Categoría de prueba: `categoria_id = 3` (`Bebidas`).

### 3. Prompt o solicitud realizada a la IA
> Explicá el comportamiento de lectura fantasma observado al contar productos de la categoría 3 (`COUNT(*)`). ¿Por qué en READ COMMITTED el COUNT pasó de 1 a 2 cuando la Sesión B insertó 'Producto Fantasma' y confirmó, mientras que en REPEATABLE READ el COUNT se mantuvo en 2 cuando B insertó 'Producto Fantasma 2' y confirmó? Explicá la particularidad de PostgreSQL con respecto al nivel REPEATABLE READ y la anomalía de lectura fantasma.

### 4. Cambios o material generado por la IA
La IA explicó que:
1. En `READ COMMITTED`, al ejecutarse la segunda consulta `COUNT(*)`, PostgreSQL generó un snapshot actualizado que incluyó la nueva fila insertada y confirmada por la Sesión B (`Producto Fantasma`), incrementando el conteo de 1 a 2.
2. En `REPEATABLE READ`, el snapshot de la transacción A permaneció congelado desde la primera consulta, por lo que la inserción de `Producto Fantasma 2` por parte de B no fue visible y el conteo se mantuvo en 2.
3. **Particularidad de PostgreSQL:** A diferencia del estándar ANSI SQL-92 (que permite lecturas fantasma en `REPEATABLE READ`), PostgreSQL ofrece Snapshot Isolation (SI) dentro de MVCC en `REPEATABLE READ`, lo que previene tanto lecturas no repetibles como lecturas fantasma sin requerir el nivel `SERIALIZABLE`.

### 5. Verificación realizada por el estudiante
* **Prueba READ COMMITTED:**
  * Sesión A inició transacción con `READ COMMITTED` y consultó `COUNT(*)` sobre `categoria_id = 3` (resultado: 1).
  * Sesión B insertó `Producto Fantasma` en la categoría 3 y realizó `COMMIT;`.
  * Sesión A repitió el `COUNT(*)` y obtuvo 2.
  * Sesión A ejecutó `ROLLBACK;`.

* **Prueba REPEATABLE READ:**
  * Sesión A inició transacción con `REPEATABLE READ` y obtuvo `COUNT(*) = 2`.
  * Sesión B insertó `Producto Fantasma 2` en la categoría 3 y realizó `COMMIT;`.
  * Sesión A repitió el `COUNT(*)` y obtuvo nuevamente 2.
  * Sesión A ejecutó `ROLLBACK;`.

* **Limpieza de datos:**
  * Los dos productos de prueba (`Producto Fantasma` y `Producto Fantasma 2`) fueron eliminados posteriormente y se verificó que quedara únicamente el producto original (`Coca Cola`) en la categoría 3.

### 6. Resultado de la verificación
Se confirmó experimentalmente que la inserción de nuevas filas impactó en el `COUNT(*)` bajo `READ COMMITTED`, pero fue aislada con éxito bajo `REPEATABLE READ`.

### 7. Evaluación de la respuesta de IA
La explicación generada por la IA fue evaluada como correcta. La argumentación basada en MVCC y la aclaración sobre cómo PostgreSQL extiende las garantías de `REPEATABLE READ` más allá del estándar ANSI SQL fueron contrastadas y validadas con los resultados reales del laboratorio.

### 8. Decisión final
Aceptar la explicación de la IA por su precisión técnica y coincidencia total con las pruebas de laboratorio.

### 9. Relación con la consigna de la Parte 2
Satisface la consigna de analizar la aparición de filas "fantasma" en consultas por rango o agregación y comprender la arquitectura de aislamiento de PostgreSQL.

---

## Escenario 3 — Espera por bloqueo

### 1. Objetivo
Observar el comportamiento de los bloqueos pesimistas a nivel de fila y el fenómeno de espera por bloqueo (*lock wait*) mediante el uso de `SELECT ... FOR UPDATE` en dos transacciones concurrentes.

### 2. Herramientas y entorno
* Base de trabajo `tp_bd2_trabajo`.
* Dos sesiones SQL independientes en DBeaver.
* Registro utilizado: `producto.id_producto = 5`.

### 3. Prompt o solicitud realizada a la IA
> Explicá qué ocurrió cuando la Sesión A ejecutó `SELECT ... FOR UPDATE` sobre `id_producto = 5`, la Sesión B intentó la misma consulta y quedó bloqueada, y luego B se desbloqueó inmediatamente al hacer A `COMMIT`. Explicá el tipo de bloqueo, por qué ocurre la espera y si esto depende del nivel de aislamiento.

### 4. Cambios o material generado por la IA
La IA explicó que:
1. `SELECT ... FOR UPDATE` solicita un bloqueo exclusivo a nivel de fila sobre el registro seleccionado, impidiendo que otras transacciones adquieran bloqueos incompatibles sobre la misma tupla.
2. La Sesión B quedó suspendida en espera de bloqueo (*lock wait*) debido al conflicto entre los bloqueos solicitados sobre `id_producto = 5`.
3. Al ejecutar la Sesión A el `COMMIT`, finalizó la transacción y liberó el bloqueo, permitiendo que PostgreSQL despertara a la Sesión B y le retornara la fila.
4. Denominó conceptualmente a la operación como `RowExclusiveLock / FOR UPDATE`.
5. Aclaró que este fenómeno depende del bloqueo explícito de fila y no de alterar el nivel de aislamiento.

### 5. Verificación realizada por el estudiante
* Sesión A inició transacción y ejecutó `SELECT ... FOR UPDATE` sobre `id_producto = 5`. La fila fue retornada y la transacción de A permaneció abierta.
* Sesión B inició otra transacción y ejecutó exactamente el mismo `SELECT ... FOR UPDATE` sobre `id_producto = 5`.
* La consulta de la Sesión B quedó bloqueada en espera.
* Sesión A ejecutó `COMMIT;`.
* Inmediatamente, la Sesión B se desbloqueó y retornó la fila.

* **Aclaración sobre niveles de aislamiento:**
  No se realizó una segunda prueba cambiando el nivel de aislamiento para el Escenario 3. La explicación se verificó a través del experimento de bloqueo realizado, entendiendo que el fenómeno de espera por bloqueo es provocado por la instrucción pesimista `SELECT ... FOR UPDATE` a nivel de fila y no depende de modificar el nivel de aislamiento.

### 6. Resultado de la verificación
Se verificó el encolamiento de la Sesión B y su liberación instantánea al momento de confirmarse la transacción A.

### 7. Evaluación de la respuesta de IA
La explicación del comportamiento operativo de la espera por bloqueo y la liberación tras el `COMMIT` fue totalmente acertada y comprobada en la práctica.

Sin embargo, en la evaluación detallada se observó que la denominación `RowExclusiveLock / FOR UPDATE` utilizada por la IA contiene una imprecisión terminológica técnica: en el catálogo interno de PostgreSQL (`pg_locks`), `RowExclusiveLock` es un modo de bloqueo a nivel de **tabla** (adquirido por sentencias como `UPDATE` o `INSERT`), mientras que el bloqueo generado sobre la tupla por `SELECT ... FOR UPDATE` es un bloqueo de **fila** (*Row-level lock / Exclusive tuple lock*).

Esta imprecisión terminológica puntual no invalida la respuesta, pero se deja documentada: el comportamiento físico observado fue correcto y la explicación del bloqueo y espera fue verídica, aunque la nomenclatura exacta del catálogo interno no fue del todo precisa.

### 8. Decisión final
Aceptar la explicación del fenómeno de bloqueo pesimista y la dinámica de liberación de recursos, registrando explícitamente la aclaración sobre la nomenclatura interna de bloqueos en PostgreSQL.

### 9. Relación con la consigna de la Parte 2
Cumple con la consigna al demostrar el funcionamiento del control de concurrencia pesimista, la diferencia con un interbloqueo (*deadlock*) y la mecánica de liberación de bloqueos retenidos por transacciones.

---

## Conclusión general de la Parte 2

Los tres escenarios del laboratorio de concurrencia permitieron contrastar la teoría con la práctica directa en PostgreSQL 17.11:

1. **Lectura no repetible:** Se constató que `READ COMMITTED` actualiza el snapshot por sentencia (devuelve 10 y 20), mientras `REPEATABLE READ` mantiene el snapshot por transacción (devuelve 30 y 30).
2. **Lectura fantasma:** Se comprobó que `READ COMMITTED` muestra nuevas filas insertadas (conteo pasa de 1 a 2), mientras `REPEATABLE READ` las aísla mediante Snapshot Isolation (conteo se mantiene en 2).
3. **Espera por bloqueo:** Se demostró la detención de la Sesión B ante un `SELECT ... FOR UPDATE` sobre la misma fila retenida por A, reanudando la ejecución inmediatamente tras el `COMMIT` de A.

Las explicaciones proporcionadas por la IA fueron contrastadas con los experimentos realizados en el motor de base de datos, y cuando correspondió se identificaron y documentaron imprecisiones técnicas antes de aceptar la explicación.
