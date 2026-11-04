# Diseño Técnico - Food Store Móvil e Integración (Unidad 8 / TP8)
## Arquitectura de Sincronización y Capa de Datos

### 1. Arquitectura Offline-First y Regla de Oro
El sistema Food Store en su modalidad Food Truck opera bajo el patrón de diseño arquitectónico **Offline-First**. 
* **Regla de Oro:** *"El móvil propone, el servidor dispone"*. La tablet es un cliente ligero dotado de una base de datos embebida relacional (SQLite 3.37+) cuyo rol se limita a la exhibición del menú y al armado de borradores de pedidos.
* **Fuente de Verdad:** PostgreSQL 16+ es la única autoridad sobre los datos maestros (precios oficiales, stock real, identidades y facturación formal).

---

### 2. Esquema Embebido en SQLite (STRICT Tables)
Para evitar la flexibilidad tipográfica predeterminada de SQLite y garantizar consistencia estricta:
1. **`producto_cache` (STRICT):**
   - Precios guardados como enteros en centavos (`precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0)`), eliminando el error de redondeo de punto flotante.
   - Manejo de bajas mediante banderas enteras binarias: `eliminado IN (0, 1)` y `disponible_visto IN (0, 1)`.
2. **`pedido_borrador` (STRICT):**
   - Identificador `id_local TEXT PRIMARY KEY` basado en UUID generado en la tablet.
   - Formas de pago restringidas: `CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA'))`.
3. **`item_borrador` (STRICT):**
   - Clave primaria compuesta `(id_local, producto_id)`.
   - Clave foránea con borrado en cascada `REFERENCES pedido_borrador(id_local) ON DELETE CASCADE`.
   - Restricción estricta de cantidad: `CHECK (cantidad > 0)`.
4. **`cola_sync` (STRICT):**
   - `solicitud_uuid TEXT PRIMARY KEY` para garantizar idempotencia en reenvíos.
   - Índice único parcial: `CREATE UNIQUE INDEX ux_cola_una_pendiente ON cola_sync (id_local) WHERE estado = 'PENDIENTE';` que impide carreras de envíos simultáneos para un mismo borrador sin bloquear reintentos tras resolver conflictos.

---

### 3. Modelo de Bajas Lógicas (Lápidas / Tombstones)
Si en el servidor central se borrase un producto con `DELETE`, la tablet desconectada no tendría forma de enterarse. Por tal motivo, se adopta el patrón de **Lápida (*Tombstone*)**:
* En PostgreSQL, la vista `v_snapshot_movil` calcula `(NOT p.activo OR NOT c.activa) AS eliminado`.
* La baja viaja como dato a la tablet, donde `producto_cache.eliminado = 1` oculta el ítem de la vista del vendedor (`v_catalogo_disponible`), pero conserva la fila en disco para preservar la integridad referencial de los borradores existentes.

---

### 4. Máquina de Estados del Semáforo
```
                      +-------------------+
                      |     PENDIENTE     |
                      +-------------------+
                                |
             +------------------+------------------+
             |                                     |
    ¿Falta stock / Baja?               ¿Precio distinto?
             |                                     |
             v                                     v
     +---------------+                     +---------------+
     |   RECHAZADO   | (Rojo)              |   CONFLICTO   | (Amarillo)
     +---------------+                     +---------------+
                                                   |
                                       Cliente acepta precio nuevo
                                                   |
                                                   v
                                        +---------------------+
                                        |  SIMULADO_APROBADO  | (Verde)
                                        +---------------------+
```
* **Precedencia:** El color Rojo (`RECHAZADO`) tiene prioridad máxima sobre el Amarillo (`CONFLICTO`).
* **Idempotencia:** El semáforo solo procesa filas con `estado = 'PENDIENTE'`.
