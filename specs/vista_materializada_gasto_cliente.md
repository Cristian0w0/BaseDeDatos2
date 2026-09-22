# Especificación de Vista Materializada — v_resumen_gasto_cliente

## 1. Identificación de la vista materializada

- **Nombre de la vista materializada:** `v_resumen_gasto_cliente`
- **Tipo de objeto:** Vista materializada (`MATERIALIZED VIEW`)
- **Tablas involucradas:** `cliente`, `pedido`, `detalle_pedido`
- **Propósito:** Precalcular y almacenar de forma persistente el gasto total acumulado por cada cliente a partir de sus pedidos transaccionales y detalles de compra, optimizando sustancialmente la ejecución de reportes analíticos y rankings de clientes.

---

## 2. Requerimientos y columnas a exponer

La vista materializada debe exponer exactamente las siguientes columnas:
- `id_cliente`: Identificador unívoco del cliente (`cliente.id_cliente`).
- `nombre_completo`: Concatenación del nombre y apellido del cliente (`c.nombre || ' ' || c.apellido`).
- `gasto_total`: Suma acumulada del subtotal de las ventas del cliente (`SUM(dp.cantidad * dp.precio_unitario)`).

---

## 3. Definición DDL e Índices asociados

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

-- Índice único obligatorio para permitir actualización concurrente
CREATE UNIQUE INDEX idx_v_resumen_gasto_cliente_cliente
    ON v_resumen_gasto_cliente (id_cliente);
```

---

## 4. Reglas de diseño, mantenimiento y refresco

1. **Poblado inicial:** Se define con la cláusula `WITH DATA` para que la información quede calculada y almacenada de forma inmediata tras la creación de la vista (poblando 20000 filas).
2. **Requisito para refresco concurrente:** El índice único `idx_v_resumen_gasto_cliente_cliente` sobre `id_cliente` es imprescindible para posibilitar el comando `REFRESH MATERIALIZED VIEW CONCURRENTLY v_resumen_gasto_cliente`.
3. **Alta disponibilidad sin bloqueos de lectura:** El refresco concurrente actualiza los datos internamente permitiendo que los usuarios sigan consultando la vista sin sufrir interrupciones ni bloqueos de tablas.
4. **Frecuencia de refresco programado:** Dado que se trata de un reporte de inteligencia de negocios y no de una operación OLTP transaccional, se recomienda un esquema de refresco periódico (ej. cada una hora) para equilibrar la actualización de datos con el costo de cómputo.

---

## 5. Criterios de verificación, impacto de rendimiento y validación

1. **Verificación de volumen de datos:**
   - En la base de datos `bd2_tp5`, la vista materializada debe almacenar exactamente **20000 filas** correspondientes a los clientes con compras registradas.
2. **Impacto en el rendimiento (Medición de consultas):**
   - **Consulta sin vista materializada:** Requiere joins de 3 tablas (`cliente`, `pedido`, `detalle_pedido`) y agregación temporal en disco (`HashAggregate`), con un tiempo de ejecución medido de **207.51 ms**.
   - **Consulta con vista materializada:** Lee directamente los datos precalculados de la vista, logrando un tiempo de ejecución medido de **20.34 ms**.
   - **Mejora obtenida:** Reducción del tiempo de ejecución de **~90.2%** (~187.17 ms de aceleración).
3. **Prueba de refresco concurrente:**
   - La ejecución del comando `REFRESH MATERIALIZED VIEW CONCURRENTLY v_resumen_gasto_cliente;` debe completarse exitosamente y de forma transparente sin generar excepciones ni bloqueos exclusivos.
