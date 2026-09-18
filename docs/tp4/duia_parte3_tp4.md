# DUIA — Parte 3 TP4

## Declaración de Uso de IA

### Herramienta utilizada

**OpenCode con modelo de Google Gemini**

### Uso realizado

Se utilizó IA para generar consultas SQL a partir de especificaciones precisas y para proponer una segunda versión de cada consulta con una estructura diferente, siguiendo la consigna de la Parte 3.

Las consultas generadas fueron:

* Consulta A1: ranking de clientes por gasto mediante agregación y función de ventana `RANK()`.
* Consulta A2: mismo ranking utilizando una CTE para calcular previamente el gasto por cliente.
* Consulta B1: cantidad de pedidos y gasto total mediante subconsultas correlacionadas.
* Consulta B2: misma información mediante `JOIN + GROUP BY`.

También se solicitó a la IA generar las consultas `EXCEPT` necesarias para verificar la equivalencia en ambas direcciones.

### Revisión humana de las propuestas

Antes de ejecutar las consultas se revisaron las referencias a tablas y columnas contra `db/schema.sql`.

Durante la revisión se detectó un error en una de las consultas generadas por IA: en una de las comparaciones `EXCEPT` se había utilizado incorrectamente:

```sql
p.id_pedido = dp.precio_unitario
```

La relación correcta entre `pedido` y `detalle_pedido` es:

```sql
p.id_pedido = dp.pedido_id
```

El error fue detectado antes de ejecutar la consulta y se corrigió en el archivo `db/consultas_tp4_parte3.sql`. Luego se realizó una revisión del resto del archivo para verificar que no existieran referencias similares incorrectas.

También se verificó que la IA no agregara columnas de borrado lógico inexistentes en el esquema actual.

### Decisiones tomadas

Se aceptaron las consultas generadas después de revisar su estructura y comprobar que respetaban las especificaciones.

En particular:

* Para el ranking se utilizó `RANK()` sin incluir `id_cliente` como criterio de orden de la ventana, para conservar la posibilidad de empates en la posición.
* El orden final incluye `id_cliente ASC` únicamente como desempate de presentación.
* Para la consulta con subconsulta correlacionada se utilizó `EXISTS` para limitar el resultado a clientes con al menos un pedido.
* En la versión con `JOIN + GROUP BY` se utilizó `COUNT(DISTINCT p.id_pedido)` para evitar contar un mismo pedido varias veces cuando posee múltiples detalles.
* No se agregaron filtros de borrado lógico porque las tablas involucradas del esquema actual no poseen columnas de borrado lógico.

### Verificación con la base de datos

Las consultas fueron ejecutadas en la base `bd2_tp4`.

Resultados obtenidos:

* A1: 20.000 filas.
* A2: 20.000 filas.
* A1 `EXCEPT` A2: 0 filas.
* A2 `EXCEPT` A1: 0 filas.
* B1: 20.000 filas.
* B2: 20.000 filas.
* B1 `EXCEPT` B2: 0 filas.
* B2 `EXCEPT` B1: 0 filas.

La equivalencia fue comprobada en ambas direcciones para cada par de consultas.

### Conclusión

La IA se utilizó como herramienta de generación y revisión inicial del SQL, pero las consultas fueron inspeccionadas antes de ejecutarse.

Se detectó y corrigió un error concreto en una condición de `JOIN` generada por la IA. La verificación posterior mediante ejecución en `bd2_tp4` y operaciones `EXCEPT` confirmó que las dos versiones de cada consulta producen el mismo conjunto de resultados sobre los datos actuales.
