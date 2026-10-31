# Especificación de Vista — v_pedidos_con_cliente

## 1. Identificación de la vista

- **Nombre de la vista:** `v_pedidos_con_cliente`
- **Tipo de objeto:** Vista estándar (`VIEW`)
- **Tablas involucradas:** `pedido`, `cliente`
- **Propósito:** Proveer un acceso consolidado a los datos transaccionales de los pedidos junto con la información identificatoria de contacto del cliente correspondiente, simplificando la emisión de reportes operativos y logísticos.

---

## 2. Requerimientos y columnas a exponer

La vista debe exponer exactamente las siguientes columnas:
- `id_pedido`: Identificador unívoco del pedido (`pedido.id_pedido`).
- `cliente_id`: Identificador del cliente que realizó la compra (`pedido.cliente_id`).
- `fecha_pedido`: Marca temporal con zona horaria de emisión del pedido (`pedido.fecha_pedido`).
- `forma_pago`: Medio de pago utilizado (`pedido.forma_pago`).
- `nombre`: Nombre de pila del cliente (`cliente.nombre`).
- `apellido`: Apellido del cliente (`cliente.apellido`).
- `email`: Correo electrónico del cliente (`cliente.email`).

---

## 3. Definición DDL

```sql
CREATE OR REPLACE VIEW v_pedidos_con_cliente AS
SELECT
    p.id_pedido,
    p.cliente_id,
    p.fecha_pedido,
    p.forma_pago,
    c.nombre,
    c.apellido,
    c.email
FROM pedido p
INNER JOIN cliente c ON c.id_cliente = p.cliente_id;
```

---

## 4. Reglas de diseño, integridad y seguridad

1. **Unión de tablas:** La asociación se realiza mediante `INNER JOIN` utilizando la clave foránea `p.cliente_id = c.id_cliente`. Como `pedido.cliente_id` es obligatorio (`NOT NULL`) y con restricción `ON DELETE RESTRICT`, todos los pedidos existentes conservan su referencia a un cliente válido.
2. **Principio de mínimo privilegio de datos:** La vista expone únicamente las columnas pertinentes para la gestión operativa y de contacto (`nombre`, `apellido`, `email`). Se omiten columnas accesorias o de auditoría interna (`created_at`).
3. **Consideración sobre credenciales:** El esquema actual de la tabla `cliente` no almacena contraseñas, credenciales ni tokens de autenticación. Por tanto, no existe campo sensible de contraseña a excluir; la vista proyecta los datos públicos de contacto sin exponer datos innecesarios.
4. **Comportamiento relacional:** No materializa datos físicamente, garantizando que cualquier modificación o agregado en `pedido` o `cliente` se refleje de manera inmediata al consultar la vista.

---

## 5. Criterios de verificación y validación

1. **Verificación de resultados:**
   - En la base de datos `bd2_tp5`, con 200000 pedidos registrados, la vista debe devolver exactamente **200000 filas**.
2. **Validación de equivalencia funcional:**
   - La vista debe contrastarse frente a la consulta SQL equivalente mediante la operación `EXCEPT` en ambos sentidos:

   ```sql
   -- Sentido 1: Vista menos consulta manual
   (
       SELECT id_pedido, cliente_id, fecha_pedido, forma_pago, nombre, apellido, email
       FROM v_pedidos_con_cliente
   )
   EXCEPT
   (
       SELECT p.id_pedido, p.cliente_id, p.fecha_pedido, p.forma_pago, c.nombre, c.apellido, c.email
       FROM pedido p
       INNER JOIN cliente c ON c.id_cliente = p.cliente_id
   );

   -- Sentido 2: Consulta manual menos vista
   (
       SELECT p.id_pedido, p.cliente_id, p.fecha_pedido, p.forma_pago, c.nombre, c.apellido, c.email
       FROM pedido p
       INNER JOIN cliente c ON c.id_cliente = p.cliente_id
   )
   EXCEPT
   (
       SELECT id_pedido, cliente_id, fecha_pedido, forma_pago, nombre, apellido, email
       FROM v_pedidos_con_cliente
   );
   ```
3. Ambas consultas de verificación deben arrojar exactamente **0 diferencias**.
