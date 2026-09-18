# Parte 2 — Lectura crítica de planes de join interpretados por IA

## Plan seleccionado

Se seleccionó el plan baseline de la consulta **“Gasto total por cliente”**, obtenido en la Parte 1 mediante `EXPLAIN (ANALYZE, BUFFERS)`.

El plan contiene tres nodos `Hash Join`:

1. `detalle_pedido` con `producto`, mediante `dp.producto_id = pr.id_producto`.
2. El resultado anterior con `pedido`, mediante `dp.pedido_id = p.id_pedido`.
3. El resultado anterior con `cliente`, mediante `p.cliente_id = c.id_cliente`.

El tiempo total de ejecución registrado por PostgreSQL fue de **363.367 ms**.

Se proporcionó a la IA únicamente el texto del plan y se solicitó una explicación nodo por nodo, identificando las relaciones involucradas, los lados de entrada de cada join y diferenciando el costo estimado del tiempo real.

## Contraste entre la explicación de la IA y el plan real

| Afirmación de la IA                                                                                                 | ¿Correcta? | Corrección / evidencia del plan real                                                                                                       |
| ------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| El plan contiene tres `Hash Join`.                                                                                  | Sí         | El plan muestra tres nodos `Hash Join`.                                                                                                    |
| En el primer `Hash Join`, `detalle_pedido` es la entrada `Outer` y `producto` la entrada `Inner/Build`.             | Sí         | `detalle_pedido` aparece como primera rama y `producto` aparece debajo del nodo `Hash`.                                                    |
| El primer join utiliza `dp.producto_id = pr.id_producto`.                                                           | Sí         | Coincide con `Hash Cond: (dp.producto_id = pr.id_producto)`.                                                                               |
| El primer join produce 200.000 filas.                                                                               | Sí         | El plan indica `actual ... rows=200000`.                                                                                                   |
| En el segundo `Hash Join`, el resultado del primer join es la entrada `Outer` y `pedido` la entrada `Inner/Build`.  | Sí         | El resultado del primer join aparece como primera rama y `pedido` aparece debajo del nodo `Hash`.                                          |
| El segundo join utiliza `dp.pedido_id = p.id_pedido`.                                                               | Sí         | Coincide con `Hash Cond: (dp.pedido_id = p.id_pedido)`.                                                                                    |
| En el tercer `Hash Join`, el resultado del segundo join es la entrada `Outer` y `cliente` la entrada `Inner/Build`. | Sí         | El resultado del segundo join aparece como primera rama y `cliente` aparece debajo del nodo `Hash`.                                        |
| El tercer join utiliza `p.cliente_id = c.id_cliente`.                                                               | Sí         | Coincide con `Hash Cond: (p.cliente_id = c.id_cliente)`.                                                                                   |
| El `Sort` intermedio ordena por `c.id_cliente, p.id_pedido`.                                                        | Sí         | El plan muestra `Sort Key: c.id_cliente, p.id_pedido`.                                                                                     |
| El `Sort` intermedio utiliza `external merge` y 11288 kB de espacio en disco.                                       | Sí         | El plan muestra `Sort Method: external merge Disk: 11288kB`.                                                                               |
| El `GroupAggregate` agrupa por `c.id_cliente`.                                                                      | Sí         | El plan indica `Group Key: c.id_cliente`.                                                                                                  |
| El `Sort` final utiliza `quicksort` y 1878 kB de memoria.                                                           | Sí         | Coincide con `Sort Method: quicksort Memory: 1878kB`.                                                                                      |
| El tiempo total de ejecución fue de 363.367 ms.                                                                     | Sí         | El plan indica `Execution Time: 363.367 ms`.                                                                                               |
| El valor de `cost` representa tiempo de ejecución.                                                                  | No         | `cost` es una unidad de costo utilizada por el optimizador y no representa milisegundos.                                                   |
| `cost=45595.08..45645.08` equivale aproximadamente a 45 segundos de ejecución.                                      | No         | El costo estimado no puede convertirse directamente a tiempo. El tiempo real fue 363.367 ms.                                               |
| `actual time` representa tiempo real en milisegundos.                                                               | Sí         | Son mediciones obtenidas durante la ejecución de la consulta.                                                                              |
| `Batches: 2` indica que el hash fue dividido en más de un lote.                                                     | Sí         | El plan muestra `Batches: 2` en el hash construido sobre `pedido`, junto con operaciones temporales.                                       |
| El tercer `Hash Join` consume aproximadamente 158 ms de tiempo propio.                                              | No         | El intervalo `actual time=50.490..208.279` incluye el procesamiento de sus nodos hijos; no representa tiempo exclusivo del `Hash Join`.    |
| El `Sort` intermedio consume aproximadamente 34 ms de tiempo propio.                                                | No         | El intervalo `263.438..297.327` no permite atribuir toda esa diferencia exclusivamente al `Sort`.                                          |
| El `GroupAggregate` consume aproximadamente 51 ms de tiempo propio.                                                 | No         | El intervalo `263.456..348.743` incluye el procesamiento necesario de sus entradas y no debe interpretarse como tiempo exclusivo del nodo. |

## Conclusión

La explicación de la IA fue correcta al identificar la estructura general del plan, los tres `Hash Join`, las condiciones de unión, las entradas `Outer` e `Inner/Build`, los métodos de ordenamiento y el tiempo total de ejecución.

Los principales errores o matices detectados estuvieron relacionados con la interpretación de los tiempos de los nodos. Los valores de `actual time` de los nodos superiores incluyen el procesamiento de sus nodos hijos, por lo que no es correcto tratarlos directamente como tiempos exclusivos de cada operación.

También se verificó que el valor `cost` no representa tiempo de ejecución. El plan utiliza unidades de costo estimadas por el optimizador, mientras que el tiempo real de la consulta fue de **363.367 ms**.

El plan seleccionado no contiene ningún `Nested Loop`, por lo que esa comprobación específica de la consigna no resulta aplicable a este plan. Sí fue posible verificar correctamente la correspondencia entre las entradas `Outer` e `Inner/Build` de los tres `Hash Join`.
