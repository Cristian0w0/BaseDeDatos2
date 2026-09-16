# Parte 3 — Lectura crítica de planes interpretados por IA

## 3.1 Plan seleccionado

Para esta actividad se seleccionó el plan final obtenido en la **Consulta 2 de la Parte 2**, luego de aplicar el índice `idx_producto_categoria_activo_nombre`.

El plan entregado a la IA fue exclusivamente el siguiente, sin proporcionarle información adicional sobre la consulta original ni sobre las mediciones anteriores:

```text
Index Scan using idx_producto_categoria_activo_nombre on producto p
(cost=0.41..3632.76 rows=46642 width=43)
(actual time=0.036..8.330 rows=46667 loops=1)
Index Cond: ((categoria_id = 3) AND (activo = true))
Buffers: shared hit=9522 read=337
Planning Time: 1.101 ms
Execution Time: 9.490 ms
```

Se solicitó a la IA que explicara el plan nodo por nodo, distinguiendo valores estimados de valores reales y aclarando qué información podía y no podía obtenerse únicamente a partir del plan.

Posteriormente, la explicación obtenida fue contrastada frase por frase con el plan real.

## 3.2 Tabla de lectura crítica

| Afirmación de la IA                                                                                                      | ¿Correcta?         | Corrección / evidencia del plan real                                                                                                                                                            |
| ------------------------------------------------------------------------------------------------------------------------ | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PostgreSQL realiza un `Index Scan` utilizando `idx_producto_categoria_activo_nombre`.                                    | Sí                 | El plan indica explícitamente `Index Scan using idx_producto_categoria_activo_nombre on producto p`.                                                                                            |
| `cost=0.41..3632.76` representa un costo estimado en unidades internas de PostgreSQL.                                    | Sí                 | `cost` es una estimación del planificador y no representa milisegundos.                                                                                                                         |
| `rows=46642` representa la cantidad de filas estimada por el optimizador.                                                | Sí                 | El plan estima 46.642 filas.                                                                                                                                                                    |
| `actual time=0.036..8.330` representa tiempos reales medidos durante la ejecución.                                       | Sí                 | Son los tiempos reales informados para el nodo.                                                                                                                                                 |
| `0.036 ms` corresponde aproximadamente al momento en que el nodo pudo producir la primera fila.                          | Sí                 | Es la interpretación del primer valor de `actual time`.                                                                                                                                         |
| `8.330 ms` corresponde al tiempo hasta completar el procesamiento del nodo.                                              | Sí                 | Debe distinguirse del tiempo total de la consulta, que fue `9.490 ms`.                                                                                                                          |
| `rows=46667` representa las filas realmente producidas por el nodo.                                                      | Sí                 | El plan muestra `rows=46667` con `loops=1`.                                                                                                                                                     |
| `loops=1` indica que el nodo se ejecutó una vez.                                                                         | Sí                 | El valor aparece explícitamente en el plan.                                                                                                                                                     |
| `Index Cond` representa la condición utilizada para acotar la búsqueda mediante el índice.                               | Sí                 | El plan muestra `Index Cond: ((categoria_id = 3) AND (activo = true))`.                                                                                                                         |
| `shared hit=9522` representa bloques encontrados en `shared_buffers`.                                                    | Sí                 | `shared hit` indica accesos satisfechos desde los buffers compartidos de PostgreSQL.                                                                                                            |
| `read=337` significa que esos bloques fueron leídos desde el disco.                                                      | **No**             | `read=337` indica que los bloques no estaban en `shared_buffers`, pero el plan no permite determinar si finalmente se obtuvieron del almacenamiento físico o de la caché del sistema operativo. |
| `Planning Time: 1.101 ms` corresponde al tiempo empleado en la planificación.                                            | Sí                 | Coincide directamente con el valor informado por PostgreSQL.                                                                                                                                    |
| `Execution Time: 9.490 ms` corresponde al tiempo total de ejecución de la consulta.                                      | Sí                 | Es el valor final informado por `EXPLAIN ANALYZE`.                                                                                                                                              |
| La estimación de filas fue muy cercana a la cantidad real: 46.642 estimadas frente a 46.667 reales.                      | Sí                 | La diferencia es de solamente 25 filas.                                                                                                                                                         |
| El 96,58 % de los bloques fueron atendidos desde memoria y esto demuestra un alto rendimiento de RAM.                    | **No / imprecisa** | El cálculo del porcentaje es correcto, pero no permite concluir por sí solo que existe un “alto rendimiento de RAM”. El plan únicamente informa `shared hit` y `read`.                          |
| El plan permite afirmar que el tamaño promedio de los datos recuperados por fila es de 43 bytes.                         | **No**             | `width=43` es un ancho **estimado** por el planificador, no una medición real del tamaño de los datos recuperados.                                                                              |
| El plan no permite conocer la consulta SQL exacta que lo originó.                                                        | Sí                 | El texto del plan no contiene el SQL completo.                                                                                                                                                  |
| El plan no permite conocer el DDL completo de la tabla ni del índice.                                                    | Sí                 | El nombre del índice no permite reconstruir por sí solo toda su definición.                                                                                                                     |
| El plan no permite conocer el número total de filas de la tabla `producto`.                                              | Sí                 | Solo informa las filas estimadas y reales procesadas por este nodo.                                                                                                                             |
| El plan no permite determinar si los bloques `read` provinieron finalmente de disco o de la caché del sistema operativo. | Sí                 | Esta información no puede determinarse únicamente a partir de `EXPLAIN`.                                                                                                                        |
| El plan no permite determinar las características del hardware ni toda la configuración del servidor.                    | Sí                 | Esa información no aparece en el plan proporcionado.                                                                                                                                            |

