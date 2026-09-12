# Parte 3 — Ejercicio de lectura crítica

## Introducción

En la administración y desarrollo de bases de datos relacionales, una sentencia SQL puede ser completamente válida desde el punto de vista sintáctico y ejecutarse sin lanzar errores en PostgreSQL, pero aun así provocar resultados desastrosos o totalmente contrarios a la regla de negocio prevista. El motor de la base de datos ejecuta de manera declarativa e inmediata las instrucciones recibidas; no interpreta la "intención" del desarrollador.

Por esta razón, la lectura crítica y la verificación previa de cada sentencia SQL antes de su ejecución constituyen una línea fundamental de defensa. Este proceso se integra directamente con las buenas prácticas de la ingeniería de datos y el protocolo de seguridad del proyecto:
* **Uso de transacciones explícitas (`BEGIN ... ROLLBACK`):** Probar las sentencias de modificación (`UPDATE`, `DELETE`) dentro de un bloque de transacción que permita verificar el número de filas afectadas (`GET DIAGNOSTICS` o el reporte del cliente SQL) antes de confirmar con `COMMIT`.
* **Transformación a `SELECT` previa:** Convertir sentencias destructivas en consultas de lectura equivalentes antes de modificar los datos para auditar de forma visual qué registros serían impactados.
* **Resguardos y respaldos:** Mantener copias de seguridad (`pg_dump`) y esquemas de prueba antes de aplicar modificaciones masivas sobre entornos de producción o staging.

---

## Script 1 — Baja de funciones retiradas

### Script original

```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartel
UPDATE funcion
SET activa = FALSE;
```

### Qué hace realmente

Modifica de forma incondicional el atributo `activa` de **todos** los registros presentes en la tabla `funcion`, asignándole el valor booleano `FALSE`.

### Qué filas afectaría

Afectaría al **100% de las filas** existentes en la tabla `funcion`.

### Explicación del problema

El script carece de una cláusula `WHERE`. En el lenguaje SQL, una instrucción `UPDATE` sin cláusula `WHERE` se aplica sobre la totalidad de la tabla. 

La intención expresada en el comentario del script es *"dar de baja las funciones de películas retiradas de cartel"*. Sin embargo, al no aplicar ningún filtro, el script desactiva indistintamente tanto las funciones asociadas a películas retiradas como aquellas correspondientes a películas actualmente en cartelera o futuras. Esto produciría una indisponibilidad total e indebida de la cartelera activa del sistema.

### Versión corregida

#### Supuestos sobre el esquema
Dado que el enunciado presenta un esquema genérico, se asumen los siguientes elementos:
1. Existe una relación entre la tabla `funcion` y una tabla `pelicula` a través de la clave foránea `funcion.pelicula_id = pelicula.id`.
2. La tabla `pelicula` posee una columna que indica si la película ha sido retirada de cartel (por ejemplo, `pelicula.retirada = TRUE` o `pelicula.en_cartelera = FALSE`).

#### Propuesta 1: Uso de subconsulta en la cláusula `WHERE` (Estándar SQL)

```sql
UPDATE funcion
SET activa = FALSE
WHERE pelicula_id IN (
    SELECT id
    FROM pelicula
    WHERE retirada = TRUE
);
```

#### Propuesta 2: Uso de sintaxis `UPDATE ... FROM` (Específica y eficiente en PostgreSQL)

```sql
UPDATE funcion f
SET activa = FALSE
FROM pelicula p
WHERE f.pelicula_id = p.id
  AND p.retirada = TRUE;
```

#### Justificación de la corrección
Al incorporar la cláusula `WHERE` vinculada a la condición del estado de la película (`retirada = TRUE`), el alcance de la sentencia `UPDATE` se limita estrictamente a aquellas funciones cuyo `pelicula_id` pertenece a películas retiradas, preservando intactas las funciones de las películas activas.

---

## Script 2 — Categorías sin productos

### Script original

