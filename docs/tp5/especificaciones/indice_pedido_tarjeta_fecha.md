# Especificación de Índice — idx_pedido_tarjeta_fecha

## 1. Identificación del índice

- **Nombre del índice:** `idx_pedido_tarjeta_fecha`
- **Tabla:** `pedido`
- **Columnas:** `fecha_pedido DESC`
- **Tipo de índice:** B-Tree (parcial)
- **Predicado / Condición:** `WHERE forma_pago = 'TARJETA'`

---

## 2. Patrón de consulta objetivo (Workload)

El índice está diseñado para optimizar consultas frecuentes sobre el historial de pedidos abonados con tarjeta, filtrados por rango de fecha y ordenados cronológicamente de forma descendente (los más recientes primero).

### Consulta principal

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

### Consulta complementaria (Top-N)

```sql
SELECT
    p.id_pedido,
    p.cliente_id,
    p.fecha_pedido,
    p.forma_pago
FROM pedido p
WHERE p.fecha_pedido >= TIMESTAMPTZ '2026-01-01'
  AND p.forma_pago = 'TARJETA'
ORDER BY p.fecha_pedido DESC
LIMIT 100;
```

---

## 3. Definición DDL

```sql
CREATE INDEX idx_pedido_tarjeta_fecha
    ON pedido (fecha_pedido DESC)
    WHERE forma_pago = 'TARJETA';
```

---

## 4. Justificación técnica

1. **Índice parcial:** Al incluir la cláusula `WHERE forma_pago = 'TARJETA'`, el índice almacena únicamente las entradas de pedidos pagados con tarjeta. Esto reduce significativamente el tamaño del árbol B-Tree en memoria y disco en comparación con un índice completo.
2. **Ordenamiento descendente (`DESC`):** Al indexar `fecha_pedido DESC`, PostgreSQL puede recorrer el índice en el mismo orden que requiere la cláusula `ORDER BY p.fecha_pedido DESC`.
3. **Eliminación del paso de ordenamiento (`Sort`):** En consultas con `LIMIT`, el optimizador puede utilizar un `Index Scan` directo y detener el escaneo al alcanzar el límite, eliminando el costo de ordenar todas las filas coincidentes en memoria/disco.
4. **Bajo impacto en escrituras:** Las operaciones de inserción o actualización sobre pedidos con formas de pago distintas a `TARJETA` no requieren actualizar este índice.

---

## 5. Criterios de verificación

- Ejecutar `EXPLAIN (ANALYZE, BUFFERS)` sobre la consulta objetivo antes y después de crear el índice.
- Verificar el reemplazo de `Seq Scan` por `Bitmap Index Scan` / `Bitmap Heap Scan` en la consulta completa.
- Verificar el uso directo de `Index Scan` sin nodo `Sort` en la consulta con `LIMIT`.
- Validar la reducción en tiempos de ejecución y accesos a buffers.
