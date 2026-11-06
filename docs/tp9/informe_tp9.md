# TRABAJO PRÁCTICO · UNIDAD 7: NoSQL y nuevas formas de almacenamiento
## Base de Datos II - Tecnicatura Universitaria en Programación (UTN)
### Caso de Estudio: Food Store (PostgreSQL vs. MongoDB)

**Estudiante / Integrante:** Cristian Rodriguez (`Cloverfield`)  
**Repositorio de Trabajo:** `https://github.com/Cristian0w0/BaseDeDatos2.git`  
**Rama de Entrega:** `tp9-nosql` | **Fecha:** Ciclo Lectivo 2026  
**Entorno de Pruebas:** PostgreSQL 17.11 (base `foodstore`) & MongoDB 9.0.4 (`mongosh`, base `foodstore_nosql`)

---

## Parte 1 · Modelo documental y migración

### Consigna 1: Selección del subconjunto y diseño del modelo documental

#### 1. Identificación del subconjunto relacional en PostgreSQL
Para representar la gestión de ventas de **Food Store**, se seleccionó el subconjunto transaccional compuesto por **pedidos** y sus correspondientes **detalles de pedido**, complementado con los datos de **clientes** y **productos** vigentes al momento de la transacción.

En la base relacional PostgreSQL (`schema.sql`), este subconjunto involucra las siguientes tablas, claves primarias (PK) y claves foráneas (FK):

| Tabla | Clave Primaria (PK) | Claves Foráneas (FK) | Descripción y Atributos Clave |
| :--- | :--- | :--- | :--- |
| **`pedido`** | `id_pedido` (`BIGINT GENERATED ALWAYS AS IDENTITY`) | `cliente_id` $\rightarrow$ `cliente(id_cliente)` (`ON DELETE RESTRICT`) | Cabecera del pedido: almacena `fecha_pedido` (`TIMESTAMPTZ`), `forma_pago` (`ENUM: EFECTIVO, TARJETA, TRANSFERENCIA`) y `estado` (`ENUM: PENDIENTE, CONFIRMADO, ENTREGADO, CANCELADO`). |
| **`detalle_pedido`** | `(pedido_id, producto_id)` (`PK compuesta`) | `pedido_id` $\rightarrow$ `pedido(id_pedido)`<br>`producto_id` $\rightarrow$ `producto(id_producto)` | Ítems de la orden: almacena `cantidad` (`CHECK > 0`) y `precio_unitario` (`NUMERIC(12,2) >= 0`, precio histórico pactado). |
| **`cliente`** | `id_cliente` (`BIGINT GENERATED ALWAYS AS IDENTITY`) | Ninguna | Entidad compradora: `nombre`, `apellido`, `email` (`UNIQUE`). |
| **`producto`** | `id_producto` (`BIGINT GENERATED ALWAYS AS IDENTITY`) | `categoria_id` $\rightarrow$ `categoria(id_categoria)` | Catálogo de productos: `nombre`, `precio` (precio actual de lista), `stock`, `activo`. |

> **Nota de integridad relacional**: En PostgreSQL no se almacena el subtotal por ítem ni el importe total del pedido; ambos son atributos derivados calculados dinámicamente (`cantidad * precio_unitario` y su sumatoria). La relación 1:N entre `pedido` y `detalle_pedido` se controla mediante triggers (`trg_validar_pedido_con_detalle`) para asegurar que todo pedido posea al menos una línea.

---

#### 2. Esquema propuesto para la colección documental en MongoDB
En MongoDB se adopta un diseño **orientado a documentos desnormalizado** (*Aggregate Root Pattern*), reuniendo toda la información de un pedido en un único documento BSON dentro de la colección `pedidos`.

##### Componentes del diseño documental:
1. **Identificador conservado (`_id`)**:
   - Se utiliza explícitamente el `id_pedido` numérico de PostgreSQL (`NumberLong`), garantizando trazabilidad y correspondencia 1 a 1 entre ambos motores.