## 3.3 Hallazgos principales

La explicación de la IA fue mayormente correcta, pero se encontraron algunas afirmaciones que debieron ser corregidas o matizadas.

### 1. Interpretación de `read=337`

La IA inicialmente relacionó los bloques `read` con solicitudes al sistema operativo o al disco. Esta explicación es demasiado específica.

El plan muestra:

```text
Buffers: shared hit=9522 read=337
```

`shared hit` indica que el bloque estaba disponible en los buffers compartidos de PostgreSQL. `read` indica que no estaba allí y debió ser obtenido desde una capa inferior.

Sin información adicional no puede afirmarse que esos 337 bloques hayan sido necesariamente leídos desde almacenamiento físico, ya que podrían haber sido atendidos desde la caché del sistema operativo.

### 2. Interpretación de `width=43`

La IA explicó inicialmente correctamente que `width=43` es un valor estimado. Sin embargo, posteriormente afirmó que el plan permitía conocer el tamaño promedio real de los datos recuperados por fila.

Esto es incorrecto.

El valor:

```text
width=43
```

es una estimación realizada por el planificador y no una medición real de los bytes transferidos o almacenados para cada fila.

### 3. Interpretación del porcentaje de `shared hit`

La IA calculó:

```text
9522 / (9522 + 337) ≈ 96,58 %
```

El cálculo es correcto.

Sin embargo, concluir a partir de ese porcentaje que existe un “alto rendimiento de memoria RAM” es demasiado amplio. El plan muestra información sobre accesos a bloques de PostgreSQL, pero no constituye por sí solo una medición completa del rendimiento de memoria del servidor.

## 3.4 Conclusión

El ejercicio permitió comprobar que una explicación generada por IA puede ser técnicamente útil y, al mismo tiempo, contener afirmaciones demasiado generales o imprecisas.

En este caso, la mayor parte de la explicación fue correcta: la IA identificó correctamente el `Index Scan`, distinguió `cost` de `actual time`, interpretó correctamente `rows`, `loops`, `Index Cond`, `Planning Time` y `Execution Time`, y también reconoció varios límites de la información disponible.

Los principales errores aparecieron al interpretar `Buffers` y `width`. En particular, se comprobó que:

* `cost` no representa tiempo en milisegundos.
* `read` no implica necesariamente una lectura física desde disco.
* `width` es una estimación y no una medición real de bytes por fila.
* Un porcentaje elevado de `shared hit` no permite por sí solo concluir que el rendimiento de la memoria del servidor sea alto.

También se observó que la propia explicación de la IA contenía una inconsistencia: primero asociaba `read=337` con el sistema operativo/disco y posteriormente reconocía correctamente que no era posible determinar el origen físico de esos bloques únicamente a partir del plan.

Por lo tanto, la conclusión de esta actividad es que **la explicación de la IA debe ser contrastada con el plan real y no aceptarse automáticamente como correcta**. La lectura crítica permite separar los datos que realmente demuestra `EXPLAIN ANALYZE` de las interpretaciones o inferencias que requieren información adicional.