```sql
-- Generado para: limpiar las categorías sin productos asociados
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

### Qué intenta hacer

Eliminar de la tabla `categoria` únicamente aquellos registros que no tengan ningún producto asociado en la tabla `producto` (es decir, categorías "huérfanas" o vacías).

### Explicación del problema: `NOT IN` y valores `NULL`

El problema principal radica en cómo opera la comparación `NOT IN` en SQL cuando la subconsulta puede retornar valores nulos (`NULL`), debido a la **lógica trivaluada** (*Three-Valued Logic*: `TRUE`, `FALSE`, `UNKNOWN`).

La expresión `id NOT IN (SELECT categoria_id FROM producto)` se traduce lógicamente a una cadena de desigualdades unidas por el operador `AND`:

$$\text{id} \neq \text{val}_1 \land \text{id} \neq \text{val}_2 \land \dots \land \text{id} \neq \text{val}_n$$

Si existe al menos un registro en la tabla `producto` donde `categoria_id` sea `NULL` (por ejemplo, un producto libre o sin categoría asignada), la lista retornada por la subconsulta contendrá al menos un elemento `NULL`.

En SQL, cualquier comparación directa con un valor `NULL` (como `id <> NULL`) se evalúa como `UNKNOWN`. Dado que en la lógica de proposiciones de SQL:
* `TRUE AND UNKNOWN` $\rightarrow$ `UNKNOWN`
* `FALSE AND UNKNOWN` $\rightarrow$ `FALSE`

La condición entera del `WHERE` se evaluará como `UNKNOWN` o `FALSE` para **todas** las filas de la tabla `categoria`. Puesto que una sentencia `DELETE` (al igual que `SELECT` o `UPDATE`) solo procesa aquellas filas donde la condición del `WHERE` se evalúa estrictamente a `TRUE`, **el script no eliminará ninguna fila**. El script fallará silenciosamente en cumplir su objetivo, sin arrojar ningún error de sintaxis pero dejando la base de datos sin modificar.

### Versión corregida preferente (`NOT EXISTS`)

```sql
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1
    FROM producto p
    WHERE p.categoria_id = c.id
);
```

### Explicación paso a paso de `NOT EXISTS`

1. **Subconsulta correlacionada:** Para cada fila de la tabla `categoria` (con alias `c`), la subconsulta evalúa si existe al menos un registro en `producto` (alias `p`) que cumpla la condición `p.categoria_id = c.id`.
2. **Evaluación booleana clara:** 
   * Si existe al menos un producto asociado a la categoría `c.id`, la subconsulta devuelve filas (`TRUE`), haciendo que `NOT EXISTS` se evalúe a `FALSE`. Por lo tanto, dicha categoría **no se elimina**.
   * Si no existe ningún producto asociado a esa categoría, la subconsulta devuelve un conjunto vacío (`FALSE`), haciendo que `NOT EXISTS` se evalúe a `TRUE`. Por lo tanto, la categoría **es eliminada**.
3. **Manejo seguro de `NULL`:** Si la columna `producto.categoria_id` contiene valores `NULL`, la condición `p.categoria_id = c.id` simplemente resulta `UNKNOWN`/`FALSE` para esos productos individuales, sin contaminar la evaluación global del conjunto para la categoría `c.id`.

### Alternativa: Filtrado explícito de `NULL` en `NOT IN`

Otra solución técnicamente válida consiste en excluir explícitamente los valores nulos dentro de la subconsulta:

```sql
DELETE FROM categoria
WHERE id NOT IN (
    SELECT categoria_id
    FROM producto
    WHERE categoria_id IS NOT NULL
);
```

**Comparación:** Aunque esta alternativa soluciona el problema de los nulos, se prefiere `NOT EXISTS` por sobre `NOT IN` porque es semánticamente más clara respecto a la intención de verificar la existencia de relaciones entre tablas, y en PostgreSQL suele permitir una optimización de plan de ejecución (Anti-Join) más eficiente y robusta.

---

## Conclusión

El análisis de ambos scripts evidencia la idea central de esta práctica: **la validez sintáctica no garantiza la corrección semántica**.

1. **El Script 1** era sintácticamente correcto, pero al omitir el filtro `WHERE`, habría provocado una modificación masiva no deseada de datos al desactivar el 100% de las funciones.
2. **El Script 2** era sintácticamente correcto, pero debido al comportamiento sutil de la lógica trivaluada de SQL con `NOT IN` frente a valores `NULL`, habría resultado en una operación inerte que no habría eliminado ninguna categoría.

La decisión de aplicar un cambio sobre una base de datos debe sustentarse siempre en la **lectura crítica previa**, el entendimiento riguroso del comportamiento del motor ante valores nulos y filtrados, y el uso adecuado de entornos de prueba y transacciones seguras.