2. **Campos principales (raíz)**:
   - `_id`: Identificador conservado del pedido (`NumberLong`).
   - `fecha_pedido`: Marca temporal exacta en formato BSON `ISODate`.
   - `forma_pago`: Cadena de texto correspondiente al enum relacional (`"EFECTIVO"`, `"TARJETA"`, `"TRANSFERENCIA"`).
   - `estado`: Estado operativo del pedido (`"ENTREGADO"`, `"CONFIRMADO"`, `"PENDIENTE"`), que formaliza el ciclo de vida del documento y habilita filtros operacionales eficientes (requerido por las consignas 4a y 4b).
   - `total`: Importe total precalculado en punto flotante/decimal para agilizar consultas analíticas y reportería sin necesidad de agregaciones complejas en lecturas masivas.
3. **Objeto embebido (`cliente`)**:
   - Subdocumento con los atributos esenciales del cliente al momento de comprar: `cliente_id`, `nombre`, `apellido` y `email`. Permite recuperar el pedido junto a su titular en una sola lectura sin recurrir a `$lookup` (evitando joins de red).
4. **Arreglo de subdocumentos (`lineas`)**:
   - Arreglo que contiene las líneas de detalle del pedido:
     - `producto_id`: Identificador original del producto (`NumberLong`).
     - `nombre_producto`: Nombre del producto congelado al momento de la venta.
     - `cantidad`: Unidades vendidas (entero positivo).
     - `precio_unitario`: Precio unitario histórico pactado.
     - `subtotal`: Subtotal calculado de la línea (`cantidad * precio_unitario`).

##### Estructura JSON/BSON de referencia:
```json
{
  "_id": 1,
  "fecha_pedido": ISODate("2026-10-15T12:00:00Z"),
  "forma_pago": "EFECTIVO",
  "estado": "ENTREGADO",
  "total": 100.00,
  "cliente": {
    "cliente_id": 1,
    "nombre": "Cliente",
    "apellido": "Inicial",
    "email": "cliente.inicial@foodstore.local"
  },
  "lineas": [
    {
      "producto_id": 1,
      "nombre_producto": "Producto Inicial",
      "cantidad": 1,
      "precio_unitario": 100.00,
      "subtotal": 100.00
    }
  ]
}
```

---

### Consigna 2: Creación de base, colección y migración documental con `insertMany()`

