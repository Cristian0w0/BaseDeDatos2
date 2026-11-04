# Bitácora de Uso de Inteligencia Artificial
## Asignatura: Base de Datos II · Tecnicatura Universitaria en Programación (UTN)
### Proyecto Integrador: Food Store · Unidad 8: Bases de Datos Móviles e Integración
**Estudiante / Integrante:** Cristian Rodriguez (`Cloverfield`)  
**Ciclo Lectivo:** 2026  

---

### Entrada 1 · Especificación del Esquema Móvil y Restricciones de Sincronización
* **Fecha:** 3 de Noviembre de 2026
* **Herramienta / Agente:** Antigravity / OpenCode
* **Qué se le pidió a la IA:**  
  *"Diseñá el esquema SQLite para la base embebida de la tablet respetando el modo STRICT, precios en centavos y claves foráneas. Asegurá que no se puedan duplicar solicitudes de sincronización para un mismo pedido borrador."*
* **Qué propuso la IA:**  
  La IA propuso crear la tabla `cola_sync` con una restricción `UNIQUE (id_local)`, argumentando que con ello se aseguraba que ningún borrador fuera sincronizado más de una vez.
* **Comprobación en el motor:**  
  Al ejecutar el caso de prueba C2 (conflicto de precios resuelto), el borrador inicial quedó en estado `CONFLICTO`. Tras la aceptación del nuevo precio por parte del cliente, la tablet debió registrar una nueva solicitud de envío con un nuevo `solicitud_uuid` referenciando al mismo `id_local`. Con la propuesta de la IA, la operación fue abortada inmediatamente por SQLite: `sqlite3.IntegrityError: UNIQUE constraint failed: cola_sync.id_local`.
* **Qué se aceptó y qué se descartó (Decisión con Fundamento):**  
  * **DESCARTADO:** Se descartó la restricción `UNIQUE (id_local)`. Un mismo pedido borrador puede atravesar múltiples ciclos de envío a lo largo de su ciclo de vida (por ejemplo, tras renegociar una tarifa con el comensal).
  * **ADOPTADO:** Se implementó en su lugar el índice parcial condicional:
    ```sql
    CREATE UNIQUE INDEX ux_cola_una_pendiente ON cola_sync (id_local) WHERE estado = 'PENDIENTE';
    ```
    Esta regla impide con precisión que un borrador tenga dos solicitudes pendientes concurrentes, pero permite envíos sucesivos una vez resuelto el conflicto.

---

### Entrada 2 · Concurrencia y Serialización de Stock en el Servidor Central
* **Fecha:** 3 de Noviembre de 2026
* **Herramienta / Agente:** Antigravity / OpenCode
* **Qué se le pidió a la IA:**  
  *"Revisá el procedimiento `sp_crear_pedido` en PostgreSQL para asegurar que los pedidos validados desde tablets móviles no generen carreras críticas si varias terminales intentan comprar el último ítem disponible."*
* **Qué propuso la IA:**  
  La IA sugirió incorporar una cláusula de bloqueo pesimista a nivel de fila mediante `SELECT ... FOR UPDATE` al momento de comprobar la disponibilidad de stock, antes de aplicar el `UPDATE` que decrementa las unidades.
* **Comprobación en el motor:**  
  Se configuró una prueba de carga simulada con dos sesiones paralelas en `psql` apuntando a un producto con `stock = 1`. Sin el `FOR UPDATE`, ambas sesiones leyeron `1` de manera simultánea e intentaron realizar la compra, resultando una de ellas en fallo abrupto de la restricción `CHECK (stock >= 0)` o en inconsistencias de inventario (*lost update*).
* **Qué se aceptó y qué se descartó (Decisión con Fundamento):**  
  * **ACEPTADO Y VERIFICADO:** Se incorporó el bloqueo pesimista en `sp_crear_pedido`:
    ```sql
    SELECT stock INTO v_stock 
    FROM producto 
    WHERE id_producto = v_item.producto_id 
    FOR UPDATE;
    ```
    Esto garantiza aislamiento transaccional y previene sobreventas en ferias gastronómicas con múltiples terminales activas.

---

### Entrada 3 · Política de Permisos y Roles de Soporte
* **Fecha:** 3 de Noviembre de 2026
* **Herramienta / Agente:** Antigravity / OpenCode
* **Qué se le pidió a la IA:**  
  *"Definí los privilegios necesarios para el rol `rol_soporte` de manera que pueda auditar incidencias y consultar pedidos en la base de datos."*
* **Qué propuso la IA:**  
  La IA propuso otorgar privilegios masivos de lectura ejecutando `GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_soporte;` para facilitar la visibilidad de todas las tablas del sistema.
* **Comprobación en el motor:**  
  Al revisar el contenido de la tabla `usuario` en PostgreSQL, se verificó que almacena datos personales críticos (mails, teléfonos) y hashes criptográficos de contraseñas de administradores generados con `crypt(..., gen_salt('bf'))`. Con la sugerencia de la IA, cualquier operador con credenciales de soporte podía ejecutar `SELECT contrasena FROM usuario;`.
* **Qué se aceptó y qué se descartó (Decisión con Fundamento):**  
  * **DESCARTADO:** Se descartó categóricamente el `GRANT SELECT ON ALL TABLES`, por violar el principio de mínimo privilegio y vulnerar el Art. 9 de la Ley Nacional 25.326 de Protección de Datos Personales.
  * **ADOPTADO:** Se crearon vistas de proyección restringida (`v_usuarios_publico` sin hashes ni celulares, y `v_snapshot_movil` sin datos de clientes), otorgando permisos exclusivamente sobre las vistas autorizadas.
