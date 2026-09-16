# Declaración de Uso de IA (DUIA) — TP3

## Uso responsable de herramientas de IA

Durante el desarrollo del TP3 se utilizaron herramientas de inteligencia artificial como apoyo para proponer alternativas, analizar resultados y redactar documentación. Las propuestas generadas por IA no se aplicaron de forma automática: fueron verificadas mediante ejecución de consultas, `EXPLAIN (ANALYZE, BUFFERS)`, pruebas controladas con `BEGIN/ROLLBACK` y, cuando correspondía, comprobaciones formales de equivalencia mediante `EXCEPT`.

Se aplicó como criterio general:

> **La IA propone, el estudiante verifica.**

### Registro de usos relevantes de IA

| Herramienta  | Para qué se usó                                                                         | Prompt / spec (resumen)                                                                                                                                                               | Se aceptó / se descartó — por qué                                                                                                                                                                                                                                                                                                         |
| ------------ | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **OpenCode** | Proponer optimizaciones para las consultas de la Parte 2.                               | Se proporcionaron las consultas, los planes de ejecución y las mediciones iniciales. Se solicitó analizar los planes y proponer índices u otras alternativas de optimización.         | **Se aceptaron** las propuestas que demostraron mejora mediante `EXPLAIN (ANALYZE, BUFFERS)`. Se **descartó** la propuesta para la Consulta 3 porque la medición no mostró una mejora significativa y el plan continuó utilizando un `Seq Scan`.                                                                                          |
| **OpenCode** | Analizar y explicar el plan de ejecución de la optimización seleccionada en la Parte 3. | Se proporcionó el plan final de `EXPLAIN (ANALYZE, BUFFERS)` y se solicitó explicar los nodos, costos estimados, filas, buffers, condiciones de índice y tiempos.                     | **Se utilizó como apoyo**, pero no se aceptaron todas las explicaciones literalmente. Se detectaron y corrigieron imprecisiones relacionadas con `shared hit`, `read`, `width` y la interpretación de los buffers.                                                                                                                        |
| **OpenCode** | Generar las consultas de la Parte 4 a partir de las especificaciones.                   | Se proporcionaron las especificaciones funcionales: categorías activas con cantidad de productos activos y productos activos cuyo precio supera el promedio de los productos activos. | **Se aceptaron** las consultas generadas después de verificar que cumplían la especificación. Se comprobó formalmente la equivalencia entre las variantes mediante `EXCEPT` en ambas direcciones.                                                                                                                                         |
| **OpenCode** | Proponer alternativas de optimización para la consulta experimental de la Parte 5.      | Se proporcionó la consulta de competencia utilizada como variante experimental y se solicitaron estrategias para reducir su tiempo de ejecución.                                      | Se evaluaron **cuatro propuestas** mediante mediciones reales. Las propuestas 1, 2 y 3 fueron **descartadas** porque no mejoraron el tiempo de ejecución respecto de la referencia. La propuesta 4 fue **aceptada para esta variante experimental** porque redujo el tiempo de ejecución y mantuvo equivalencia con la consulta original. |
| **OpenCode** | Revisar y ayudar a redactar la documentación del TP3.                                   | Se proporcionaron resultados, planes, mediciones y decisiones tomadas durante las pruebas. Se solicitó organizar y explicar la información de las Partes 2, 3, 4 y 5.                 | **Se utilizó como apoyo de documentación**, manteniendo como criterio que los resultados técnicos provinieran de las verificaciones realizadas sobre la base de datos y no de afirmaciones de la IA sin comprobar.                                                                                                                        |

## Verificaciones realizadas por el estudiante

Las propuestas de IA fueron sometidas a verificaciones prácticas antes de incorporarlas al trabajo.

### Parte 2

Para las propuestas de índices se realizaron mediciones con `EXPLAIN (ANALYZE, BUFFERS)` antes y después. Los cambios aceptados fueron los que mostraron una mejora medible en las condiciones de prueba.

La propuesta para la Consulta 3 fue descartada porque el índice propuesto no produjo una mejora observable y el plan continuó utilizando un recorrido secuencial de `detalle_pedido`.

### Parte 3

La explicación generada por IA fue revisada críticamente. Se identificaron afirmaciones que excedían lo que podía demostrarse directamente a partir del plan de ejecución. Estas afirmaciones fueron corregidas en la documentación final.

### Parte 4

Las consultas alternativas se verificaron mediante:

```sql
consulta_original
EXCEPT
consulta_alternativa;
```

y:

```sql
consulta_alternativa
EXCEPT
consulta_original;
```

En ambos sentidos se obtuvieron **0 filas**, por lo que las variantes fueron consideradas equivalentes sobre los datos utilizados para la verificación.

### Parte 5

Las propuestas de optimización fueron probadas de manera controlada. Los cambios experimentales se realizaron dentro de transacciones y se revirtieron mediante `ROLLBACK` cuando no correspondía conservarlos.

La propuesta finalmente seleccionada para la variante experimental fue verificada nuevamente con `EXPLAIN (ANALYZE, BUFFERS)` y mediante `EXCEPT` en ambas direcciones.

## Participación del estudiante

La IA se utilizó como herramienta de apoyo para generar propuestas, alternativas y explicaciones. La selección de cambios, la ejecución de las consultas, la interpretación de los resultados, la validación de equivalencia y la decisión de aceptar o descartar cada propuesta fueron realizadas mediante verificación sobre la base de datos de trabajo.

No se consideró válida una propuesta únicamente por haber sido generada por la IA.

**Criterio aplicado durante el TP3:**

> **La IA propone, el estudiante verifica.**