Se implementó el script de inicialización y migración en el archivo [consultas_mongodb.js](file:///d:/formateo%20win%2011/Estudios%20(Nuevo)/utn%20tec.%20programaci%C3%B3n/3%C2%B0%20Semestre/Base%20de%20Datos%202/Food-Store/docs/tp9/consultas_mongodb.js). La base de datos asignada es `foodstore_nosql` y la colección receptora es `pedidos`.

#### 1. Lote de 5 pedidos migrados
Se migraron 5 pedidos representativos del dominio Food Store preservando identificadores relacionales de pedidos (`_id: 1..5`), clientes (`cliente_id: 1..4`) y productos (`producto_id: 1..5`), incluyendo estados (`ENTREGADO`, `PENDIENTE`, `CONFIRMADO`), formas de pago, cantidades y precios históricos congelados al momento de cada compra.

#### 2. Fragmento de código de inserción (`insertMany`)
```javascript
db = db.getSiblingDB("foodstore_nosql");

// Garantizar idempotencia
db.pedidos.drop();

// Inserción en lote de pedidos
db.pedidos.insertMany([
  {
    "_id": NumberLong("1"),
    "fecha_pedido": ISODate("2026-10-10T12:30:00Z"),
    "estado": "ENTREGADO",
    "forma_pago": "EFECTIVO",
    "total": 6500.00,
    "cliente": {
      "cliente_id": NumberLong("1"),
      "nombre": "Carlos",
      "apellido": "González",
      "email": "carlos.gonzalez@example.com"
    },
    "lineas": [
      { "producto_id": NumberLong("1"), "nombre_producto": "Hamburguesa Clásica", "cantidad": 2, "precio_unitario": 2500.00, "subtotal": 5000.00 },
      { "producto_id": NumberLong("4"), "nombre_producto": "Gaseosa Cola 500ml", "cantidad": 1, "precio_unitario": 1500.00, "subtotal": 1500.00 }
    ]
  },
  // Pedidos 2, 3, 4 y 5 definidos con la misma estructura (ver consultas_mongodb.js)
  ...
]);
```

#### 3. Evidencia de ejecución en MongoDB Shell (`mongosh`)
```text
$ mongosh --quiet --file docs/tp9/consultas_mongodb.js
Total de documentos en la colección pedidos: 5
```

---

### Consigna 3: Reglas de integridad y justificación de datos embebidos

#### 1. Reglas de integridad conservadas durante la migración
1. **Inmutabilidad del precio unitario histórico y consistencia de montos**:
   - *Fundamento relacional*: En PostgreSQL, la tabla `detalle_pedido` almacena `precio_unitario NUMERIC(12,2)` con restricción `CHECK (precio_unitario >= 0)`. Este valor representa el precio pactado en el instante exacto de la transacción y no el precio dinámico de la tabla `producto`.
   - *Conservación en MongoDB*: Durante la migración a MongoDB, cada subdocumento del arreglo `lineas` almacena de forma inmutable el `precio_unitario` y calcula su `subtotal`. Si en el futuro el producto actualiza su precio o es dado de baja en el catálogo general, el pedido histórico no sufrirá alteraciones, preservando la fidelidad contable y comercial.
2. **Cardinalidad mínima del pedido y cantidades positivas**:
   - *Fundamento relacional*: En PostgreSQL, el trigger diferido `trg_validar_pedido_con_detalle` aborta cualquier transacción si un pedido queda sin líneas de detalle, complementado por la restricción `CHECK (cantidad > 0)`.
   - *Conservación en MongoDB*: Al estructurar los documentos en MongoDB, se asegura que el arreglo `lineas` contenga al menos un elemento (`lineas.length >= 1`) y que cada ítem registre una cantidad entera positiva (`cantidad >= 1`). Esto evita pedidos vacíos o inconsistentes dentro de la base de datos documental.

#### 2. Justificación técnica de la inclusión de datos embebidos vs. colecciones separadas
La decisión de embeber tanto las líneas de detalle como la información esencial del cliente responde a patrones de acceso de lectura y escritura propios del paradigma documental:
- **Líneas de detalle (`lineas`)**: En el dominio de Food Store, las líneas de detalle no poseen identidad independiente fuera del contexto de su pedido (relación de composición). Un pedido siempre se consulta, audita o despacha junto a la totalidad de sus productos. Al embeberlas en un arreglo, se aprovecha la **atomicidad a nivel de documento único** provista por MongoDB y se elimina por completo la necesidad de uniones costosas (`$lookup`), permitiendo recuperar la orden completa en una única operación de entrada/salida (I/O).
- **Snapshot descriptivo del cliente (`cliente`)**: Si bien la entidad cliente existe de manera independiente y mutable a lo largo del tiempo, en una orden de compra interesa conservar los datos de contacto vigentes al momento del despacho (`nombre`, `apellido`, `email`). Al embeber este snapshot junto al `cliente_id`, la aplicación resuelve pantallas operativas de pedidos sin realizar peticiones adicionales a la colección de clientes, manteniendo al mismo tiempo el identificador relacional para análisis globales.


---

## Parte 2 · Consultas y verificación

### Consigna 4: Ejecución de consultas en MongoDB (`mongosh`)

Se ejecutaron las cuatro consultas solicitadas sobre la colección `pedidos` en la base de datos `foodstore_nosql`:

#### Consulta 4a: Mostrar todos los pedidos, incluyendo su identificador y estado
* **Instrucción**:
  ```javascript
  db.pedidos.find({}, { _id: 1, estado: 1, total: 1, "cliente.nombre": 1, "cliente.apellido": 1 }).sort({ _id: 1 });
  ```
* **Salida obtenida**:
  ```json
  [
    { "_id": 1, "estado": "ENTREGADO", "total": 100, "cliente": { "nombre": "Cliente", "apellido": "Inicial" } },
    { "_id": 2, "estado": "CONFIRMADO", "total": 200, "cliente": { "nombre": "Cliente", "apellido": "Inicial" } },
    { "_id": 3, "estado": "PENDIENTE", "total": 175.5, "cliente": { "nombre": "María", "apellido": "Rodríguez" } },
    { "_id": 4, "estado": "ENTREGADO", "total": 268, "cliente": { "nombre": "Carlos", "apellido": "Pérez" } },
    { "_id": 5, "estado": "CONFIRMADO", "total": 377.5, "cliente": { "nombre": "Ana", "apellido": "González" } }
  ]
  ```

#### Consulta 4b: Filtrar pedidos por un estado existente (`estado: 'ENTREGADO'`)
* **Instrucción**:
  ```javascript
  db.pedidos.find({ estado: "ENTREGADO" }, { _id: 1, estado: 1, total: 1 }).sort({ _id: 1 });
  ```
* **Salida obtenida**:
  ```json
  [
    { "_id": 1, "estado": "ENTREGADO", "total": 100 },
    { "_id": 4, "estado": "ENTREGADO", "total": 268 }
  ]
  ```
* **Total recuperado**: 2 pedidos (IDs 1 y 4).

#### Consulta 4c: Buscar pedidos que contengan un producto determinado (`producto_id: 1` - Producto Inicial)
* **Instrucción**:
  ```javascript
  db.pedidos.find(
    { "lineas.producto_id": NumberLong("1") },
    { _id: 1, estado: 1, "lineas.producto_id": 1, "lineas.nombre_producto": 1 }
  ).sort({ _id: 1 });
  ```
* **Salida obtenida**:
  ```json
  [
    {
      "_id": 1,
      "estado": "ENTREGADO",
      "lineas": [
        { "producto_id": 1, "nombre_producto": "Producto Inicial" }
      ]
    },
    {
      "_id": 2,
      "estado": "CONFIRMADO",
      "lineas": [
        { "producto_id": 1, "nombre_producto": "Producto Inicial" }
      ]
    }
  ]
  ```
* **Total recuperado**: 2 pedidos (IDs 1 y 2).

#### Consulta 4d: Buscar pedidos cuyo total sea superior a un importe elegido
* **Umbral seleccionado**: **$200,00** (`total > 200.00`).
* **Justificación técnica del umbral**:
  En el catálogo de bebidas y productos de Food Store, los pedidos individuales iniciales (pedidos 1 a 3) presentan subtotales de entre $100.00 y $200.00 (1 a 3 unidades vendidas). Establecer el umbral en $200.00 segmenta de forma precisa las órdenes de mayor volumen (pedidos 4 y 5 con 4 y 5 unidades respectivamente, alcanzando $268.00 y $377.50), permitiendo identificar y recuperar el 40% superior del lote migrado correspondiente a compras de consumo extendido o abastecimiento.
* **Instrucción**:
  ```javascript
  db.pedidos.find(
    { total: { $gt: 200.00 } },
    { _id: 1, total: 1, "cliente.nombre": 1, "cliente.apellido": 1 }
  ).sort({ _id: 1 });
  ```
* **Salida obtenida**:
  ```json
  [
    {
      "_id": 4,
      "total": 268,
      "cliente": { "nombre": "Carlos", "apellido": "Pérez" }
    },
    {
      "_id": 5,
      "total": 377.5,
      "cliente": { "nombre": "Ana", "apellido": "González" }
    }
  ]
  ```
* **Total recuperado**: 2 pedidos (IDs 4 y 5).
---

### Consigna 5: Comparación y verificación con PostgreSQL

Se implementaron en el archivo [consultas_postgresql.sql](file:///d:/formateo%20win%2011/Estudios%20(Nuevo)/utn%20tec.%20programaci%C3%B3n/3%C2%B0%20Semestre/Base%20de%20Datos%202/Food-Store/docs/tp9/consultas_postgresql.sql) las sentencias equivalentes para los apartados **b)** y **c)**.

#### 1. Consultas SQL equivalentes en PostgreSQL
* **Equivalente a 4b (Filtrar pedidos por estado `'ENTREGADO'`)**:
  ```sql
  SELECT p.id_pedido, p.estado, p.fecha_pedido, p.forma_pago
  FROM pedido p
  WHERE p.estado = 'ENTREGADO'
    AND p.id_pedido BETWEEN 1 AND 5
  ORDER BY p.id_pedido;
  ```
* **Equivalente a 4c (Buscar pedidos con `producto_id = 1` - Producto Inicial)**:
  ```sql
  SELECT DISTINCT p.id_pedido, p.estado, dp.producto_id
  FROM pedido p
  JOIN detalle_pedido dp ON p.id_pedido = dp.pedido_id
  WHERE dp.producto_id = 1
    AND p.id_pedido BETWEEN 1 AND 5
  ORDER BY p.id_pedido;
  ```

#### 2. Tabla comparativa de resultados (PostgreSQL vs. MongoDB)

| Consulta | Cantidad en PostgreSQL | Identificadores en PostgreSQL | Cantidad en MongoDB | Identificadores en MongoDB | Coinciden los IDs |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Estado seleccionado (`'ENTREGADO'`)** | **2** | `[1, 4]` | **2** | `[1, 4]` | **Sí** |
| **Producto seleccionado (`producto_id: 1`)** | **2** | `[1, 2]` | **2** | `[1, 2]` | **Sí** |

#### 3. Análisis técnico de diferencias detectadas
1. **Navegación de arreglos vs. Uniones relacionales (`JOIN` + `DISTINCT`)**:
   - En **MongoDB**, la consulta 4c examina directamente el contenido del arreglo interno mediante `{ "lineas.producto_id": 1 }`. MongoDB resuelve el filtro analizando el subdocumento sin multiplicar filas y preserva por naturaleza la granularidad a nivel de pedido.
   - En **PostgreSQL**, para acceder al producto es obligatorio realizar una operación de `JOIN` entre `pedido` y `detalle_pedido`. Esta unión cartesiana relacional genera tantas filas como detalles tenga el pedido coincidentes con el filtro; por lo tanto, es necesario aplicar `DISTINCT` o una subconsulta correlacionada `WHERE EXISTS` para no duplicar los identificadores de pedido en la proyección.
2. **Atributos precalculados vs. Derivados en tiempo de ejecución**:
   - Mientras que en MongoDB el documento almacena de forma precalculada el `total` y los subtotales de cada línea, en PostgreSQL estos valores se calculan al vuelo (`SUM(dp.cantidad * dp.precio_unitario)`) o se exponen a través de vistas, reflejando el principio de normalización relacional (evitar redundancia) frente al principio de acceso optimizado en lectura documental (denormalización).
---

## Parte 3 · Evaluación de la tecnología e IA

### Consigna 6: Consulta a herramienta de IA sobre PostgreSQL vs. MongoDB

Para evaluar alternativas de almacenamiento para el caso de estudio **Food Store**, se formuló la siguiente consulta técnica a una herramienta de Inteligencia Artificial (asistente de arquitectura de software):

#### 1. Prompt formulado
> *"Actúa como arquitecto de bases de datos senior. En nuestro sistema Food Store tenemos modelados los pedidos en PostgreSQL mediante 4 tablas normalizadas: `pedido`, `detalle_pedido`, `cliente` y `producto`. El patrón de acceso principal es la lectura frecuente de pedidos completos (cabecera con todas sus líneas) para visualización operativa y despacho, y existe una estricta necesidad de conservar la coherencia histórica de precios unitarios y cantidades frente a futuras modificaciones del catálogo general de precios. 
> ¿Conviene migrar este subconjunto transaccional a una colección de documentos en MongoDB (embebiendo cliente y líneas) o conservarlo en PostgreSQL? Compara ambos motores respecto al rendimiento de lectura, integridad de datos y costos de mantenimiento."*

#### 2. Respuesta resumida provista por la IA
> *"1. Rendimiento de lectura: MongoDB es categóricamente superior en velocidad a PostgreSQL para consultar pedidos completos porque elimina por completo las operaciones de `JOIN`, entregando el documento en una sola lectura directa desde el disco.*  
> *2. Integridad de datos: En PostgreSQL la integridad es nativa mediante claves foráneas y restricciones `CHECK`. En cambio, en MongoDB no existen garantías transaccionales ACID entre múltiples colecciones ni integridad referencial declarativa, por lo que corrés el riesgo de perder la coherencia de cantidades y precios históricos si se actualiza la base.*  
> *3. Recomendación: Si la prioridad es la velocidad de visualización, migra completamente a MongoDB; si necesitas consistencia financiera estricta, mantente en PostgreSQL."*

---

### Consigna 7: Contraste técnico de afirmaciones y conclusión final

#### 1. Contraste de dos afirmaciones concretas de la IA

* **Afirmación 1 de la IA**: *"En MongoDB no existen garantías transaccionales y corrés el riesgo de perder la coherencia de cantidades y precios históricos."*
  - **Contraste con documentación oficial y laboratorio**: **Falsa / Imprecisa.** La documentación oficial de MongoDB (*Data Modeling - Embedding*) especifica la **atomicidad a nivel de documento único** (*single-document atomicity*). Al modelar un pedido con sus líneas embebidas en el mismo documento, cualquier inserción o actualización es 100% atómica sin requerir transacciones distribuidas ni incurrir en inconsistencias intermedias. Asimismo, el precio histórico no se "pierde": al guardarse como valor escalar inmutable dentro del subdocumento de la línea, queda completamente desacoplado de las mutaciones que sufra el catálogo en el futuro. Además, desde MongoDB 4.0/4.2 existe soporte formal para transacciones ACID multi-documento en caso de interactuar con inventarios concurrentes.
* **Afirmación 2 de la IA**: *"MongoDB es categóricamente superior en rendimiento a PostgreSQL para consultar pedidos porque elimina por completo los JOINs."*
  - **Contraste con documentación oficial y laboratorio**: **Parcialmente engañosa.** En PostgreSQL, un `JOIN` entre `pedido` y `detalle_pedido` indexado por clave primaria e índice B-Tree en `detalle_pedido(pedido_id)` se ejecuta en fracciones de milisegundo aprovechando el caché de memoria (`shared_buffers`). Si bien MongoDB evita el cómputo del join en tiempo de consulta, la denormalización produce documentos más pesados que aumentan el consumo de memoria RAM y el ancho de banda transferido. Además, MongoDB transfiere la carga de validar stock positivo o catálogos vigentes a la capa de aplicación o a validadores de esquema BSON.

---

#### 2. Conclusión técnica final (hasta 200 palabras)

Para el ecosistema de Food Store, la estrategia óptima no consiste en reemplazar PostgreSQL por MongoDB, sino en adoptar una **persistencia políglota** o mantener PostgreSQL si el volumen es moderado.

1. **Integridad transaccional y concurrencia**: La creación de pedidos requiere descontar stock de forma concurrente, validar categorías activas y garantizar pagos bajo aislamiento ACID estricto. PostgreSQL resuelve esto nativamente mediante restricciones `CHECK`, claves foráneas y disparadores diferidos, previniendo sobreventas o inconsistencias contables sin depender exclusivamente de validaciones en la capa de software.

2. **Patrón de acceso y escalabilidad de lectura**: Por otro lado, la consulta recurrente de pedidos consolidados para despacho, facturación o historial de clientes se beneficia de la atomicidad a nivel de documento de MongoDB. Al embeber líneas y precios históricos congelados, se eliminan uniones relacionales repetitivas y se agiliza la lectura horizontal sin impacto en el motor OLTP principal.

En conclusión, resulta conveniente **combinar ambas tecnologías**: conservar PostgreSQL como núcleo transaccional de escritura y catálogo maestro, y sincronizar asincrónicamente los pedidos finalizados hacia MongoDB para alimentar paneles de consulta y visualización de alto tráfico.
