# Requisitos del Sistema - Food Store Móvil (Unidad 8 / TP8)
## Especificación Kiro en Notación EARS (Easy Approach to Requirements Syntax)

### REQ-01 · Catálogo de Productos Offline (State-Driven)
**Definición:**  
`WHILE` la aplicación en la tablet se encuentra operando sin conectividad de red con el servidor central,  
`THE SYSTEM SHALL` permitir la consulta visual y búsqueda de productos vigentes y no eliminados a través de la vista `v_catalogo_disponible` leyendo de la base embebida SQLite local.  
* **Caso de prueba que lo verifica:** **Caso C1** (Consulta del catálogo local sin conexión al servidor).

---

### REQ-02 · Detección de Conflicto Tarifario (Event-Driven)
**Definición:**  
`WHEN` una solicitud de sincronización en estado `PENDIENTE` es evaluada contra la instantánea del servidor (`snapshot_servidor`) y el precio de lista vigente difiere del precio congelado en el borrador (`precio_centavos_visto != precio_centavos`),  
`THE SYSTEM SHALL` marcar el estado de la solicitud en `cola_sync` como `CONFLICTO`, registrar el motivo explícito y requerir la reconfirmación del cliente en mostrador antes de permitir su aprobación.  
* **Caso de prueba que lo verifica:** **Caso C2** (Aumento tarifario de la Pizza Muzzarella a $10.500 resuelto satisfactoriamente).

---

### REQ-03 · Quiebre de Stock y Bajas Lógicas (Event-Driven / Prioridad)
**Definición:**  
`WHEN` al menos un ítem del pedido borrador requiere una cantidad superior al stock real en el servidor (`cantidad > stock`) O el producto ha sido dado de baja lógica (`eliminado = 't'`) O no está disponible para venta (`disponible = 'f'`),  
`THE SYSTEM SHALL` clasificar la solicitud en `cola_sync` como `RECHAZADO` con precedencia absoluta sobre cualquier advertencia de precio, impidiendo el envío y preservando inalterado el stock central.  
* **Casos de prueba que lo verifican:** **Caso C3** (Quiebre de stock) y **Caso C4** (Baja lógica / lápida).

---

### REQ-04 · Idempotencia y Protección ante Reintentos (Event-Driven)
**Definición:**  
`WHEN` la aplicación móvil reintenta el envío de una solicitud de pedido ya evaluada utilizando el mismo identificador único `solicitud_uuid`,  
`THE SYSTEM SHALL` rechazar la duplicación a nivel de clave primaria en `cola_sync` y devolver el resultado previamente obtenido sin reevaluar ni duplicar la orden en PostgreSQL.  
* **Caso de prueba que lo verifica:** **Caso C6** (Reenvío idéntico de solicitud C5 con UUID duplicado).

---

### REQ-05 · Integridad Estricta de Borradores (Unwanted Behavior)
**Definición:**  
`IF` se intenta registrar un renglón de pedido con cantidad menor o igual a cero (`cantidad <= 0`) O referenciando a un identificador de producto inexistente en `producto_cache`,  
`THEN THE SYSTEM SHALL` abortar la transacción inmediatamente por violación de restricciones de integridad (`CHECK` / `FOREIGN KEY`), garantizando que ninguna fila inválida o huérfana persista en la base.  
* **Caso de prueba que lo verifica:** **Caso C7** (Rechazo controlado de datos inválidos).
