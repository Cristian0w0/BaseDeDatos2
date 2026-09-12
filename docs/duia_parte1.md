# DUIA — Parte 1: Integridad versionada

## Herramienta utilizada

* Herramienta: OpenCode 1.18.23
* Proveedor: Google
* Modelo: Gemini 3.6 Flash

## Spec / reglas de negocio

Regla 1: Todo registro de pedido en la tabla pedido debe tener al menos un registro asociado en la tabla detalle_pedido mediante la columna detalle_pedido.pedido_id.

Regla 2: No se debe permitir que existan dos registros en la tabla producto con el mismo valor en producto.nombre cuando pertenezcan a la misma categoría mediante producto.categoria_id.

## Prompt utilizado en OpenCode — modo Plan

Quiero implementar las siguientes dos reglas de integridad para mi proyecto Food Store:

Regla 1: Todo registro de pedido en la tabla pedido debe tener al menos un registro asociado en la tabla detalle_pedido mediante la columna detalle_pedido.pedido_id.

Regla 2: No se debe permitir que existan dos registros en la tabla producto con el mismo valor en producto.nombre cuando pertenezcan a la misma categoría mediante producto.categoria_id.

Analizá el esquema actual de db/schema.sql y proponé un plan de implementación para garantizar estas dos reglas en PostgreSQL.

IMPORTANTE:

* Trabajá solamente en modo Plan.
* No crees ni modifiques ningún archivo.
* No ejecutes cambios sobre la base de datos.
* Para cada regla explicá qué mecanismo de PostgreSQL proponés y por qué.
* Considerá especialmente cómo garantizar la Regla 1 sin impedir el flujo normal de crear un pedido y luego sus detalles dentro de una misma transacción.

## Qué generó OpenCode

OpenCode propuso:

* Para la Regla 1, una función en PL/pgSQL y dos `CONSTRAINT TRIGGER` diferibles (`DEFERRABLE INITIALLY DEFERRED`).
* Para la Regla 2, una restricción `UNIQUE` sobre las columnas `producto.categoria_id` y `producto.nombre`.

La propuesta fue revisada antes de aplicarla y se aceptó.

## Prompt utilizado para implementar

El plan está aprobado. Implementalo modificando únicamente db/schema.sql.

No modifiques ningún otro archivo.
No ejecutes cambios sobre la base de datos.
No hagas commits.

## Qué se aceptó

Se aceptó la implementación propuesta por OpenCode:

* `uq_producto_categoria_nombre` para garantizar que el nombre de un producto no se repita dentro de una misma categoría.
* `fn_validar_pedido_tiene_detalle()` para validar que un pedido tenga al menos un detalle.
* `trg_validar_pedido_con_detalle` para validar los pedidos.
* `trg_validar_detalle_minimo` para evitar que un pedido quede sin detalles al modificar o eliminar detalles.

También se aceptó que los triggers de la Regla 1 fueran `DEFERRABLE INITIALLY DEFERRED`, permitiendo crear primero el pedido y agregar posteriormente sus detalles dentro de la misma transacción.

## Qué se modificó o descartó y por qué

No se modificó el código generado por OpenCode después de la revisión.

La propuesta opcional de utilizar una restricción de unicidad basada en valores normalizados mediante `lower()` y `trim()` no fue incorporada, porque la regla definida exige evitar duplicados con el mismo valor de `producto.nombre` dentro de una misma categoría, sin agregar una regla adicional sobre mayúsculas, minúsculas o espacios.

## Verificación realizada

Las pruebas se realizaron sobre la base de trabajo `tp_bd2_trabajo`.

### Regla 2 — nombre único por categoría

Se creó la categoría:

* `Bebidas`, `id_categoria = 3`

Se insertó correctamente:

* `Coca Cola`
* `categoria_id = 3`

Luego se intentó insertar otro producto con:

* `nombre = Coca Cola`
* `categoria_id = 3`

PostgreSQL rechazó la operación con el error `23505`, indicando la violación de la restricción `uq_producto_categoria_nombre`.

Resultado: **prueba inválida rechazada correctamente**.

También se utilizó un `SAVEPOINT` para recuperar la transacción después del intento inválido.

### Regla 1 — pedido con al menos un detalle

Se creó correctamente un pedido sin detalles inicialmente.

Al ejecutar `SET CONSTRAINTS ALL IMMEDIATE`, PostgreSQL rechazó la situación con el mensaje:

`El pedido 1 debe contener al menos un detalle.`

Resultado: **pedido sin detalle rechazado correctamente**.

Luego se creó otro pedido y se agregó un detalle:

* `pedido_id = 2`
* `producto_id = 5`
* `cantidad = 1`
* `precio_unitario = 1000.00`

Al ejecutar nuevamente `SET CONSTRAINTS ALL IMMEDIATE`, no se produjo ningún error.

Resultado: **pedido con detalle aceptado correctamente**.

## Verificación final

Después de las pruebas se realizó `COMMIT`.

Posteriormente se verificó que continuaran existiendo:

* la restricción `uq_producto_categoria_nombre`;
* la función `fn_validar_pedido_tiene_detalle`;
* el trigger `trg_validar_pedido_con_detalle`;
* el trigger `trg_validar_detalle_minimo`.

Las cuatro verificaciones devolvieron `true`.

## Versionado

El cambio realizado en `db/schema.sql` fue guardado en Git mediante el commit:

`9b0f71e — Garantizar pedidos con detalle y nombres únicos por categoría`
