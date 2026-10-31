# Especificación de Índice — idx_producto_activo_precio

## 1. Identificación del índice

- **Nombre del índice:** `idx_producto_activo_precio`
- **Tabla:** `producto`
- **Columnas:** `precio DESC`
- **Tipo de índice:** B-Tree (parcial)
- **Predicado / Condición:** `WHERE activo = TRUE`

---

## 2. Patrón de consulta objetivo (Workload)

El índice está diseñado para optimizar consultas de productos vigentes (activos) ordenados por precio de forma descendente, especialmente aquellas que solicitan los productos de mayor precio mediante un límite de resultados (`LIMIT`).

### Consulta principal (Top-N de productos activos)

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

---

## 3. Definición DDL

```sql
CREATE INDEX idx_producto_activo_precio
    ON producto (precio DESC)
    WHERE activo = TRUE;
```

---

## 4. Justificación técnica

1. **Índice parcial:** Al incluir la cláusula `WHERE activo = TRUE`, el índice excluye los productos inactivos, reduciendo el tamaño del árbol B-Tree y manteniendo únicamente los registros vigentes relevantes para el catálogo activo.
2. **Ordenamiento descendente (`DESC`):** Al indexar `precio DESC`, PostgreSQL puede recorrer las hojas del índice directamente en el orden que requiere la cláusula `ORDER BY p.precio DESC`.
3. **Eliminación del paso de ordenamiento (`Sort`):** En consultas con `LIMIT`, el optimizador puede utilizar un `Index Scan` directo y detener el escaneo apenas alcanza el límite solicitado, eliminando el costo de recorrer toda la tabla y realizar una operación de `Sort` en memoria.
4. **Bajo impacto en escrituras:** Las modificaciones o inserciones de productos inactivos (`activo = FALSE`) no requieren actualizar este índice.

---

## 5. Criterios de verificación

- Ejecutar `EXPLAIN (ANALYZE, BUFFERS)` sobre la consulta objetivo antes y después de crear el índice.
- Verificar el paso de un `Seq Scan` seguido de un `Sort` a un `Index Scan` directo sobre `idx_producto_activo_precio`.
- Confirmar la eliminación del nodo `Sort` en el plan de ejecución.
- Validar la reducción significativa en tiempo de ejecución (aproximadamente un 98% de mejora) y accesos a buffers.
