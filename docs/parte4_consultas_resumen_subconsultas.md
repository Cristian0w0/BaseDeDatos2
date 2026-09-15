# Parte 4 — Consultas resumen y subconsultas bajo especificación precisa

## 1. Metodología

Para el desarrollo de esta etapa se aplicó una metodología orientada a garantizar la precisión y equivalencia de las consultas:
- Se redactaron especificaciones precisas y detalladas antes de generar el código SQL, estableciendo condiciones sobre tablas, filtros, agregaciones, columnas de salida y ordenamiento.
- Se utilizó IA para generar una primera versión de cada consulta ajustada estrictamente a la especificación.
- Se generó una segunda versión con una estructura sintáctica y conceptual diferente para resolver el mismo problema.
- Ambas versiones fueron revisadas analíticamente para constatar el cumplimiento de las restricciones planteadas.
- Se verificó la equivalencia de los resultados mediante el operador de conjuntos `EXCEPT` en ambas direcciones (`A EXCEPT B` y `B EXCEPT A`).

## 2. Consulta 1 — Resumen de productos vigentes por categoría

### Especificación

La consulta debe satisfacer las siguientes condiciones:
- Tablas: `categoria` y `producto`.
- Solo categorías con `activa = TRUE`.
- Solo productos con `activo = TRUE`.
- Incluir categorías activas sin productos activos (mostrando 0 productos).
- Salida: nombre de categoría y cantidad de productos activos.
- Agregación.
- `ORDER BY` cantidad `DESC` y nombre `ASC`.
- Sin `LIMIT`.
- Sin `SELECT *`.

### Versión generada por IA

```sql
SELECT 
    c.nombre,
    COUNT(p.id_producto) AS cantidad_productos_vigentes
FROM categoria c
LEFT JOIN producto p 
    ON c.id_categoria = p.categoria_id 
   AND p.activo = TRUE
WHERE c.activa = TRUE
GROUP BY c.id_categoria, c.nombre
ORDER BY cantidad_productos_vigentes DESC, c.nombre ASC;
```

### Versión alternativa

```sql
SELECT 
    c.nombre,
    (
        SELECT COUNT(p.id_producto)
        FROM producto p
        WHERE p.categoria_id = c.id_categoria
          AND p.activo = TRUE
    ) AS cantidad_productos_activos
FROM categoria c
WHERE c.activa = TRUE
ORDER BY cantidad_productos_activos DESC, c.nombre ASC;
```

### Verificación de equivalencia

Se evaluó la equivalencia de las dos alternativas ejecutando `EXCEPT` en ambas direcciones:

- **A EXCEPT B** → 0 filas.
- **B EXCEPT A** → 0 filas.

No se encontraron diferencias entre los resultados obtenidos por ambas consultas.

## 3. Consulta 2 — Productos por encima del precio promedio

### Especificación

La consulta debe satisfacer las siguientes condiciones:
- Tabla: `producto`.
- Solo productos activos (`activo = TRUE`).
- Promedio calculado únicamente sobre productos activos.
- Precio estrictamente mayor que el promedio.
- Debe utilizar subconsulta.
- Sin `LIMIT` en la subconsulta.
- Salida: `id_producto`, `nombre` y `precio`.
- `ORDER BY` precio `DESC` e `id_producto` `ASC`.
- Sin `LIMIT`.
- Sin `SELECT *`.
- Productos exactamente iguales al promedio quedan excluidos.

### Versión generada por IA

```sql
SELECT 
    p.id_producto,
    p.nombre,
    p.precio
FROM producto p
WHERE p.activo = TRUE
  AND p.precio > (
      SELECT AVG(p2.precio)
      FROM producto p2
      WHERE p2.activo = TRUE
  )
ORDER BY p.precio DESC, p.id_producto ASC;
```

### Versión alternativa

```sql
SELECT 
    p.id_producto,
    p.nombre,
    p.precio
FROM producto p
CROSS JOIN (
    SELECT AVG(p_avg.precio) AS precio_promedio
    FROM producto p_avg
    WHERE p_avg.activo = TRUE
) prom
WHERE p.activo = TRUE
  AND p.precio > prom.precio_promedio
ORDER BY p.precio DESC, p.id_producto ASC;
```

### Verificación de equivalencia

Se evaluó la equivalencia de las dos alternativas ejecutando `EXCEPT` en ambas direcciones:

- **A EXCEPT B** → 0 filas.
- **B EXCEPT A** → 0 filas.

No se encontraron diferencias entre los resultados obtenidos por ambas consultas.

## 4. Conclusión

- Ambas consultas fueron especificadas antes de su implementación.
- Las dos alternativas de cada consulta cumplen los requisitos definidos.
- La equivalencia fue comprobada con `EXCEPT` en ambas direcciones (`A EXCEPT B` y `B EXCEPT A`).
- La validación se realizó sobre la base de trabajo masiva de TP3.
- El resultado no se aceptó solamente porque las consultas ejecutaran correctamente, sino porque se verificó la equivalencia de resultados.
